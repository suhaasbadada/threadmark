import Foundation
import Darwin

public struct ProcessLimits: Sendable {
    public var seconds: Double = 30
    public var stdoutBytes: Int = 1_048_576
    public var stderrBytes: Int = 16_384
    public var inputBytes: Int = 4096
    public init() {}
}

private final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var canceled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// Owned only by the runner's I/O thread. No Foundation Process/dispatch reaper
/// exists for this child. An exited but unreaped child reserves its PID, so an
/// exit between waitpid(WNOHANG)==0 and kill cannot target a recycled identity.
struct OwnedChild {
    let pid: pid_t
    private(set) var finished = false
    private(set) var status: Int32?
    private var terminatedAt: Double?
    private var killed = false

    // Older Swift toolchains make the synthesized memberwise initializer private
    // because lifecycle fields are private. Only a fresh PID may be supplied.
    init(pid: pid_t) { self.pid = pid }

    mutating func step(now: Double, stopping: Bool,
                       wait: (pid_t, UnsafeMutablePointer<Int32>?, Int32) -> pid_t = { Darwin.waitpid($0, $1, $2) },
                       signal: (pid_t, Int32) -> Int32 = { Darwin.kill($0, $1) }) -> Bool {
        guard !finished else { return true }
        var value: Int32 = 0
        let result = wait(pid, &value, WNOHANG)
        if result == pid { status = value; finished = true; return true }
        if result < 0 {
            if errno == EINTR { return false }
            // ECHILD (or another unexpected wait error) means no retained
            // identity: stop ALL signaling, including a pending escalation.
            finished = true; return true
        }
        guard result == 0 else { finished = true; return true }
        if stopping {
            if terminatedAt == nil { _ = signal(pid, SIGTERM); terminatedAt = now }
            else if !killed, now - terminatedAt! >= 0.2 {
                killed = true; _ = signal(pid, SIGKILL)
            }
        }
        return false
    }
}

/// No shell, PATH search, inherited environment, credentials, listener, or sample fallback.
public struct ProcessService: CoreService {
    public let executable: URL?
    public let dataDirectory: URL?
    public var limits: ProcessLimits
    public init(executable: URL? = nil, dataDirectory: URL? = nil, limits: ProcessLimits = .init()) {
        self.executable = executable; self.dataDirectory = dataDirectory; self.limits = limits
    }

    public func perform(_ operation: Operation) async throws -> Reply {
        let batch: BatchPlan?
        if case .editContextBatchBound(let execution) = operation { batch = try execution.claim() }
        else { batch = nil }
        // Claim once; decoding uses this immutable capture, never claims again.
        let (arguments, input) = try command(operation, batch: batch)
        guard let executable, let dataDirectory,
              executable.isFileURL, dataDirectory.isFileURL,
              executable.path.hasPrefix("/"), dataDirectory.path.hasPrefix("/"),
              !executable.path.contains("\0"), !dataDirectory.path.contains("\0"),
              FileManager.default.isExecutableFile(atPath: executable.path) else { throw ServiceError.unavailable }
        guard input.count <= (batch == nil ? limits.inputBytes : 65536), limits.seconds > 0,
              limits.seconds <= 300, limits.stdoutBytes > 0, limits.stdoutBytes <= 1_048_576,
              limits.stderrBytes > 0, limits.stderrBytes <= 16_384,
              limits.inputBytes > 0, limits.inputBytes <= 4096 else { throw ServiceError.invalid }
        let cancellation = Cancellation()
        var operationLimits = limits
        if batch != nil { operationLimits.inputBytes = 65536; operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .indexIncrementalBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 65536) }
        if case .coverageBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 65536) }
        if case .inspectSourceAnchorBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .compareHumanContextBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 65536) }
        if case .refinePreview = operation {
            operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192)
            operationLimits.seconds = min(limits.seconds, 30)
        }
        if case .searchHumanContext = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .searchHumanContextBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .searchHumanContextKindsBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .query = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .queryBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .queryTermsBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .prepareContextTermsBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .prepareContextBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .prepareContext = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .removeProject = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 1024) }
        if case .forgetContext = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 1024) }
        if case .forgetSource = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 1024) }
        if case .updateContextRevisionBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 1024) }
        if case .retireContextRevisionBound = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 1024) }
        let boundedLimits = operationLimits
        let data = try await withTaskCancellationHandler {
            guard !Task.isCancelled else { throw ServiceError.canceled }
            return try await Task.detached {
                try Self.run(executable: executable, directory: dataDirectory,
                             arguments: ["--data-dir", dataDirectory.path] + arguments,
                             input: input, limits: boundedLimits, cancellation: cancellation)
            }.value
        } onCancel: { cancellation.cancel() }
        guard !Task.isCancelled else { throw ServiceError.canceled }
        do {
            let decoder = JSONDecoder()
            let responseOperation: Operation
            switch operation {
            case .contextsBound(let b): responseOperation = .contexts(b.project)
            case .forgottenContextsBound(let b): responseOperation = .forgottenContexts(b.project)
            case .forgottenSourcesBound(let b): responseOperation = .forgottenSources(b.project)
            case .contextBound(let b, let id): responseOperation = .context(b.project, id)
            case .searchHumanContextBound(let b, let q): responseOperation = .searchHumanContext(b.project, q)
            case .queryBound(let p, let q), .queryTermsBound(let p, let q): responseOperation = .query(p.id, q)
            case .prepareContextBound(let p, let q, let original), .prepareContextTermsBound(let p, let q, let original): responseOperation = .prepareContext(p.id, q, original)
            default: responseOperation = operation
            }
            switch responseOperation {
            case .editContextBatchBound:
                guard let batch else { throw ServiceError.invalid }
                return .batchReceipt(try BatchReceipt.decode(data, plan: batch))
            case .indexIncrementalBound(let request):
                return .incrementalBuild(try IncrementalBuildReport.decode(data, request: request))
            case .searchHumanContextKindsBound(let request):
                return .filteredHumanSearch(try FilteredHumanSearch.decode(data, request: request))
            case .coverageBound(let request):
                return .coverage(try CoverageDocument.decode(data, request: request))
            case .inspectSourceAnchorBound(let request):
                return .sourceInspection(try SourceInspectionDocument.decode(data, request: request))
            case .compareHumanContextBound(let request):
                return .humanComparison(try HumanComparison.decode(data, request: request))
            case .exportProjectBound(let execution):
                return .projectExport(try ProjectExportDocument.decode(data, scope: execution.confirmation.project))
            case .refinePreview(let consent):
                return .refinementPreview(try RefinementPreview.decode(data, consent: consent))
            case .searchHumanContext(let project, _):
                let result = try HumanContextSearch.decode(data, project: project)
                if case .searchHumanContextBound(let binding, _) = operation {
                    guard result.root_identity.utf8.elementsEqual(binding.rootIdentity.utf8),
                          result.incarnation?.utf8.elementsEqual(binding.incarnation.utf8) == true else { throw ServiceError.namespaceChanged }
                }
                return .humanContextSearch(result)
            case .forgetSource(let project, let path, _, _, _, _):
                guard data.count <= 1024 else { throw ServiceError.outputLimit }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      Set(object.keys) == ["project", "path", "forgotten", "source_authorization", "snapshot", "human_context", "retention_limits"] else { throw ServiceError.invalid }
                let result = try decoder.decode(ForgottenSource.self, from: data)
                try result.validate(project: project, path: path)
                return .forgottenSource(result)
            case .forgottenSources(let project):
                guard data.count <= 1_048_576 else { throw ServiceError.outputLimit }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      Set(object.keys) == ["project", "forgotten"],
                      let markers = object["forgotten"] as? [[String: Any]],
                      markers.allSatisfy({ Set($0.keys) == ["path"] }) else { throw ServiceError.invalid }
                let result = try decoder.decode(ForgottenSources.self, from: data)
                try result.validate(project: project)
                return .forgottenSources(result)
            case .forgetContext(let project, let id, _, _, _, let revision):
                guard data.count <= 1024 else { throw ServiceError.outputLimit }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      Set(object.keys) == ["project", "id", "forgotten", "removed_revisions", "retention_limits"] else { throw ServiceError.invalid }
                let result = try decoder.decode(ForgottenContext.self, from: data)
                try result.validate(project: project, id: id, revision: revision)
                return .forgotten(result)
            case .forgottenContexts(let project):
                guard data.count <= 1_048_576 else { throw ServiceError.outputLimit }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      Set(object.keys) == ["project", "forgotten"],
                      let markers = object["forgotten"] as? [[String: Any]],
                      markers.allSatisfy({ Set($0.keys) == ["id"] }) else { throw ServiceError.invalid }
                let result = try decoder.decode(ForgottenContexts.self, from: data)
                try result.validate(project: project)
                return .forgottenContexts(result)
            case .removeProject(let id, _, _, _):
                guard data.count <= 1024 else { throw ServiceError.outputLimit }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      Set(object.keys) == ["project", "removed", "retention_limits"] else { throw ServiceError.invalid }
                let result = try decoder.decode(RemovedProject.self, from: data)
                try result.validate(project: id)
                return .removed(result)
            case .prepareContext(let id, _, let original):
                guard data.count <= 8192 else { throw ServiceError.outputLimit }
                let result = try decoder.decode(ContextPreview.self, from: data)
                try result.validate(project: id, original: original)
                if case .prepareContextTermsBound = operation {
                    guard result.retrieval_mode == "ranked-terms", result.coverage?.hasPrefix("ranked-terms;") == true else { throw ServiceError.invalid }
                }
                return .preview(result)
            case .projects:
                let projects = try decoder.decode([Project].self, from: data)
                guard projects.count <= 64, Set(projects.map(\.id)).count == projects.count,
                      projects.allSatisfy({ InputPolicy.identifier($0.id) && InputPolicy.sources($0.sources) && ($0.incarnation.map(InputPolicy.incarnation) ?? true) }) else { throw ServiceError.invalid }
                return .projects(projects)
            case .project(let id):
                let result = try decoder.decode(Project.self, from: data)
                guard result.id == id else { throw ServiceError.scopeMismatch }
                guard InputPolicy.sources(result.sources), result.incarnation.map(InputPolicy.incarnation) ?? true else { throw ServiceError.invalid }
                return .project(result)
            case .index(let id), .indexBound(let id, _, _, _, _):
                let result = try decoder.decode(IndexReport.self, from: data)
                guard result.project == id else { throw ServiceError.scopeMismatch }
                guard result.files >= 0, result.files <= 64, result.anchors >= 0 else { throw ServiceError.invalid }
                return .indexed(result)
            case .query(let id, _):
                guard data.count <= 8192 else { throw ServiceError.outputLimit }
                let result = try decoder.decode(QueryReport.self, from: data)
                if case .queryTermsBound = operation {
                    guard let terms = result.terms, (1...8).contains(terms.count),
                          terms.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 64 }),
                          result.selection == "distinct-matched-terms-desc,total-nonoverlap-occurrences-desc,path-line-asc",
                          result.truncated != nil else { throw ServiceError.invalid }
                }
                guard result.project == id, result.results.allSatisfy({ $0.project == id }) else { throw ServiceError.scopeMismatch }
                guard result.results.count <= 8, Self.currentness(result.currentness), result.results.allSatisfy({
                    $0.line > 0 && $0.kind == "observed-source-line" && Self.currentness($0.currentness) && InputPolicy.sources([$0.path])
                }) else { throw ServiceError.invalid }
                return .query(result)
            case .updateContextRevisionBound(let binding, _, _):
                let object = try decoder.decode([String: JSONValue].self, from: data)
                guard Set(object.keys) == ["project", "id", "saved", "producer"],
                      object["project"] == .string(binding.project), object["id"] == .string(binding.contextID),
                      object["saved"] == .bool(true), object["producer"] == .string("human-authored") else { throw ServiceError.invalid }
                return .acknowledged
            case .retireContextRevisionBound(let binding):
                let object = try decoder.decode([String: JSONValue].self, from: data)
                guard Set(object.keys) == ["project", "id", "retired"],
                      object["project"] == .string(binding.project), object["id"] == .string(binding.contextID),
                      object["retired"] == .bool(true) else { throw ServiceError.invalid }
                return .acknowledged
            case .contexts(let id):
                let result = try decoder.decode(ContextList.self, from: data)
                guard result.project == id else { throw ServiceError.scopeMismatch }
                guard result.contexts.allSatisfy({ $0.producer == "human-authored" && $0.revision > 0 }) else { throw ServiceError.invalid }
                return .contexts(result)
            case .context(let id, let context):
                let result = try decoder.decode(ContextHistory.self, from: data)
                try result.validate(project: id, id: context)
                return .context(result)
            default:
                _ = try decoder.decode(JSONValue.self, from: data)
                return .acknowledged
            }
        } catch let error as ServiceError { throw error }
        catch { throw ServiceError.invalid }
    }

    private static func currentness(_ value: String) -> Bool {
        value == "current-at-read" || value == "stale-or-unindexed"
    }
    private func command(_ operation: Operation, batch: BatchPlan? = nil) throws -> ([String], Data) {
        func id(_ value: String) throws -> String {
            guard InputPolicy.identifier(value) else { throw ServiceError.invalid }; return value
        }
        func sources(_ values: [String]) throws -> [String] {
            guard InputPolicy.sources(values) else { throw ServiceError.invalid }; return values
        }
        var args: [String]
        var input = Data()
        switch operation {
        case .editContextBatchBound:
            guard let batch else { throw ServiceError.invalid }
            input = try batch.encoded()
            let b = batch.binding
            args = ["context", "batch-edit", b.project, "--expected-root", b.root,
                    "--expected-root-identity", b.rootIdentity, "--expected-incarnation", b.incarnation]
        case .indexIncrementalBound(let request):
            try request.validate()
            let p = request.project
            guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            args = ["index-incremental", p.id, "--expected-root", p.root,
                    "--expected-root-identity", identity, "--expected-incarnation", token,
                    "--expected-snapshot", try ProjectExportDocument.snapshotArgument(p), "--expected-sources"] + p.sources
        case .searchHumanContextKindsBound(let request):
            try request.validate()
            let b = request.binding
            args = ["context", "search", b.project, request.query, "--kinds"] + request.kinds +
                ["--expected-root", b.root, "--expected-root-identity", b.rootIdentity, "--expected-incarnation", b.incarnation]
        case .coverageBound(let request):
            try request.validate()
            let p = request.project
            guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            args = ["project", "coverage", p.id, "--expected-root", p.root,
                    "--expected-root-identity", identity, "--expected-incarnation", token,
                    "--expected-snapshot", try ProjectExportDocument.snapshotArgument(p), "--expected-sources"] + p.sources
        case .inspectSourceAnchorBound(let request):
            try request.validate()
            let p = request.project, a = request.anchor
            guard case .string(let identity) = p.root_identity, let token = p.incarnation,
                  case .string(let snapshot) = p.snapshot else { throw ServiceError.invalid }
            args = ["source", "inspect", p.id, a.path, String(a.line), "--radius", String(request.radius),
                    "--expected-source-hash", a.source_hash, "--expected-root", p.root,
                    "--expected-root-identity", identity, "--expected-incarnation", token,
                    "--expected-snapshot", snapshot, "--expected-sources"] + p.sources
        case .compareHumanContextBound(let request):
            try request.validate()
            let b = request.binding
            args = ["context", "compare", b.project, request.contextID, String(request.from.revision), String(request.to.revision),
                    "--expected-root", b.root, "--expected-root-identity", b.rootIdentity, "--expected-incarnation", b.incarnation]
        case .contextsBound(let binding), .contextBound(let binding, _), .searchHumanContextBound(let binding, _):
            try binding.validate()
            switch operation {
            case .contextBound(_, let context): args = ["context", "show", binding.project, try id(context)]
            case .searchHumanContextBound(_, let query):
                guard InputPolicy.humanSearch(query) else { throw ServiceError.invalid }
                args = ["context", "search", binding.project, query]
            default: args = ["context", "list", binding.project]
            }
            args += ["--expected-root", binding.root, "--expected-root-identity", binding.rootIdentity,
                     "--expected-incarnation", binding.incarnation]
        case .exportProjectBound(let execution):
            let consent = try execution.claim()
            try consent.validate()
            let p = consent.project
            guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            args = ["project", "export", p.id, "--confirm-export-local-content",
                    "--expected-root", p.root, "--expected-root-identity", identity,
                    "--expected-incarnation", token, "--expected-snapshot", try ProjectExportDocument.snapshotArgument(p),
                    "--expected-sources"] + p.sources
        case .queryBound(let p, let query), .prepareContextBound(let p, let query, _),
             .queryTermsBound(let p, let query), .prepareContextTermsBound(let p, let query, _):
            guard InputPolicy.identifier(p.id), case .string(let identity) = p.root_identity,
                  InputPolicy.removal(root: p.root, identity: identity),
                  let token = p.incarnation, InputPolicy.incarnation(token), InputPolicy.sources(p.sources),
                  !query.isEmpty, query.utf8.count <= 256, !query.contains("\0") else { throw ServiceError.invalid }
            let snapshot: String
            if p.snapshot == nil || p.snapshot == .null { snapshot = "none" }
            else {
                guard case .string(let hash) = p.snapshot, hash.utf8.count == 64,
                      hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw ServiceError.invalid }
                snapshot = hash
            }
            let original: String?
            let ranked: Bool
            switch operation {
            case .prepareContextBound(_, _, let text): original = text; ranked = false
            case .prepareContextTermsBound(_, _, let text): original = text; ranked = true
            case .queryTermsBound: original = nil; ranked = true
            default: original = nil; ranked = false
            }
            if let original {
                guard InputPolicy.preparation(query: query, original: original) else { throw ServiceError.invalid }
                args = ["context", "prepare", p.id, query]; input = Data(original.utf8)
                if ranked { args += ["--terms"] }
            } else { args = [ranked ? "query-terms" : "query", p.id, query] }
            args += ["--expected-root", p.root, "--expected-root-identity", identity,
                     "--expected-incarnation", token, "--expected-snapshot", snapshot, "--expected-sources"] + p.sources
        case .refinePreview(let consent):
            try consent.validate()
            guard case .string(let identity) = consent.project.root_identity,
                  case .string(let snapshot) = consent.project.snapshot,
                  let token = consent.project.incarnation else { throw ServiceError.invalid }
            args = ["refine", "preview", try id(consent.project.id), consent.query,
                    "--profile", consent.profile.id, "--model", consent.profile.model, "--endpoint", consent.profile.endpoint,
                    "--expected-root", consent.project.root, "--expected-root-identity", identity,
                    "--expected-incarnation", token, "--expected-snapshot", snapshot, "--confirm-local-inference"]
            if consent.retrievalMode == .rankedTerms { args.append("--terms") }
            input = Data(consent.original.utf8) // Original ONLY on bounded stdin, never argv.
        case .searchHumanContext(let p, let query):
            guard InputPolicy.humanSearch(query) else { throw ServiceError.invalid }
            args = ["context", "search", try id(p), query]
        case .setSourcesBound(let p, let root, let identity, let token, let old, let new):
            guard InputPolicy.removal(root: root, identity: identity), InputPolicy.incarnation(token),
                  !old.contains(where: { $0.hasPrefix("--") }), !new.contains(where: { $0.hasPrefix("--") }) else { throw ServiceError.invalid }
            args = ["project", "sources", try id(p), "--expected-root", root, "--expected-root-identity", identity,
                    "--expected-incarnation", token, "--expected-sources"] + (try sources(old)) + ["--new-sources"] + (try sources(new))
        case .updateContextRevisionBound(let binding, let kind, let text):
            try binding.validate()
            guard InputPolicy.contextKinds.contains(kind), !text.isEmpty, text.utf8.count <= 4096,
                  !text.contains("\0") else { throw ServiceError.invalid }
            args = ["context", "update", binding.project, binding.contextID, kind,
                    "--expected-root", binding.root, "--expected-root-identity", binding.rootIdentity,
                    "--expected-incarnation", binding.incarnation, "--expected-revision", String(binding.revision)]
            input = Data(text.utf8)
        case .retireContextRevisionBound(let binding):
            try binding.validate()
            args = ["context", "retire", binding.project, binding.contextID,
                    "--expected-root", binding.root, "--expected-root-identity", binding.rootIdentity,
                    "--expected-incarnation", binding.incarnation, "--expected-revision", String(binding.revision)]
        case .writeContextBound(let p, let c, let kind, let text, let update, let root, let identity, let token):
            guard InputPolicy.removal(root: root, identity: identity), InputPolicy.incarnation(token),
                  InputPolicy.contextKinds.contains(kind), !text.isEmpty, text.utf8.count <= 4096, !text.contains("\0") else { throw ServiceError.invalid }
            args = ["context", update ? "update" : "add", try id(p), try id(c), kind,
                    "--expected-root", root, "--expected-root-identity", identity, "--expected-incarnation", token]
            input = Data(text.utf8) // Human text is ONLY stdin, never argv.
        case .retireContextBound(let p, let c, let root, let identity, let token):
            guard InputPolicy.removal(root: root, identity: identity), InputPolicy.incarnation(token) else { throw ServiceError.invalid }
            args = ["context", "retire", try id(p), try id(c), "--expected-root", root,
                    "--expected-root-identity", identity, "--expected-incarnation", token]
        case .forgetSource(let p, let path, let root, let identity, let token, let files):
            guard InputPolicy.removal(root: root, identity: identity), InputPolicy.incarnation(token),
                  InputPolicy.sourceMarker(path), files.contains(path), !files.isEmpty,
                  files.allSatisfy(InputPolicy.sourceMarker) else { throw ServiceError.invalid }
            args = ["source", "forget", try id(p), path, "--confirm-forget-source",
                    "--expected-root", root, "--expected-root-identity", identity,
                    "--expected-incarnation", token, "--expected-sources"] + (try sources(files))
        case .forgottenSources(let p): args = ["source", "forgotten", try id(p)]
        case .forgottenSourcesBound(let b):
            try b.validate()
            args = ["source", "forgotten", try id(b.project), "--expected-root", b.root,
                    "--expected-root-identity", b.rootIdentity, "--expected-incarnation", b.incarnation]
        case .forgetContext(let p, let c, let root, let identity, let token, let revision):
            guard InputPolicy.removal(root: root, identity: identity), InputPolicy.incarnation(token),
                  (1...32).contains(revision) else { throw ServiceError.invalid }
            args = ["context", "forget", try id(p), try id(c), "--confirm-forget-local-history",
                    "--expected-root", root, "--expected-root-identity", identity,
                    "--expected-incarnation", token, "--expected-revision", String(revision)]
        case .forgottenContexts(let p): args = ["context", "forgotten", try id(p)]
        case .forgottenContextsBound(let b):
            try b.validate()
            args = ["context", "forgotten", try id(b.project), "--expected-root", b.root,
                    "--expected-root-identity", b.rootIdentity, "--expected-incarnation", b.incarnation]
        case .removeProject(let p, let root, let identity, let token):
            guard InputPolicy.removal(root: root, identity: identity), InputPolicy.incarnation(token) else { throw ServiceError.invalid }
            args = ["project", "remove", try id(p), "--confirm-remove-local-data", "--expected-root", root, "--expected-root-identity", identity, "--expected-incarnation", token]
        case .prepareContext(let p, let query, let original):
            guard InputPolicy.preparation(query: query, original: original) else { throw ServiceError.invalid }
            args = ["context", "prepare", try id(p), query]
            input = Data(original.utf8) // Original is ONLY stdin, never argv.
        case .projects: args = ["project", "list"]
        case .project(let p): args = ["project", "show", try id(p)]
        case .addProject(let p, let root, let files):
            guard root.hasPrefix("/"), !root.contains("\0"), root.utf8.count <= 4096 else { throw ServiceError.invalid }
            args = ["project", "add", try id(p), root] + (try sources(files))
        case .setSources(let p, let files): args = ["project", "sources", try id(p)] + (try sources(files))
        case .index(let p): args = ["index", try id(p)]
        case .indexBound(let p, let root, let identity, let files, let token):
            guard InputPolicy.removal(root: root, identity: identity), !files.isEmpty, InputPolicy.incarnation(token) else { throw ServiceError.invalid }
            args = ["index", try id(p), "--expected-root", root, "--expected-root-identity", identity, "--expected-incarnation", token, "--expected-sources"] + (try sources(files))
        case .query(let p, let text):
            guard !text.isEmpty, text.utf8.count <= 256, !text.contains("\0") else { throw ServiceError.invalid }
            args = ["query", try id(p), text]
        case .contexts(let p): args = ["context", "list", try id(p)]
        case .context(let p, let c): args = ["context", "show", try id(p), try id(c)]
        case .retireContext(let p, let c): args = ["context", "retire", try id(p), try id(c)]
        case .writeContext(let p, let c, let kind, let text, let update):
            guard InputPolicy.contextKinds.contains(kind), !text.isEmpty else { throw ServiceError.invalid }
            args = ["context", update ? "update" : "add", try id(p), try id(c), kind]
            input = Data(text.utf8) // Never in argv or diagnostics.
        }
        return (args, input)
    }

    private static func run(executable: URL, directory: URL, arguments: [String], input: Data,
                            limits: ProcessLimits, cancellation: Cancellation) throws -> Data {
        let out = Pipe(), err = Pipe(), stdin = Pipe()
        defer {
            for handle in [out.fileHandleForReading, out.fileHandleForWriting, err.fileHandleForReading,
                           err.fileHandleForWriting, stdin.fileHandleForReading, stdin.fileHandleForWriting] { try? handle.close() }
        }
        let stdoutFD = out.fileHandleForReading.fileDescriptor
        let stderrFD = err.fileHandleForReading.fileDescriptor
        let inputFD = stdin.fileHandleForWriting.fileDescriptor
        for fd in [stdoutFD, stderrFD, inputFD] {
            let flags = fcntl(fd, F_GETFL)
            guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else { throw ServiceError.unavailable }
        }
        // Suppress SIGPIPE for only this owned pipe, never change a global signal handler.
        guard fcntl(inputFD, F_SETNOSIGPIPE, 1) == 0 else { throw ServiceError.unavailable }
        guard !cancellation.canceled else { throw ServiceError.canceled }
        // Core, not the shell, creates a new store with mode 0700. Spawn in its
        // existing parent until that first explicit core operation creates it.
        let cwd = FileManager.default.fileExists(atPath: directory.path) ? directory : directory.deletingLastPathComponent()
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw ServiceError.unavailable }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { throw ServiceError.unavailable }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
              posix_spawn_file_actions_adddup2(&actions, stdin.fileHandleForReading.fileDescriptor, STDIN_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, out.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, err.fileHandleForWriting.fileDescriptor, STDERR_FILENO) == 0,
              posix_spawn_file_actions_addchdir_np(&actions, cwd.path) == 0 else { throw ServiceError.unavailable }
        // strdup-backed vectors stay alive through spawn; no ambient environ.
        let argv = ([executable.path] + arguments).map { $0.withCString { strdup($0) } } + [nil]
        let environmentValues: [String] = ["LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8"]
        let env = environmentValues.map { $0.withCString { strdup($0) } } + [nil]
        defer { for pointer in argv + env { free(pointer) } }
        guard argv.dropLast().allSatisfy({ $0 != nil }), env.dropLast().allSatisfy({ $0 != nil }) else { throw ServiceError.unavailable }
        var pid: pid_t = 0
        let spawned = argv.withUnsafeBufferPointer { args in
            env.withUnsafeBufferPointer { environment in
                posix_spawn(&pid, executable.path, &actions, &attributes, args.baseAddress!, environment.baseAddress!)
            }
        }
        guard spawned == 0 else { throw ServiceError.unavailable }
        var child = OwnedChild(pid: pid)
        try? out.fileHandleForWriting.close(); try? err.fileHandleForWriting.close(); try? stdin.fileHandleForReading.close()
        let deadline = ProcessInfo.processInfo.systemUptime + limits.seconds
        var failure: ServiceError?
        var output = Data(), stderrCount = 0, inputOffset = 0, inputClosed = false
        func drain(_ fd: Int32, stdout: Bool) {
            var buffer = [UInt8](repeating: 0, count: 4096)
            // Bound each pass even if a malicious child keeps writing forever.
            for _ in 0..<32 {
                let count = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
                if count <= 0 { break }
                if stdout {
                    if output.count + count > limits.stdoutBytes { failure = failure ?? .outputLimit; break }
                    output.append(contentsOf: buffer.prefix(count))
                } else {
                    stderrCount += count
                    if stderrCount > limits.stderrBytes { failure = failure ?? .outputLimit; break }
                }
            }
        }
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if cancellation.canceled { failure = .canceled }
            if now >= deadline { failure = failure ?? .timedOut }
            drain(stdoutFD, stdout: true); drain(stderrFD, stdout: false)
            if !inputClosed {
                if inputOffset < input.count && failure == nil {
                    let written = input.withUnsafeBytes { Darwin.write(inputFD, $0.baseAddress!.advanced(by: inputOffset), input.count - inputOffset) }
                    if written > 0 { inputOffset += written }
                    else if written < 0 && errno != EAGAIN && errno != EINTR { failure = .failed }
                }
                if inputOffset == input.count || failure != nil {
                    try? stdin.fileHandleForWriting.close(); inputClosed = true
                }
            }
            if child.step(now: now, stopping: failure != nil) { break }
            usleep(5_000)
        }
        drain(stdoutFD, stdout: true); drain(stderrFD, stdout: false)
        if let failure { throw failure }
        guard child.status == 0 else { throw ServiceError.failed }
        return output
    }
}
