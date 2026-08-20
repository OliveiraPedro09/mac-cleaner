import Foundation

enum Paths {
    static let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

    /// Expande `~` e normaliza. Não resolve symlinks — isso é papel da guarda.
    static func expand(_ raw: String) -> URL {
        let s = (raw as NSString).expandingTildeInPath
        return URL(fileURLWithPath: s).standardizedFileURL
    }

    /// Encurta para exibição: `/Users/x/Library/Caches` -> `~/Library/Caches`.
    static func display(_ url: URL) -> String {
        let p = url.path
        let h = home.path
        return p == h ? "~" : (p.hasPrefix(h + "/") ? "~" + p.dropFirst(h.count) : p)
    }

    /// Resolve um glob simples via FileManager, sem depender de shell.
    /// Suporta `*` em qualquer número de componentes.
    static func glob(_ pattern: String) -> [URL] {
        let expanded = (pattern as NSString).expandingTildeInPath
        let parts = expanded.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var frontier = [URL(fileURLWithPath: "/")]
        let fm = FileManager.default

        for part in parts {
            guard part.contains("*") else {
                frontier = frontier.map { $0.appendingPathComponent(part) }
                    .filter { fm.fileExists(atPath: $0.path) }
                continue
            }
            var next: [URL] = []
            for dir in frontier {
                let kids = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
                for kid in kids where matches(kid, part) {
                    next.append(dir.appendingPathComponent(kid))
                }
            }
            frontier = next
        }
        return frontier.map(\.standardizedFileURL).sorted { $0.path < $1.path }
    }

    /// Casamento de curinga `*` em um único componente de caminho.
    private static func matches(_ name: String, _ pattern: String) -> Bool {
        let chunks = pattern.split(separator: "*", omittingEmptySubsequences: false).map(String.init)
        guard chunks.count > 1 else { return name == pattern }
        var rest = Substring(name)

        if let first = chunks.first, !first.isEmpty {
            guard rest.hasPrefix(first) else { return false }
            rest = rest.dropFirst(first.count)
        }
        if let last = chunks.last, !last.isEmpty {
            guard rest.hasSuffix(last), rest.count >= last.count else { return false }
            rest = rest.dropLast(last.count)
        }
        for mid in chunks.dropFirst().dropLast() where !mid.isEmpty {
            guard let r = rest.range(of: mid) else { return false }
            rest = rest[r.upperBound...]
        }
        return true
    }
}
