import Foundation

struct BlockedPath: Sendable, Hashable {
    let path: String
    let rule: String
}

struct ScanItem: Identifiable, Sendable {
    let target: Target
    var paths: [URL] = []
    var commands: [Command] = []
    var note: String?
    var bytes: Int64 = 0
    var files: Int = 0
    var unreadable: Int = 0
    /// Caminhos que a guarda recusou. Aparecem na UI para que a recusa seja visível,
    /// não silenciosa.
    var blocked: [BlockedPath] = []

    var id: String { target.id }
    var hasWork: Bool { !paths.isEmpty || !commands.isEmpty }
}

enum Scanner {
    /// Resolve a origem declarada de um alvo em caminhos concretos e passa cada um
    /// pela guarda de segurança antes de sequer medir.
    static func resolve(_ target: Target) -> (Discovery, [BlockedPath]) {
        var discovery: Discovery
        switch target.source {
        case .paths(let list):
            let urls = list.map(Paths.expand)
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            discovery = Discovery(paths: urls)
        case .glob(let pattern):
            discovery = Discovery(paths: Paths.glob(pattern))
        case .provider(let id):
            discovery = Providers.discover(id)
        }

        var allowed: [URL] = []
        var blocked: [BlockedPath] = []
        for url in discovery.paths {
            do {
                try SafetyGuard.validate(url, allowInsideRepo: target.allowInsideRepo)
                allowed.append(url)
            } catch let r as SafetyGuard.Rejection {
                blocked.append(BlockedPath(path: Paths.display(URL(fileURLWithPath: r.path)), rule: r.rule))
            } catch {
                blocked.append(BlockedPath(path: Paths.display(url), rule: "erro inesperado"))
            }
        }
        discovery.paths = allowed
        // Se todos os caminhos foram recusados, os comandos associados perdem sentido.
        if allowed.isEmpty { discovery.commands = [] }
        return (discovery, blocked)
    }

    private static func scanOne(_ target: Target) async -> ScanItem {
        let (d, blocked) = resolve(target)
        var item = ScanItem(target: target, paths: d.paths, commands: d.commands,
                            note: d.note, blocked: blocked)
        guard !d.paths.isEmpty else { return item }
        let m = await Sizer.measure(d.paths)
        item.bytes = m.bytes
        item.files = m.files
        item.unreadable = m.unreadable
        return item
    }

    /// Varre em paralelo limitado, emitindo cada resultado assim que fica pronto —
    /// a lista na tela vai se preenchendo em vez de aparecer tudo no fim.
    static func scan(_ targets: [Target], maxConcurrent: Int = 4) -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await withTaskGroup(of: ScanItem.self) { group in
                    var pending = targets.makeIterator()
                    for _ in 0..<maxConcurrent {
                        guard let t = pending.next() else { break }
                        group.addTask { await scanOne(t) }
                    }
                    while let done = await group.next() {
                        if Task.isCancelled { break }
                        continuation.yield(done)
                        if let t = pending.next() { group.addTask { await scanOne(t) } }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
