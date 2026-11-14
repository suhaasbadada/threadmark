import Foundation
import CompanionKit

/// Explicit, process-local launch choices. No environment lookup or saved preferences.
struct LaunchConfiguration {
    let executable: URL?
    let dataDirectory: URL?
    let validateOnly: Bool

    static func parse(_ arguments: [String]) throws -> LaunchConfiguration {
        var values: [String: String] = [:]
        var validateOnly = false
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            if key == "--validate-launch-config", !validateOnly {
                validateOnly = true; index += 1; continue
            }
            guard ["--core-binary", "--data-dir"].contains(key), values[key] == nil,
                  index + 1 < arguments.count else { throw ServiceError.invalid }
            let value = arguments[index + 1]
            guard value.hasPrefix("/"), !value.contains("\0") else { throw ServiceError.invalid }
            values[key] = value; index += 2
        }
        guard values.isEmpty || values.count == 2 else { throw ServiceError.invalid }
        guard let binary = values["--core-binary"], let directory = values["--data-dir"] else {
            return LaunchConfiguration(executable: nil, dataDirectory: nil, validateOnly: validateOnly)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: binary, isDirectory: &isDirectory),
              !isDirectory.boolValue, FileManager.default.isExecutableFile(atPath: binary) else {
            throw ServiceError.unavailable
        }
        let url = URL(fileURLWithPath: directory)
        let store: URL
        if FileManager.default.fileExists(atPath: directory) {
            store = try StoreSelection.existingDirectory(url)
        } else {
            store = try StoreSelection.newDirectory(parent: url.deletingLastPathComponent(), name: url.lastPathComponent)
        }
        return LaunchConfiguration(executable: URL(fileURLWithPath: binary), dataDirectory: store, validateOnly: validateOnly)
    }
}
