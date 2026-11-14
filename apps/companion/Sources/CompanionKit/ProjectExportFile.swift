import Foundation
import Darwin

/// NEW private file only. A held directory fd, not response content, determines
/// publication. No overwrite, parent creation, symlink traversal or remote mount.
enum ProjectExportFile {
    static func validateLocalFilesystem(flags: UInt32) throws {
        guard flags & UInt32(MNT_LOCAL) != 0 else { throw ServiceError.invalid }
    }
    struct IO: Sendable {
        var write: @Sendable (Int32, UnsafeRawPointer, Int) -> Int = { Darwin.write($0, $1, $2) }
        var sync: @Sendable (Int32) -> Int32 = { Darwin.fsync($0) }
    }
    static func parent(_ url: URL, project: Project, store: URL, roots: [String] = []) throws -> (Int32, String) {
        guard url.isFileURL, url.host == nil || url.host == "", !url.path.contains("\0"),
              store.isFileURL, store.path.hasPrefix("/") else { throw ServiceError.invalid }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count > 2, parts.first == "", parts.dropFirst().allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let name = parts.last, name.utf8.count <= 255 else { throw ServiceError.invalid }
        let forbidden = ([project.root, store.path] + roots).map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        let parentPath = url.deletingLastPathComponent().path
        guard !forbidden.contains(where: { $0 == "/" || parentPath == $0 || parentPath.hasPrefix($0 + "/") }) else { throw ServiceError.invalid }
        // Identity checks also reject aliases of the source/store roots.
        let identities: [(dev_t, ino_t)] = forbidden.compactMap {
            var s = stat(); return lstat($0, &s) == 0 ? (s.st_dev, s.st_ino) : nil
        }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw ServiceError.failed }
        do {
            func validateDirectory(_ descriptor: Int32) throws {
                var s = stat(), fs = statfs()
                guard fstat(descriptor, &s) == 0, fstatfs(descriptor, &fs) == 0,
                      !identities.contains(where: { $0.0 == s.st_dev && $0.1 == s.st_ino }) else { throw ServiceError.invalid }
                try validateLocalFilesystem(flags: fs.f_flags)
            }
            try validateDirectory(fd)
            for part in parts.dropFirst().dropLast() {
                let next = openat(fd, String(part), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                guard next >= 0 else { throw ServiceError.invalid }; close(fd); fd = next
                try validateDirectory(fd)
            }
            var s = stat()
            guard fstat(fd, &s) == 0, s.st_uid == geteuid(), s.st_mode & 0o7777 == 0o700 else { throw ServiceError.invalid }
            // Reject inherited ACLs; this is not cloud/backup isolation certification.
            errno = 0
            if let acl = acl_get_fd_np(fd, ACL_TYPE_EXTENDED) {
                defer { acl_free(UnsafeMutableRawPointer(acl)) }
                var entry: acl_entry_t?
                guard acl_valid(acl) == 0, acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry) != 0 else { throw ServiceError.invalid }
            } else if errno != ENOENT { throw ServiceError.invalid }
            var existing = stat()
            guard fstatat(fd, String(name), &existing, AT_SYMLINK_NOFOLLOW) == -1, errno == ENOENT else { throw ServiceError.invalid }
            return (fd, String(name))
        } catch { close(fd); throw error }
    }
    static func validateDestination(_ url: URL, project: Project, store: URL, roots: [String] = []) throws {
        let (fd, _) = try parent(url, project: project, store: store, roots: roots); close(fd)
    }
    static func save(_ document: ProjectExportDocument, to url: URL, project: Project, store: URL, roots: [String] = [], io: IO = .init()) throws {
        guard document.bytes.count <= ProjectExportDocument.limit else { throw ServiceError.outputLimit }
        try Task.checkCancellation()
        let (directory, name) = try parent(url, project: project, store: store, roots: roots); defer { close(directory) }
        let temporary = ".threadmark-export-" + UUID().uuidString
        let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw ServiceError.failed }
        var owned = stat()
        defer {
            var named = stat()
            if fstatat(directory, temporary, &named, AT_SYMLINK_NOFOLLOW) == 0,
               named.st_dev == owned.st_dev, named.st_ino == owned.st_ino { unlinkat(directory, temporary, 0) }
            close(fd)
        }
        guard fstat(fd, &owned) == 0, owned.st_uid == geteuid(), owned.st_mode & S_IFMT == S_IFREG,
              owned.st_mode & 0o7777 == 0o600, owned.st_nlink == 1 else { throw ServiceError.failed }
        try document.bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                try Task.checkCancellation()
                let count = io.write(fd, raw.baseAddress!.advanced(by: offset), min(4096, raw.count - offset))
                if count < 0 { if errno == EINTR { continue }; throw ServiceError.failed }
                guard count > 0, count <= raw.count - offset else { throw ServiceError.failed }; offset += count
            }
        }
        guard io.sync(fd) == 0 else { throw ServiceError.failed }
        try Task.checkCancellation()
        // Repeat destination/ancestry validation immediately before publication,
        // retaining and comparing the originally selected directory identity.
        let (checked, _) = try parent(url, project: project, store: store, roots: roots); defer { close(checked) }
        var first = stat(), second = stat(), named = stat()
        guard fstat(directory, &first) == 0, fstat(checked, &second) == 0,
              first.st_dev == second.st_dev, first.st_ino == second.st_ino,
              fstatat(directory, temporary, &named, AT_SYMLINK_NOFOLLOW) == 0,
              named.st_dev == owned.st_dev, named.st_ino == owned.st_ino,
              renameatx_np(directory, temporary, directory, name, UInt32(RENAME_EXCL)) == 0 else { throw ServiceError.failed }
        // Published data is user-owned now: never delete it on cancellation or a
        // durability error. Caller must report uncertainty rather than rollback.
        guard io.sync(directory) == 0 else { throw ServiceError.exportUncertain }
    }
}
