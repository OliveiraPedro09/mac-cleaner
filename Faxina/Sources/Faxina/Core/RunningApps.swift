import AppKit

struct BlockingApp: Identifiable, Sendable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

@MainActor
enum RunningApps {
    private static let names: [String: String] = [
        "com.apple.dt.Xcode": "Xcode",
        "com.apple.iphonesimulator": "Simulator",
        "com.google.Chrome": "Google Chrome",
        "com.apple.Safari": "Safari",
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.spotify.client": "Spotify",
        "com.hnc.Discord": "Discord",
        "com.valvesoftware.steam": "Steam",
        "com.docker.docker": "Docker Desktop",
        "net.whatsapp.WhatsApp": "WhatsApp",
    ]

    static func label(for bundleID: String) -> String {
        names[bundleID] ?? bundleID
    }

    /// Quais dos bundle IDs informados estão rodando agora.
    static func running(among bundleIDs: [String]) -> [BlockingApp] {
        let live = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return bundleIDs.filter(live.contains).map { BlockingApp(bundleID: $0, name: label(for: $0)) }
    }

    /// Pede o encerramento normal (o app pode pedir para salvar). Retorna false se não achou.
    @discardableResult
    static func quit(_ bundleID: String) -> Bool {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
        guard !apps.isEmpty else { return false }
        apps.forEach { $0.terminate() }
        return true
    }
}
