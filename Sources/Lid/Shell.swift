import Foundation

/// Tiny helper to run a command and capture stdout. Returns nil on launch error.
enum Shell {
    static func capture(_ path: String, _ args: [String]) -> String? {
        ProcessRunner.capture(path, args)
    }
}
