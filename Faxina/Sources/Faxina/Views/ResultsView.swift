import SwiftUI

struct ResultsView: View {
    let model: AppModel

    private var delta: Int64 { model.disk.free - model.diskBefore.free }
    private var failures: [CleanOutcome] { model.outcomes.filter { !$0.ok } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary

                if !failures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(failures.count) item(ns) com falha", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                        ForEach(failures) { o in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.name).font(.system(size: 11.5, weight: .medium))
                                ForEach(Array(o.errors.enumerated()), id: \.offset) { _, e in
                                    Text(e).font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.leading, 14)
                        }
                    }
                    .padding(14)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.outcomes.sorted { $0.freed > $1.freed }) { o in
                        HStack(spacing: 10) {
                            Image(systemName: o.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(o.ok ? .green : .orange)
                            Text(o.name).font(.system(size: 12))
                            Spacer()
                            if o.freed != o.expected && o.expected > 0 {
                                Text("de \(o.expected.humanSize)")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                            Text(o.freed.humanSize)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
            .padding(20)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(delta > 0 ? delta.humanSize : model.totalFreed.humanSize)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
                Text("recuperados")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                stat("Livre antes", model.diskBefore.free.humanSize)
                stat("Livre agora", model.disk.free.humanSize)
                stat("Ocupação", "\(model.diskBefore.percent)% → \(model.disk.percent)%")
            }

            Text("Código, credenciais, chaves SSH e configurações não foram tocados — a guarda de segurança recusa esses caminhos por construção.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}
