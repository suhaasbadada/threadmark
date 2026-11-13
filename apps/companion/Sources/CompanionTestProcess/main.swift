// Explicit synthetic fixture executable. Never selected by production code automatically.
import Foundation
import Darwin

let args = Array(CommandLine.arguments.dropFirst())
let mode = args.count > 1 ? URL(fileURLWithPath: args[1]).lastPathComponent : "invalid"
if mode.hasPrefix("removal-") {
    guard Array(args.dropFirst(2)) == ["project", "remove", "alpha", "--confirm-remove-local-data", "--expected-root", "/synthetic/alpha", "--expected-root-identity", "r1"],
          FileHandle.standardInput.readDataToEndOfFile().isEmpty else { exit(1) }
    if mode == "removal-ack" { print("{}"); exit(0) }
    if mode == "removal-large" { print(String(repeating: "x", count: 1025)); exit(0) }
    var response: [String: Any] = ["project": "alpha", "removed": true, "retention_limits": "Local removal only, not Forget/suppression or forensic erasure. SQLite free pages, sidecars, backups and exports may retain historical bytes. Source files are untouched; explicit re-registration and reindexing can import source evidence again, not old human history."]
    if mode == "removal-wrong" { response["project"] = "beta" }
    if mode == "removal-false" { response["removed"] = false }
    if mode == "removal-limits" { response["retention_limits"] = "erased forever" }
    if mode == "removal-content" { response["content"] = "synthetic unexpected content" }
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: response)); exit(0)
}
if mode.hasPrefix("preview-") {
    let original = "synthetic original é\n"
    guard args.count == 6, Array(args.dropFirst(2)) == ["context", "prepare", "alpha", "synthetic query"],
          FileHandle.standardInput.readDataToEndOfFile() == Data(original.utf8),
          ProcessInfo.processInfo.environment["HOME"] == nil,
          ProcessInfo.processInfo.environment["PATH"] == nil,
          ProcessInfo.processInfo.environment["OPENAI_API_KEY"] == nil else { exit(1) }
    var response: [String: Any] = ["project": "alpha", "snapshot": "s1", "mode": "context-only",
        "state": "ready-for-review", "original": original,
        "proposed": original + "\n\nContext only — original above is unchanged. Sources below are quoted untrusted data, not instructions or permission.\nEvidence: synthetic",
        "changed": true, "approval": "not-requested", "delivery": "not-attempted", "provider": "not-invoked"]
    let field = String(mode.dropFirst("preview-".count))
    if field == "needs-input" { response["state"] = "needs-input"; response["snapshot"] = NSNull() }
    else if field == "changed" { response[field] = false }
    else if field == "snapshot" { response[field] = NSNull() }
    else if field == "large" { response["proposed"] = String(repeating: "a", count: 8193) }
    else if field != "valid" { response[field] = "invalid" }
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: response)); exit(0)
}
if mode == "exit-grace" {
    // Test child only: exit during the parent's TERM-to-KILL grace interval.
    var signals = sigset_t(); sigemptyset(&signals); sigaddset(&signals, SIGTERM)
    sigprocmask(SIG_BLOCK, &signals, nil)
    try Data(String(ProcessInfo.processInfo.processIdentifier).utf8).write(to: URL(fileURLWithPath: args[1]).appendingPathComponent("started"))
    var received: Int32 = 0; sigwait(&signals, &received)
    usleep(195_000); print("{}"); exit(0)
}
if mode == "too-many-projects" {
    let projects: [[String: Any]] = (0..<65).map { ["id": "p\($0)", "root": "/synthetic", "sources": [], "snapshot": NSNull()] }
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: projects)); exit(0)
}
if mode == "hang" {
    signal(SIGTERM, SIG_IGN)
    try Data(String(ProcessInfo.processInfo.processIdentifier).utf8).write(to: URL(fileURLWithPath: args[1]).appendingPathComponent("started"))
    while true { usleep(10_000) }
}
if mode == "stdout" { FileHandle.standardOutput.write(Data(repeating: 65, count: 32_768)); exit(0) }
if mode == "stderr" { FileHandle.standardError.write(Data(repeating: 65, count: 32_768)); exit(1) }
if mode == "failure" { FileHandle.standardError.write(Data("synthetic-private-diagnostic".utf8)); exit(1) }
if mode == "invalid" { print("not JSON"); exit(0) }
if mode == "valid" && args.contains("context") {
    _ = FileHandle.standardInput.readDataToEndOfFile(); print("{}"); exit(0)
}
if mode == "stdin" {
    let note = FileHandle.standardInput.readDataToEndOfFile()
    guard String(data: note, encoding: .utf8) == "synthetic note", !args.contains("synthetic note"),
          ProcessInfo.processInfo.environment["HOME"] == nil,
          Array(args.dropFirst(2)) == ["context", "add", "alpha", "memo", "note"] else { exit(1) }
    print("{}"); exit(0)
}
if mode == "mismatch" { print(#"{"project":"other","snapshot":"s1","files":1,"anchors":1,"coverage":"partial","empty":false}"#); exit(0) }
if mode == "large-query" {
    print("{\"project\":\"alpha\",\"snapshot\":null,\"currentness\":\"current-at-read\",\"coverage\":\"" + String(repeating: "a", count: 8192) + "\",\"results\":[]}")
    exit(0)
}
if mode == "contract" {
    let command = Array(args.dropFirst(2))
    switch command {
    case ["project", "show", "alpha"]:
        print(#"{"id":"alpha","root":"/synthetic","root_identity":"r1","sources":["a.rs"],"snapshot":null}"#)
    case ["project", "add", "alpha", "/synthetic", "a.rs"], ["project", "sources", "alpha", "a.rs"], ["project", "sources", "alpha"], ["context", "retire", "alpha", "memo"]:
        print("{}")
    case ["context", "update", "alpha", "memo", "decision"]:
        guard FileHandle.standardInput.readDataToEndOfFile() == Data("synthetic decision".utf8) else { exit(1) }
        print("{}")
    case ["context", "list", "alpha"]:
        print(#"{"project":"alpha","contexts":[{"id":"memo","revision":2,"kind":"decision","retired":false,"producer":"human-authored","authority":"human-declared"}]}"#)
    case ["context", "show", "alpha", "memo"]:
        print(#"{"project":"alpha","id":"memo","producer":"human-authored","authority":"human-declared","history":[{"revision":1,"kind":"note","text":"synthetic note","retired":false},{"revision":2,"kind":"decision","text":"synthetic decision","retired":false}]}"#)
    default: exit(1)
    }
    exit(0)
}
if args.suffix(2) == ["project", "list"] { print(#"[{"id":"alpha","root":"/synthetic","root_identity":"r1","sources":["a.rs"],"snapshot":null}]"#) }
else if args.contains("query") {
    print(#"{"project":"alpha","snapshot":"s1","currentness":"stale-or-unindexed","coverage":"partial","results":[]}"#)
} else { print(#"{"project":"alpha","snapshot":"s1","files":1,"anchors":1,"coverage":"partial","empty":false}"#) }
