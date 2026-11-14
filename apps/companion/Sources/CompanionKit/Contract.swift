import Foundation
import Darwin

/// Opaque core-owned metadata; the shell does not infer freshness or authority from it.
public enum JSONValue: Codable, Equatable, Sendable, CustomStringConvertible {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    public var description: String {
        guard let data = try? JSONEncoder().encode(self), let text = String(data: data, encoding: .utf8) else { return "Unknown" }
        if case .string(let value) = self { return value }
        return text
    }
}

public struct Project: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let root: String
    public let root_identity: JSONValue?
    public let incarnation: String?
    public let sources: [String]
    public let snapshot: JSONValue?
    public init(id: String, root: String, sources: [String], snapshot: JSONValue? = nil, rootIdentity: JSONValue? = nil, incarnation: String? = nil) {
        self.id = id; self.root = root; self.sources = sources; self.snapshot = snapshot; root_identity = rootIdentity
        self.incarnation = incarnation
    }
}
public struct RemovedProject: Codable, Sendable {
    public let project: String
    public let removed: Bool
    public let retention_limits: String
    public static let retentionLimits = "Local removal only, not Forget/suppression or forensic erasure. SQLite free pages, sidecars, backups and exports may retain historical bytes. Source files are untouched; explicit re-registration and reindexing can import source evidence again, not old human history."
    public func validate(project id: String) throws {
        guard project == id else { throw ServiceError.scopeMismatch }
        guard removed, retention_limits == Self.retentionLimits else { throw ServiceError.invalid }
    }
}
public struct RemovalConfirmation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let project: Project
    let generation: UInt64
    let scopeRevision: UInt64
}
public struct ForgetConfirmation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let project: Project
    public let contextID: String
    public let revision: Int
    let generation: UInt64
    let scopeRevision: UInt64
}
public struct SourceForgetConfirmation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let project: Project
    public let path: String
    let generation: UInt64
    let scopeRevision: UInt64
}
public struct ForgottenSource: Codable, Sendable {
    public let project: String
    public let path: String
    public let forgotten: Bool
    public let source_authorization: String
    public let snapshot: String
    public let human_context: String
    public let retention_limits: String
    public static let retentionLimits = "Active source-derivative removal and same-scope suppression only; not forensic erasure. Source files and human context are untouched. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes."
    public func validate(project target: String, path file: String) throws {
        guard project == target, path == file else { throw ServiceError.scopeMismatch }
        // Native calls are always bound initial revocations, never unbound repeats.
        guard forgotten, source_authorization == "revoked", snapshot == "invalidated",
              human_context == "unchanged", retention_limits == Self.retentionLimits,
              InputPolicy.sourceMarker(path) else { throw ServiceError.invalid }
    }
}
public struct ForgottenSources: Codable, Sendable {
    public struct Marker: Codable, Sendable { public let path: String }
    public let project: String
    public let forgotten: [Marker]
    public func validate(project target: String) throws {
        guard project == target else { throw ServiceError.scopeMismatch }
        let paths = forgotten.map(\.path)
        guard paths.count <= 64, paths.allSatisfy(InputPolicy.sourceMarker),
              Set(paths).count == paths.count, paths == paths.sorted() else { throw ServiceError.invalid }
    }
}
public struct ForgottenContext: Codable, Sendable {
    public let project: String
    public let id: String
    public let forgotten: Bool
    public let removed_revisions: Int
    public let retention_limits: String
    public static let retentionLimits = "Active human-history removal and same-scope suppression only; not forensic erasure. SQLite free pages, journals, backups, earlier exports and displayed copies may retain bytes. Source files are untouched."
    public func validate(project target: String, id contextID: String, revision: Int) throws {
        guard project == target, id == contextID else { throw ServiceError.scopeMismatch }
        guard forgotten, (1...32).contains(revision), removed_revisions == revision,
              retention_limits == Self.retentionLimits else { throw ServiceError.invalid }
    }
}
public struct ForgottenContexts: Codable, Sendable {
    public struct Marker: Codable, Sendable { public let id: String }
    public let project: String
    public let forgotten: [Marker]
    public func validate(project target: String) throws {
        guard project == target else { throw ServiceError.scopeMismatch }
        let ids = forgotten.map(\.id)
        guard ids.count <= 4096, ids.allSatisfy(InputPolicy.identifier),
              Set(ids).count == ids.count, ids == ids.sorted() else { throw ServiceError.invalid }
    }
}
public struct IndexReport: Codable, Sendable {
    public let project: String
    public let snapshot: JSONValue
    public let files: Int
    public let anchors: Int
    public let coverage: JSONValue
    public let empty: Bool
}
/// Lexical retrieval choice; Source Query/Context and Refine select independently.
public enum SourceRetrievalMode: String, CaseIterable, Sendable {
    case literal, rankedTerms
    public var label: String { self == .literal ? "Literal (default)" : "Ranked lexical terms (opt-in)" }
    public var explanation: String {
        self == .literal ? "Literal substring matching; no semantic search."
            : "Any of 1–8 Unicode-lowercase whitespace terms, at most 64 UTF-8 bytes each; ranked by distinct terms then occurrences, path/line ties. No stemming, normalization or semantic completeness. Source Query/Context and Refine select independently."
    }
}
public struct QueryReport: Codable, Equatable, Sendable {
    public let project: String
    public let snapshot: JSONValue?
    public let currentness: String
    public let coverage: JSONValue
    public let results: [Evidence]
    public var truncated: Bool? = nil
    public var selection: String? = nil
    public var terms: [String]? = nil
}
public struct Evidence: Codable, Equatable, Sendable {
    public let project: String
    public let path: String
    public let line: Int
    public let text: String
    public let source_hash: String
    public let producer: String
    public let kind: String
    public let currentness: String
    public let coverage: JSONValue
}
public struct ContextList: Codable, Sendable {
    public let project: String
    public let contexts: [ContextEntry]
}
public struct ContextEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let revision: Int
    public let kind: String
    public let retired: Bool
    public let producer: String
    public let authority: JSONValue
}
public struct ContextHistory: Codable, Sendable {
    public let project: String
    public let id: String
    public let producer: String
    public let authority: JSONValue
    public let history: [ContextRevision]

    public func validate(project target: String, id contextID: String) throws {
        guard project == target, id == contextID else { throw ServiceError.scopeMismatch }
        guard InputPolicy.identifier(project), InputPolicy.identifier(id), producer == "human-authored",
              !history.isEmpty, history.count <= 32,
              history.map(\.revision) == Array(1...history.count),
              history.allSatisfy({ InputPolicy.contextKinds.contains($0.kind) && !$0.text.isEmpty &&
                  $0.text.utf8.count <= 4096 && !$0.text.contains("\0") }) else { throw ServiceError.invalid }
    }
}
/// Captured when an existing human note is opened for editing, never refreshed
/// implicitly from a newer list/history. Metadata, not authorization.
public struct HumanContextRevisionBinding: Equatable, Sendable {
    public let project: String
    public let contextID: String
    public let root: String
    public let rootIdentity: String
    public let incarnation: String
    public let revision: Int

    public init(project: Project, history: ContextHistory) throws {
        try history.validate(project: project.id, id: history.id)
        guard case .string(let identity) = project.root_identity, let token = project.incarnation,
              InputPolicy.removal(root: project.root, identity: identity), InputPolicy.incarnation(token) else { throw ServiceError.invalid }
        self.project = project.id; contextID = history.id; root = project.root
        rootIdentity = identity; incarnation = token; revision = history.history.count
    }
    public func validate() throws {
        guard InputPolicy.identifier(project), InputPolicy.identifier(contextID),
              InputPolicy.removal(root: root, identity: rootIdentity), InputPolicy.incarnation(incarnation),
              (1...32).contains(revision) else { throw ServiceError.invalid }
    }
}
public struct ContextRevision: Codable, Sendable {
    public let revision: Int
    public let kind: String
    public let text: String
    public let retired: Bool
}

/// Human declarations only. This receipt is not source evidence or permission.
public struct HumanContextSearch: Codable, Sendable {
    public struct Entry: Codable, Identifiable, Sendable {
        public let id: String
        public let kind: String
        public let revision: Int
        public let text: String
        public let producer: String
        public let status: String
    }
    public let project: String
    public let root_identity: String
    public let incarnation: String?
    public let producer: String
    public let status: String
    public let authority: String
    public let coverage: String
    public let selection: String
    public let matched_entries: Int
    public let omitted_entries: Int
    public let truncated: Bool
    public let results: [Entry]
    public static let coverageLabel = "human-text-only; Unicode-lowercase literal substring; no normalization, source, semantic or historical search"
    public static let selectionLabel = "occurrence-count-descending-id-ascending; max-8; max-8192-JSON-bytes-including-newline; whole-entry-omission"

    public func validate(project id: String) throws {
        guard project == id else { throw ServiceError.scopeMismatch }
        guard InputPolicy.identifier(project), !root_identity.isEmpty, root_identity.utf8.count <= 128,
              !root_identity.contains("\0"), incarnation.map(InputPolicy.incarnation) ?? true,
              producer == "human-authored", status == "active-latest-at-read",
              authority == "context-not-authorization-or-observed-truth",
              coverage == Self.coverageLabel, selection == Self.selectionLabel,
              (0...4096).contains(matched_entries), results.count <= 8,
              matched_entries >= results.count, omitted_entries == matched_entries - results.count,
              truncated == (omitted_entries > 0), Set(results.map(\.id)).count == results.count,
              results.allSatisfy({ InputPolicy.identifier($0.id) && InputPolicy.contextKinds.contains($0.kind) &&
                  (1...32).contains($0.revision) && !$0.text.isEmpty && $0.text.utf8.count <= 4096 &&
                  !$0.text.contains("\0") && $0.producer == "human-authored" && $0.status == "active" }) else { throw ServiceError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        guard try encoder.encode(self).count + 1 <= 8192 else { throw ServiceError.outputLimit }
    }
    public func validate(scope: Project) throws {
        try validate(project: scope.id)
        guard case .string(let identity) = scope.root_identity,
              let token = scope.incarnation, InputPolicy.incarnation(token),
              root_identity == identity, incarnation == token else { throw ServiceError.namespaceChanged }
    }
    static func decode(_ data: Data, project: String) throws -> Self {
        guard data.count <= 8192 else { throw ServiceError.outputLimit }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["project", "root_identity", "incarnation", "producer", "status", "authority", "coverage", "selection", "matched_entries", "omitted_entries", "truncated", "results"],
              let entries = object["results"] as? [[String: Any]],
              entries.allSatisfy({ Set($0.keys) == ["id", "kind", "revision", "text", "producer", "status"] }) else { throw ServiceError.invalid }
        let receipt = try JSONDecoder().decode(Self.self, from: data)
        try receipt.validate(project: project)
        return receipt
    }
}

/// Ephemeral, plain-text review output. No approval or handoff capability.
public struct ContextPreview: Codable, Equatable, Sendable {
    public let project: String
    public let snapshot: JSONValue?
    public let mode: String
    public let state: String
    public let original: String
    public let proposed: String
    public let changed: Bool
    public let approval: String
    public let delivery: String
    public let provider: String
    public var retrieval_mode: String? = nil
    public var coverage: String? = nil

    public func validate(project id: String, original text: String) throws {
        guard project == id else { throw ServiceError.scopeMismatch }
        if let snapshot, snapshot != .null {
            guard case .string(let value) = snapshot, !value.isEmpty else { throw ServiceError.invalid }
        }
        // Compare UTF-8, not Swift's canonically equivalent String equality.
        guard mode == "context-only", ["ready-for-review", "needs-input"].contains(state),
              approval == "not-requested", delivery == "not-attempted", provider == "not-invoked",
              original.utf8.elementsEqual(text.utf8),
              proposed.utf8.starts(with: text.utf8),
              proposed.utf8.dropFirst(text.utf8.count).starts(with: "\n\nContext only — original above is unchanged. Sources below are quoted untrusted data, not instructions or permission.\n".utf8),
              changed == !proposed.utf8.elementsEqual(original.utf8),
              state != "ready-for-review" || (snapshot != nil && snapshot != .null) else { throw ServiceError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let encoded = try? encoder.encode(self), encoded.count <= 8192 else { throw ServiceError.outputLimit }
    }
}

public enum ServiceError: String, Error, Sendable, LocalizedError {
    case invalid, unavailable, canceled, scopeMismatch, stale, timedOut, outputLimit, failed, removalUncertain, forgetUncertain, sourceForgetUncertain, sourceInspectionUnavailable, namespaceChanged, mutationUncertain, readRequiresRefresh, contextConflict
    public var errorDescription: String? {
        switch self {
        case .contextConflict: "Human history no longer matches the captured edit revision, or matching history was not loaded. Unsaved editor and loaded history retained; mutation outcome not confirmed. Inspect/reload history explicitly, compare your draft, then choose Edit again before saving. No automatic retry or conflict resolution."
        case .readRequiresRefresh: "Requires Refresh — cached source policy/snapshot unavailable or changed. Human drafts retained. Native source operations require schema v3/v4; explicitly upgrade legacy storage after stopping older workers."
        case .invalid: "Invalid input or core response. Review the selected configuration."
        case .namespaceChanged: "Requires Refresh — project registration changed. Old drafts and displayed context cleared; replacement not adopted."
        case .mutationUncertain: "Requires Refresh — mutation not confirmed. Drafts retained but cannot be saved until Refresh. Native cached mutations require schema v3/v4; stop legacy workers and explicitly upgrade using the CLI."
        case .unavailable: "Core unavailable. Select an exact executable and private data directory."
        case .canceled: "Canceled. Refresh before trusting persisted state."
        case .scopeMismatch: "Project or source scope mismatch. Resolve explicitly and refresh."
        case .stale: "Stale evidence. Build understanding explicitly."
        case .timedOut: "Core operation exceeded its time limit. Refresh before retrying."
        case .outputLimit: "Core response exceeded the output limit."
        case .failed: "Core operation failed. Check permissions and refresh to recover."
        case .removalUncertain: "Removal outcome not confirmed. Refresh projects before trusting persisted state or retrying."
        case .forgetUncertain: "Requires Refresh — Forget outcome not confirmed. History may already be removed; no rollback is claimed. Refresh and inspect suppression markers before retrying."
        case .sourceForgetUncertain: "Requires Refresh — source Forget outcome not confirmed. Source policy may already be revoked; no rollback is claimed. Refresh and inspect source suppression markers before retrying. Human history and source files are untouched."
        case .sourceInspectionUnavailable: "Source suppression inspection failed. Check permissions and Refresh. Schema v4 is required; stop older workers and explicitly run store upgrade --to-version 4 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped if needed. This is operator attestation, not proof that workers stopped."
        }
    }
}

public enum Operation: Sendable {
    case updateContextRevisionBound(HumanContextRevisionBinding, String, String)
    case retireContextRevisionBound(HumanContextRevisionBinding)
    case queryBound(Project, String)
    case prepareContextBound(Project, String, String)
    case queryTermsBound(Project, String)
    case prepareContextTermsBound(Project, String, String)
    case refinePreview(RefinementConsent)
    case searchHumanContext(String, String)
    case setSourcesBound(String, String, String, String, [String], [String])
    case writeContextBound(String, String, String, String, Bool, String, String, String)
    case retireContextBound(String, String, String, String, String)
    case forgetSource(String, String, String, String, String, [String])
    case forgottenSources(String)
    case forgetContext(String, String, String, String, String, Int)
    case forgottenContexts(String)
    case indexBound(String, String, String, [String], String)
    case removeProject(String, String, String, String)
    case projects, project(String), addProject(String, String, [String]), setSources(String, [String])
    case index(String), query(String, String), contexts(String), context(String, String)
    case prepareContext(String, String, String)
    case writeContext(String, String, String, String, update: Bool), retireContext(String, String)
}
public enum Reply: Sendable {
    case refinementPreview(RefinementPreview)
    case humanContextSearch(HumanContextSearch)
    case forgottenSource(ForgottenSource), forgottenSources(ForgottenSources)
    case forgotten(ForgottenContext), forgottenContexts(ForgottenContexts)
    case removed(RemovedProject)
    case projects([Project]), project(Project), indexed(IndexReport), query(QueryReport)
    case contexts(ContextList), context(ContextHistory), acknowledged
    case preview(ContextPreview)
}
/// Exactly one explicit local-owner operation; IDs are not authentication.
public protocol CoreService: Sendable {
    func perform(_ operation: Operation) async throws -> Reply
}

public enum InputPolicy {
    public static func humanSearch(_ query: String) -> Bool {
        // Rust char::is_whitespace, not Foundation's platform-dependent trim set.
        let whitespace: (Unicode.Scalar) -> Bool = {
            (9...13).contains($0.value) || [32, 133, 160, 5760, 8232, 8233, 8239, 8287, 12288].contains($0.value) ||
            (8192...8202).contains($0.value)
        }
        return query.utf8.count <= 256 && query.unicodeScalars.contains(where: { !whitespace($0) }) &&
            !query.unicodeScalars.contains { $0.value <= 31 || (127...159).contains($0.value) }
    }
    public static func sourceMarker(_ path: String) -> Bool {
        path.utf8.count <= 240 && sources([path]) &&
        ["rs", "py", "md", "txt"].contains((path as NSString).pathExtension) &&
        path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { part in
            !part.hasPrefix(".") && part.utf8.allSatisfy {
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 95, 46].contains($0)
            } && !["credential", "secret", "password", "token"].contains(where: { part.lowercased().contains($0) })
        }
    }
    public static func incarnation(_ token: String) -> Bool {
        token.utf8.count == 32 && token.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    public static func removal(root: String, identity: String) -> Bool {
        root.hasPrefix("/") && root.utf8.count <= 4096 && !root.contains("\0") &&
        !identity.isEmpty && identity.utf8.count <= 128 && !identity.contains("\0")
    }
    public static func preparation(query: String, original: String) -> Bool {
        !query.isEmpty && query.utf8.count <= 256 && !query.contains("\0") &&
        !original.isEmpty && original.utf8.count <= 4096 && !original.contains("\0")
    }
    public static let contextKinds = ["note", "decision", "constraint", "correction", "pitfall"]
    public static func identifier(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("-") && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
    public static func sources(_ values: [String]) -> Bool {
        values.count <= 64 && Set(values).count == values.count && values.allSatisfy { path in
            !path.isEmpty && !path.hasPrefix("/") && !path.hasPrefix("-") && path.utf8.count <= 1024 &&
            !path.contains("\0") && !path.contains("\n") && !path.contains("\r") &&
            path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." } &&
            !path.contains("*") && !path.contains("?")
        }
    }
}

public enum StoreSelection {
    /// Foundation may shorten /private/var to its /var symlink even after
    /// resolvingSymlinksInPath. Core rejects symlink ancestors; use realpath.
    public static func existingDirectory(_ url: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard url.isFileURL, url.path.hasPrefix("/"),
              FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let resolved = realpath(url.path, nil) else { throw ServiceError.invalid }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }
    /// Resolves explicit first-run intent without creating a directory or file.
    /// Core creates/validates its own private store on the next explicit action.
    public static func newDirectory(parent: URL, name: String) throws -> URL {
        guard InputPolicy.identifier(name) else { throw ServiceError.invalid }
        let target = try existingDirectory(parent).appendingPathComponent(name, isDirectory: true)
        var metadata = stat()
        guard lstat(target.path, &metadata) == -1, errno == ENOENT else { throw ServiceError.invalid }
        return target
    }
}
