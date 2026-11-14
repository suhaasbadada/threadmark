// Synthetic comparison transport fixture only; never discovered by production.
import Foundation
import Darwin

func runComparisonFixture(_ args: [String]) {
    guard args.count > 1, args[0] == "--data-dir" else { return }
    let mode = URL(fileURLWithPath: args[1]).lastPathComponent
    guard mode.hasPrefix("human-comparison-") else { return }
    guard Array(args.dropFirst(2)) == ["context", "compare", "alpha", "memo", "1", "2",
        "--expected-root", "/synthetic/alpha", "--expected-root-identity", "r1",
        "--expected-incarnation", String(repeating: "a", count: 32)],
        FileHandle.standardInput.readDataToEndOfFile().isEmpty else { exit(1) }
    if mode == "human-comparison-hang" { while true { pause() } }
    var text = #"{"version":"human-context-comparison-v1","project":"alpha","id":"memo","producer":"human-authored","authority":"context-not-authorization-or-observed-truth","from":{"revision":1,"kind":"note","retired":false},"to":{"revision":2,"kind":"note","retired":false},"text_changed":true,"kind_changed":false,"retirement_changed":false,"delta":{"algorithm":"common-prefix-suffix-logical-lines-not-minimal","prefix":"head\n","from":"old\r\n","to":"new\n","suffix":"tail"}}"#
    switch mode {
    case "human-comparison-duplicate": text = text.replacingOccurrences(of: #""delta":{"# , with: #""delta":{"prefix":"","#)
    case "human-comparison-wrongpair": text = text.replacingOccurrences(of: #""revision":2"#, with: #""revision":1"#)
    case "human-comparison-wrongdelta": text = text.replacingOccurrences(of: #""from":"old\r\n""#, with: #""from":"old\n""#)
    case "human-comparison-wrongflags": text = text.replacingOccurrences(of: #""text_changed":true"#, with: #""text_changed":false"#)
    case "human-comparison-unexpected": text = "{\"extra\":true," + text.dropFirst()
    case "human-comparison-frames": text += text
    case "human-comparison-partial": text = String(text.prefix(text.count / 2))
    default: break
    }
    var bytes = Data(text.utf8)
    if mode == "human-comparison-limit" || mode == "human-comparison-overflow" {
        bytes.append(Data(repeating: 32, count: 65535 - bytes.count + (mode == "human-comparison-overflow" ? 1 : 0)))
    }
    if mode != "human-comparison-no-newline" { bytes.append(10) }
    FileHandle.standardOutput.write(bytes); exit(0)
}
