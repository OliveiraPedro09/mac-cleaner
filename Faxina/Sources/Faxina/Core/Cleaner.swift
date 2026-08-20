import Foundation

struct CleanOutcome: Identifiable, Sendable {
    let targetID: String
    let name: String
    let risk: Risk
    var expected: Int64
    var freed: Int64 = 0
    var errors: [String] = []
    var ranCommands: [String] = []
    var id: String { targetID }
    var ok: Bool { errors.isEmpty }
}

enum Cleaner {
    /// Remove um item. A guarda é reexecutada aqui, sobre o caminho já resolvido:
    /// entre a varredura e o clique em "limpar" o sistema de arquivos pode ter mudado.
    static func clean(_ item: ScanItem) async -> CleanOutcome {
        var out = CleanOutcome(targetID: item.target.id, name: item.target.name,
                               risk: item.target.risk, expected: item.bytes)

        // Revalidação obrigatória.
        var confirmed: [URL] = []
        for url in item.paths {
            do {
                try SafetyGuard.validate(url, allowInsideRepo: item.target.allowInsideRepo)
                confirmed.append(url)
            } catch let r as SafetyGuard.Rejection {
                out.errors.append("recusado (\(r.rule)): \(Paths.display(url))")
            } catch {
                out.errors.append("recusado: \(Paths.display(url))")
            }
        }
        guard !confirmed.isEmpty else { return out }

        let before = await Sizer.measure(confirmed).bytes

        if !item.commands.isEmpty {
            // Ferramentas que mantêm índice próprio (simctl) precisam remover elas mesmas.
            for cmd in item.commands {
                let r = Shell.run(cmd.tool, cmd.args)
                out.ranCommands.append(cmd.display)
                if !r.ok {
                    let msg = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    out.errors.append("\(cmd.display): \(msg.isEmpty ? "status \(r.status)" : msg)")
                }
            }
        } else if item.target.requiresAdmin {
            let quoted = confirmed.map { "'" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            let cmd = "/bin/rm -rf " + quoted.joined(separator: " ")
            let r = Shell.runAsAdmin(cmd)
            out.ranCommands.append("sudo " + cmd)
            if !r.ok {
                let msg = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                // Cancelar o prompt de senha volta com -128 no osascript.
                out.errors.append(msg.contains("-128") ? "cancelado pelo usuário"
                                                       : (msg.isEmpty ? "status \(r.status)" : msg))
            }
        } else {
            let fm = FileManager.default
            for url in confirmed {
                do { try fm.removeItem(at: url) }
                catch {
                    let ns = error as NSError
                    let hint = ns.code == NSFileReadNoPermissionError || ns.code == 513
                        ? " (pode exigir Acesso Total ao Disco)" : ""
                    out.errors.append("\(Paths.display(url)): \(ns.localizedDescription)\(hint)")
                }
            }
        }

        // Espaço liberado medido de fato, não estimado: o que sobrou subtrai do total.
        let after = await Sizer.measure(confirmed.filter { FileManager.default.fileExists(atPath: $0.path) }).bytes
        out.freed = max(0, before - after)
        return out
    }
}
