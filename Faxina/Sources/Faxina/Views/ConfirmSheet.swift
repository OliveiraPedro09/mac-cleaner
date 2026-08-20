import SwiftUI

/// Última tela antes de qualquer remoção. Mostra o caminho exato de tudo que será
/// afetado — nada é removido sem estar escrito aqui.
struct ConfirmSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    private let phrase = "APAGAR"

    private var needsPhrase: Bool { model.involvesUserData }
    private var phraseOK: Bool { !needsPhrase || typed.trimmingCharacters(in: .whitespaces) == phrase }
    private var canProceed: Bool { phraseOK && model.pendingBlockers.isEmpty && !model.selectedItems.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 22)).foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Revisar antes de limpar").font(.system(size: 14, weight: .semibold))
                    Text("\(model.selectedItems.count) itens · \(model.selectedBytes.humanSize) · remoção permanente")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Risk.allCases, id: \.self) { risk in
                        let group = model.selectedItems.filter { $0.target.risk == risk }
                        if !group.isEmpty { section(risk, group) }
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 340)

            Divider()

            VStack(spacing: 12) {
                if !model.pendingBlockers.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Feche antes de continuar:").font(.system(size: 11.5, weight: .medium))
                        ForEach(model.pendingBlockers) { app in
                            Button("Encerrar \(app.name)") { model.quit(app) }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                        Spacer()
                    }
                }

                if needsPhrase {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("A seleção inclui dados de usuário, não só cache.")
                                .font(.system(size: 11.5, weight: .medium))
                            Text("Digite \(phrase) para confirmar que existe cópia do que importa.")
                                .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField(phrase, text: $typed)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }

                HStack {
                    Button("Cancelar") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Limpar \(model.selectedBytes.humanSize)") {
                        dismiss()
                        model.clean()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!canProceed)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 640)
    }

    private func section(_ risk: Risk, _ group: [ScanItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: risk.symbol).font(.system(size: 10)).foregroundStyle(risk.tint)
                Text(risk.title).font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(group.reduce(Int64(0)) { $0 + $1.bytes }.humanSize)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ForEach(group.sorted { $0.bytes > $1.bytes }) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.target.name).font(.system(size: 11.5, weight: .medium))
                        Spacer()
                        Text(item.bytes.humanSize)
                            .font(.system(size: 11, design: .rounded)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ForEach(item.commands, id: \.self) { c in
                        Text(c.display)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                    ForEach(item.paths.prefix(6), id: \.path) { p in
                        Text(Paths.display(p))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if item.paths.count > 6 {
                        Text("e \(item.paths.count - 6) caminhos mais")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    if item.target.requiresAdmin {
                        Label("pedirá senha de administrador", systemImage: "lock.fill")
                            .font(.system(size: 10)).foregroundStyle(.orange)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}
