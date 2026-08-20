import Foundation

/// Um diretório grande que o catálogo não cobre.
///
/// Existe porque catálogo fixo é justamente o ponto cego de todo limpador de disco:
/// os maiores consumidores de espaço numa máquina real costumam ser específicos dela
/// — mídia de um app de mensagens, assets de um jogo, um modelo baixado à mão.
struct BigDir: Identifiable, Sendable {
    let url: URL
    let bytes: Int64
    /// Já contemplado por algum alvo do catálogo (total ou parcialmente).
    let coveredByCatalog: Bool
    var id: String { url.path }
    var display: String { Paths.display(url) }
}

enum BigDirs {
    private static let roots = [
        "~", "~/Library", "~/Library/Application Support", "~/Library/Containers",
        "~/Library/Group Containers", "~/Library/Caches", "~/Library/Developer",
        "/Applications",
    ]

    /// Mede os filhos diretos de um conjunto de raízes e devolve os que passam do limite.
    /// Não desce recursivamente na listagem: mede o total de cada filho, mas só lista
    /// um nível — senão a lista viraria ruído.
    static func scan(minBytes: Int64 = 500_000_000,
                     onProgress: @Sendable @escaping (String) -> Void = { _ in }) async -> [BigDir] {
        let catalogPaths = Set(Catalog.all.flatMap { target -> [String] in
            let (d, _) = Scanner.resolve(target)
            return d.paths.map(\.path)
        })

        var seen = Set<String>()
        var found: [BigDir] = []
        let fm = FileManager.default

        for root in roots {
            let dir = Paths.expand(root)
            guard let kids = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                         options: []) else { continue }
            for kid in kids {
                if Task.isCancelled { return found.sorted { $0.bytes > $1.bytes } }
                let path = kid.standardizedFileURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)

                // Não medir dentro de raízes protegidas — nada aqui é acionável de qualquer forma.
                if (try? SafetyGuard.validate(kid)) == nil, !isInterestingProtected(kid) { continue }

                onProgress(Paths.display(kid))
                let m = await Sizer.measure(kid)
                guard m.bytes >= minBytes else { continue }

                let covered = catalogPaths.contains { $0 == path || $0.hasPrefix(path + "/") }
                found.append(BigDir(url: kid, bytes: m.bytes, coveredByCatalog: covered))
            }
        }
        return found.sorted { $0.bytes > $1.bytes }
    }

    /// Downloads é protegido contra remoção automática, mas continua valendo *mostrar*
    /// quando está ocupando dezenas de GB.
    private static func isInterestingProtected(_ url: URL) -> Bool {
        ["Downloads", "Documents", "Movies", "Pictures", "Music"].contains(url.lastPathComponent)
    }
}
