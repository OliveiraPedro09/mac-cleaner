import Foundation

enum ReportWriter {
    static func markdown(items: [ScanItem], outcomes: [CleanOutcome],
                         before: DiskInfo, after: DiskInfo) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        var s = "# Relatório de limpeza — Faxina\n\n_\(df.string(from: Date()))_\n\n"

        s += "## Disco\n\n"
        s += "| Métrica | Antes | Depois |\n|---|---|---|\n"
        s += "| Livre | \(before.free.humanSize) | **\(after.free.humanSize)** |\n"
        s += "| Usado | \(before.used.humanSize) | \(after.used.humanSize) |\n"
        s += "| Ocupação | \(before.percent)% | **\(after.percent)%** |\n\n"
        let delta = after.free - before.free
        s += "**Total recuperado: \(delta.humanSize)**\n\n"

        for risk in Risk.allCases {
            let group = outcomes.filter { $0.risk == risk }
            guard !group.isEmpty else { continue }
            let sum = group.reduce(Int64(0)) { $0 + $1.freed }
            s += "## \(risk.title) — \(sum.humanSize)\n\n"
            s += "| Item | Liberado | Situação |\n|---|---|---|\n"
            for o in group.sorted(by: { $0.freed > $1.freed }) {
                let status = o.ok ? "ok" : "falhas: \(o.errors.count)"
                s += "| \(o.name) | \(o.freed.humanSize) | \(status) |\n"
            }
            s += "\n"
        }

        let failed = outcomes.filter { !$0.ok }
        if !failed.isEmpty {
            s += "## Erros\n\n"
            for o in failed {
                s += "**\(o.name)**\n"
                for e in o.errors { s += "- \(e)\n" }
                s += "\n"
            }
        }

        let blocked = items.flatMap(\.blocked)
        if !blocked.isEmpty {
            s += "## Caminhos recusados pela guarda de segurança\n\n"
            s += "| Caminho | Motivo |\n|---|---|\n"
            for b in blocked { s += "| `\(b.path)` | \(b.rule) |\n" }
            s += "\n"
        }

        let doneIDs = Set(outcomes.map(\.targetID))
        let untouched = items.filter { item in item.hasWork && !doneIDs.contains(item.target.id) }
        if !untouched.isEmpty {
            s += "## Não executado (disponível)\n\n"
            s += "| Item | Tam. | Faixa |\n|---|---|---|\n"
            for i in untouched.sorted(by: { $0.bytes > $1.bytes }) where i.bytes > 0 {
                s += "| \(i.target.name) | \(i.bytes.humanSize) | \(i.target.risk.rawValue) |\n"
            }
            s += "\n"
        }

        s += "---\n_Gerado por Faxina. Cada item removido tem função técnica e consequência "
        s += "documentadas no catálogo do app._\n"
        return s
    }
}
