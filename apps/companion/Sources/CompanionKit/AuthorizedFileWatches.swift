import Darwin
import Dispatch
import Foundation

/// Mutated only by its main-actor owner. Deinit is exclusive and may run on
/// another executor; dispatch cancellation and joining are thread-safe.
private final class FileWatchOwnership: @unchecked Sendable {
    let queue = DispatchQueue(label: "threadmark.approved-file-metadata")
    let closed = DispatchGroup()
    var sources: [any DispatchSourceFileSystemObject] = []
    func stop() {
        for source in sources { source.cancel() }
        closed.wait()
        sources.removeAll()
    }
    deinit { stop() }
}

/// Metadata only; never reads bytes or enumerates directories. Main-actor
/// ownership, with descriptor close handlers on a separately joined queue.
@MainActor
final class AuthorizedFileWatches {
    private let owned = FileWatchOwnership()
    private let willInstall: () -> Void
    private let opened: (Int32) -> Void
    private let didClose: @Sendable (Int32, Int32) -> Void
    var count: Int { owned.sources.count }
    init(willInstall: @escaping () -> Void = {}, opened: @escaping (Int32) -> Void = { _ in },
         didClose: @escaping @Sendable (Int32, Int32) -> Void = { _, _ in }) {
        self.willInstall = willInstall; self.opened = opened; self.didClose = didClose
    }

    func install(_ consent: AutomaticRefreshConsent, event: @escaping @Sendable () -> Void) throws {
        willInstall()
        stop()
        guard !consent.sources.isEmpty, consent.sources.count <= 64,
              Set(consent.sources).count == consent.sources.count,
              InputPolicy.sources(consent.sources) else { throw ServiceError.invalid }
        let root = try Self.root(consent)
        defer { close(root) }
        // DispatchSource exposes no registration-error callback. Require a
        // successful native vnode registration receipt for every descriptor,
        // rather than claiming event coverage on an unsupported filesystem.
        let preflight = kqueue()
        guard preflight >= 0 else { throw ServiceError.unavailable }
        defer { close(preflight) }
        guard fcntl(preflight, F_SETFD, FD_CLOEXEC) == 0 else { throw ServiceError.failed }
        var rootInfo = stat()
        guard fstat(root, &rootInfo) == 0 else { throw ServiceError.failed }
        do {
            for path in consent.sources {
                let fd = try Self.file(path, root: root, device: rootInfo.st_dev)
                do { try Self.validateWatch(fd, queue: preflight) }
                catch { close(fd); throw error }
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .attrib, .link, .rename, .delete, .revoke], queue: owned.queue)
                source.setEventHandler(handler: event)
                owned.closed.enter()
                let closed = owned.closed, didClose = didClose
                source.setCancelHandler { @Sendable in didClose(fd, close(fd)); closed.leave() }
                owned.sources.append(source)
                opened(fd)
                source.resume()
            }
        } catch { stop(); throw error }
    }

    func stop() {
        // Handlers never need the main actor. Complete closure before opening
        // replacements: at most 64 watch descriptors are ever owned.
        owned.stop()
    }

    private static func validateWatch(_ fd: Int32, queue: Int32) throws {
        var change = kevent(ident: UInt(fd), filter: Int16(EVFILT_VNODE),
            flags: UInt16(EV_ADD | EV_CLEAR | EV_RECEIPT),
            fflags: UInt32(NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_DELETE | NOTE_REVOKE),
            data: 0, udata: nil)
        var receipt = kevent(), timeout = timespec(tv_sec: 0, tv_nsec: 0)
        guard kevent(queue, &change, 1, &receipt, 1, &timeout) == 1,
              receipt.flags & UInt16(EV_ERROR) != 0, receipt.data == 0 else { throw ServiceError.unavailable }
    }

    private static func root(_ consent: AutomaticRefreshConsent) throws -> Int32 {
        guard InputPolicy.removal(root: consent.root, identity: consent.rootIdentity), consent.root != "/" else { throw ServiceError.invalid }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw ServiceError.failed }
        do {
            for component in consent.root.split(separator: "/", omittingEmptySubsequences: false).dropFirst() {
                guard !component.isEmpty, component != ".", component != ".." else { throw ServiceError.invalid }
                let next = openat(fd, String(component), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
                guard next >= 0 else { throw ServiceError.failed }
                close(fd); fd = next
            }
            var info = stat()
            guard fstat(fd, &info) == 0,
                  "\(info.st_dev):\(info.st_ino)" == consent.rootIdentity else { throw ServiceError.scopeMismatch }
            return fd
        } catch { close(fd); throw error }
    }

    private static func file(_ path: String, root: Int32, device: dev_t) throws -> Int32 {
        var parent = fcntl(root, F_DUPFD_CLOEXEC, 0)
        guard parent >= 0 else { throw ServiceError.failed }
        defer { close(parent) }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw ServiceError.invalid }
        for component in parts.dropLast() {
            let next = openat(parent, String(component), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            guard next >= 0 else { throw ServiceError.failed }
            close(parent); parent = next
            var info = stat(), git = stat()
            guard fstat(parent, &info) == 0, info.st_dev == device else { throw ServiceError.scopeMismatch }
            errno = 0
            let marker = fstatat(parent, ".git", &git, AT_SYMLINK_NOFOLLOW)
            guard marker != 0, errno == ENOENT else { throw ServiceError.scopeMismatch }
        }
        let fd = openat(parent, String(parts.last!), O_EVTONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw ServiceError.failed }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_dev == device, info.st_nlink == 1, info.st_size <= 65536 else {
            close(fd); throw ServiceError.invalid
        }
        return fd
    }
}
