import Foundation

enum Shell {
    struct Result: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    static func run(_ tool: String, _ args: [String], timeout: TimeInterval = 120) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err

        do { try p.run() } catch {
            return Result(status: -1, stdout: "", stderr: "falha ao executar \(tool): \(error.localizedDescription)")
        }

        // Lê antes de esperar, para não travar em pipe cheio com saída grande (simctl -j é verboso).
        let oData = out.fileHandleForReading.readDataToEndOfFile()
        let eData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        return Result(status: p.terminationStatus,
                      stdout: String(decoding: oData, as: UTF8.self),
                      stderr: String(decoding: eData, as: UTF8.self))
    }

    /// Executa com privilégio de administrador, via prompt nativo do sistema.
    /// Usado apenas para caminhos root-owned fora da home (wallpapers do macOS).
    static func runAsAdmin(_ command: String) -> Result {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return run("/usr/bin/osascript",
                   ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
    }
}
