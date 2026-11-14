import Foundation
import Darwin
import Combine
import SwiftUI

/// Companion app data only, never a host configuration or credential store.
public enum ProviderProfileFile {
    public static let limit = 65536
    public enum Failure: Error { case invalid, unsafeFile, conflict, io }

    /// This version deliberately accepts only its canonical JSON encoding. Besides
    /// unknown fields, this rejects duplicate keys (including escaped aliases).
    /// No permissive JSON parser may silently choose one of two profile meanings.
    public static func encode(_ settings: ProviderSettings) throws -> Data {
        try validate(settings)
        var disabled = settings; disabled.enabled = false
        return try canonical(disabled)
    }

    public static func decode(_ data: Data) throws -> ProviderSettings {
        guard data.count <= limit else { throw Failure.invalid }
        let settings = try JSONDecoder().decode(ProviderSettings.self, from: data)
        try validate(settings)
        guard try canonical(settings) == data else { throw Failure.invalid }
        var disabled = settings; disabled.enabled = false
        return disabled
    }

    private static func canonical(_ settings: ProviderSettings) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(settings)
        guard bytes.count <= limit else { throw Failure.invalid }
        return bytes
    }

    public static func validate(_ settings: ProviderSettings) throws {
        guard settings.profiles.count <= 16,
              Set(settings.profiles.map(\.id)).count == settings.profiles.count,
              settings.selectedProfileID.map({ id in settings.profiles.contains { $0.id == id } }) ?? true,
              !settings.enabled || settings.selectedProfileID != nil else { throw Failure.invalid }
        for profile in settings.profiles { try profile.validate() }
    }

    public static func load(_ url: URL) throws -> ProviderSettings {
        let (directory, name) = try parent(url); defer { close(directory) }
        let fd = openat(directory, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { throw Failure.unsafeFile }
        defer { close(fd) }
        let before = try privateObject(fd, directory: false)
        guard before.st_size >= 0, before.st_size <= limit else { throw Failure.invalid }
        var bytes = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(fd, &buffer, min(buffer.count, limit + 1 - bytes.count))
            if count < 0 { if errno == EINTR { continue }; throw Failure.io }
            if count == 0 { break }
            bytes.append(contentsOf: buffer.prefix(count))
            guard bytes.count <= limit else { throw Failure.invalid }
        }
        let after = try privateObject(fd, directory: false)
        var named = stat()
        guard fstatat(directory, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
              named.st_dev == before.st_dev, named.st_ino == before.st_ino,
              before.st_size == after.st_size, bytes.count == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { throw Failure.conflict }
        return try decode(bytes)
    }

    /// Atomic publication to a NEW name only. Never overwrite an existing file,
    /// symlink or a competing writer, even after a save panel's replace prompt.
    public static func save(_ settings: ProviderSettings, to url: URL) throws {
        let bytes = try encode(settings)
        let (directory, name) = try parent(url); defer { close(directory) }
        let temporary = ".threadmark-profile-" + UUID().uuidString
        let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw Failure.io }
        defer { close(fd); unlinkat(directory, temporary, 0) }
        _ = try privateObject(fd, directory: false)
        try bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let count = write(fd, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                if count < 0 { if errno == EINTR { continue }; throw Failure.io }
                guard count > 0 else { throw Failure.io }; offset += count
            }
        }
        guard fsync(fd) == 0 else { throw Failure.io }
        _ = try privateObject(directory, directory: true)
        guard renameatx_np(directory, temporary, directory, name, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw Failure.conflict }; throw Failure.io
        }
        // Publication is complete. Never remove the published file on a later
        // durability error; it is now user data. The UI reports uncertainty.
        guard fsync(directory) == 0 else { throw Failure.io }
    }

    private static func parent(_ url: URL) throws -> (Int32, String) {
        guard url.isFileURL, url.host == nil || url.host == "", !url.path.contains("\0") else { throw Failure.invalid }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count > 2, parts.first == "",
              parts.dropFirst().allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw Failure.invalid }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw Failure.io }
        do {
            for part in parts.dropFirst().dropLast() {
                let next = openat(fd, String(part), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                guard next >= 0 else { throw Failure.unsafeFile }
                close(fd); fd = next
            }
            _ = try privateObject(fd, directory: true)
            return (fd, String(parts.last!))
        } catch { close(fd); throw error }
    }

    private static func privateObject(_ fd: Int32, directory: Bool) throws -> stat {
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == geteuid(),
              info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG),
              info.st_mode & 0o7777 == (directory ? 0o700 : 0o600),
              directory || info.st_nlink == 1 else { throw Failure.unsafeFile }
        // macOS reports ENOENT for an absent extended ACL on a valid open fd.
        // Unsupported filesystems and all other inspection failures reject.
        errno = 0
        guard let acl = acl_get_fd_np(fd, ACL_TYPE_EXTENDED) else {
            guard errno == ENOENT else { throw Failure.unsafeFile }
            return info
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        var entry: acl_entry_t?
        guard acl_valid(acl) == 0, acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry) != 0 else { throw Failure.unsafeFile }
        return info
    }
}

/// Session owner used by the mounted Connections binding. No service/network
/// access. Invalidation preserves the app's original/editor through its callback.
@MainActor
public final class CompanionProviderSession: ObservableObject {
    @Published public private(set) var settings = ProviderSettings()
    @Published public private(set) var status = "Profiles are session-only until explicitly saved. Inference is off."
    private let invalidate: () -> Void

    public init(invalidate: @escaping () -> Void) { self.invalidate = invalidate }

    public var binding: Binding<ProviderSettings> {
        Binding(get: { self.settings }, set: { self.update($0) })
    }

    public func update(_ candidate: ProviderSettings) {
        do {
            // Enablement may only survive a toggle, not an identity/profile edit.
            // Normalize before validation: clearing an enabled selection is a
            // valid disabling action, not an invalid enabled-without-profile state.
            var next = candidate
            if next.profiles != settings.profiles || next.selectedProfileID != settings.selectedProfileID { next.enabled = false }
            try ProviderProfileFile.validate(next)
            guard next != settings else { return }
            settings = next; invalidate()
            status = "Session settings updated. No request sent; per-request consent is still required."
        } catch { status = "Invalid profile settings; previous settings retained." }
    }

    public func save(to selection: URL?) {
        guard let selection else { return }
        do {
            try ProviderProfileFile.save(settings, to: selection)
            status = "Private profile file saved with inference off. No request sent."
        } catch { status = "Profile save failed or conflicted. Choose a NEW filename in an owned 0700 folder; no existing file is replaced. A durability failure may leave the new file present." }
    }

    public func load(from selection: URL?) {
        guard let selection else { return }
        do {
            let candidate = try ProviderProfileFile.load(selection)
            settings = candidate; invalidate()
            status = "Profile file loaded; inference is OFF. Explicit enable and separate request consent are required."
        } catch { status = "Profile load rejected: unreadable, noncanonical, invalid, changed or unsafe private file. Previous settings and drafts retained." }
    }
}
