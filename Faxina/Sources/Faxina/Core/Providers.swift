import Foundation

/// Comparação de versões pontuadas ("26.5" < "26.10", "0.0.401" < "0.0.402").
/// Componentes não numéricos são ignorados, o que basta para os formatos usados aqui.
struct Version: Comparable, Sendable, CustomStringConvertible {
    let parts: [Int]
    let description: String

    init(_ raw: String) {
        description = raw
        parts = raw.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    static func < (a: Version, b: Version) -> Bool {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y }
        }
        return false
    }
    static func == (a: Version, b: Version) -> Bool { a.parts == b.parts }
}

enum Providers {
    static func discover(_ id: ProviderID) -> Discovery {
        switch id {
        case .nvmObsolete:           return nvmObsolete()
        case .simulatorsUnavailable: return simulators(onlyUnavailable: true)
        case .simulatorsOldRuntime:  return simulators(onlyUnavailable: false)
        case .deviceSupportOld:      return deviceSupportOld()
        case .jetbrainsOld:          return jetbrainsOld()
        case .discordOld:            return discordOld()
        case .xcodeArchivesOld:      return xcodeArchivesOld()
        }
    }

    private static func children(_ dir: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles])) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Node via nvm

    /// Mantém a versão default e a maior de cada major. Remove o resto.
    /// Nunca mexe na default, mesmo que ela seja a menor instalada.
    private static func nvmObsolete() -> Discovery {
        let root = Paths.expand("~/.nvm/versions/node")
        let installed = children(root).filter { $0.lastPathComponent.hasPrefix("v") }
        guard installed.count > 1 else { return Discovery() }

        var defaultName: String?
        if let raw = try? String(contentsOf: Paths.expand("~/.nvm/alias/default"), encoding: .utf8) {
            let alias = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            // A default pode ser "v20.15.1", "20.15.1" ou um alias como "lts/*".
            defaultName = installed.first {
                $0.lastPathComponent == alias || $0.lastPathComponent == "v" + alias
            }?.lastPathComponent
        }

        // Maior versão de cada major.
        var newestPerMajor: [Int: URL] = [:]
        for url in installed {
            let v = Version(url.lastPathComponent)
            guard let major = v.parts.first else { continue }
            if let cur = newestPerMajor[major], Version(cur.lastPathComponent) >= v { continue }
            newestPerMajor[major] = url
        }

        var keep = Set(newestPerMajor.values.map(\.path))
        if let d = defaultName { keep.insert(root.appendingPathComponent(d).path) }

        let doomed = installed.filter { !keep.contains($0.path) }
        guard !doomed.isEmpty else { return Discovery() }

        let kept = installed.filter { keep.contains($0.path) }.map(\.lastPathComponent)
        return Discovery(paths: doomed,
                         note: "Mantidas: \(kept.joined(separator: ", "))"
                             + (defaultName.map { " · default: \($0)" } ?? ""))
    }

    // MARK: - Simuladores iOS

    private struct SimDevice {
        let udid: String
        let name: String
        let runtime: String
        let available: Bool
        let booted: Bool
    }

    /// Lê o catálogo do CoreSimulator via simctl. Remoção é feita por `simctl delete`,
    /// nunca apagando o diretório: o CoreSimulator mantém índice próprio e ficaria inconsistente.
    private static func simulators(onlyUnavailable: Bool) -> Discovery {
        let r = Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "--json"])
        guard r.ok, let data = r.stdout.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let byRuntime = root["devices"] as? [String: [[String: Any]]]
        else { return Discovery() }

        var devices: [SimDevice] = []
        for (runtime, list) in byRuntime {
            for d in list {
                guard let udid = d["udid"] as? String else { continue }
                devices.append(SimDevice(
                    udid: udid,
                    name: d["name"] as? String ?? udid,
                    runtime: runtime,
                    available: (d["isAvailable"] as? Bool) ?? true,
                    booted: (d["state"] as? String) == "Booted"))
            }
        }

        let doomed: [SimDevice]
        var note: String?

        if onlyUnavailable {
            doomed = devices.filter { !$0.available && !$0.booted }
        } else {
            // Para cada plataforma, descobre o runtime mais novo e condena os anteriores.
            let usable = devices.filter { $0.available && !$0.booted }
            var newest: [String: Version] = [:]
            for d in usable {
                let (plat, ver) = split(runtime: d.runtime)
                if let cur = newest[plat], cur >= ver { continue }
                newest[plat] = ver
            }
            doomed = usable.filter { d in
                let (plat, ver) = split(runtime: d.runtime)
                return newest[plat].map { ver < $0 } ?? false
            }
            let keptList = newest.map { "\($0.key) \($0.value.description)" }.sorted()
            if !keptList.isEmpty { note = "Runtime mantido: \(keptList.joined(separator: ", "))" }
        }

        guard !doomed.isEmpty else { return Discovery(note: note) }

        let devicesDir = Paths.expand("~/Library/Developer/CoreSimulator/Devices")
        let paths = doomed.map { devicesDir.appendingPathComponent($0.udid) }
        let commands = doomed.map {
            Command(tool: "/usr/bin/xcrun", args: ["simctl", "delete", $0.udid])
        }
        let names = doomed.map { "\($0.name) (\(split(runtime: $0.runtime).0) \(split(runtime: $0.runtime).1))" }
        let detail = names.prefix(6).joined(separator: ", ")
            + (names.count > 6 ? " e \(names.count - 6) mais" : "")

        return Discovery(paths: paths, commands: commands,
                         note: [note, detail].compactMap { $0 }.joined(separator: " · "))
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-26-5" -> ("iOS", 26.5)
    private static func split(runtime: String) -> (String, Version) {
        let tail = runtime.components(separatedBy: "SimRuntime.").last ?? runtime
        let bits = tail.split(separator: "-", maxSplits: 1).map(String.init)
        let platform = bits.first ?? tail
        let version = bits.count > 1 ? bits[1].replacingOccurrences(of: "-", with: ".") : ""
        return (platform, Version(version))
    }

    // MARK: - DeviceSupport de versões antigas

    /// Diretórios no formato "iPhone17,3 26.6 (23G71)". Mantém a maior versão de OS.
    private static func deviceSupportOld() -> Discovery {
        var doomed: [URL] = []
        var kept: [String] = []

        for platform in ["iOS", "watchOS", "tvOS"] {
            let root = Paths.expand("~/Library/Developer/Xcode/\(platform) DeviceSupport")
            let entries = children(root)
            guard entries.count > 1 else { continue }

            let versionOf: (URL) -> Version = { url in
                let tokens = url.lastPathComponent.split(separator: " ").map(String.init)
                // Primeiro token que começa com dígito é a versão do OS.
                return Version(tokens.first { $0.first?.isNumber == true } ?? "0")
            }
            guard let newest = entries.max(by: { versionOf($0) < versionOf($1) }) else { continue }
            let newestVersion = versionOf(newest)

            let old = entries.filter { versionOf($0) < newestVersion }
            if !old.isEmpty {
                doomed += old
                kept.append("\(platform) \(newestVersion.description)")
            }
        }
        guard !doomed.isEmpty else { return Discovery() }
        return Discovery(paths: doomed, note: "Mantido: \(kept.joined(separator: ", "))")
    }

    // MARK: - JetBrains

    /// Diretórios "IntelliJIdea2025.2", "PyCharm2024.1". Mantém a mais nova de cada produto.
    private static func jetbrainsOld() -> Discovery {
        var doomed: [URL] = []
        var kept: [String] = []

        for root in ["~/Library/Application Support/JetBrains", "~/Library/Caches/JetBrains"] {
            let dir = Paths.expand(root)
            let entries = children(dir).filter { url in
                url.hasDirectoryPath && url.lastPathComponent.contains(where: \.isNumber)
            }
            let byProduct = Dictionary(grouping: entries) { url -> String in
                String(url.lastPathComponent.prefix { !$0.isNumber })
            }
            for (product, versions) in byProduct where versions.count > 1 {
                let sorted = versions.sorted { Version($0.lastPathComponent) < Version($1.lastPathComponent) }
                guard let newest = sorted.last else { continue }
                doomed += sorted.dropLast()
                kept.append("\(product)\(Version(newest.lastPathComponent).description)")
            }
        }
        guard !doomed.isEmpty else { return Discovery() }
        return Discovery(paths: doomed, note: "Mantido: \(Set(kept).sorted().joined(separator: ", "))")
    }

    // MARK: - Discord

    /// "app-0.0.402" é a versão em uso; as anteriores são resíduo de update.
    /// Remover a atual impediria o app de abrir, então ela é sempre preservada.
    private static func discordOld() -> Discovery {
        let root = Paths.expand("~/Library/Application Support/discord")
        let apps = children(root).filter { $0.lastPathComponent.hasPrefix("app-") }
        guard apps.count > 1 else { return Discovery() }

        let sorted = apps.sorted { Version($0.lastPathComponent) < Version($1.lastPathComponent) }
        guard let current = sorted.last else { return Discovery() }
        return Discovery(paths: Array(sorted.dropLast()),
                         note: "Versão em uso preservada: \(current.lastPathComponent)")
    }

    // MARK: - Archives do Xcode

    private static func xcodeArchivesOld() -> Discovery {
        let root = Paths.expand("~/Library/Developer/Xcode/Archives")
        let cutoff = Date().addingTimeInterval(-60 * 24 * 3600)
        var doomed: [URL] = []

        for dayDir in children(root) {
            for archive in children(dayDir) where archive.pathExtension == "xcarchive" {
                let vals = try? archive.resourceValues(forKeys: [.contentModificationDateKey])
                if let d = vals?.contentModificationDate, d < cutoff { doomed.append(archive) }
            }
        }
        guard !doomed.isEmpty else { return Discovery() }
        return Discovery(paths: doomed, note: "\(doomed.count) archive(s) com mais de 60 dias")
    }
}
