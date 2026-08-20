import SwiftUI

struct RootView: View {
    @State private var model = AppModel()
    @State private var tab = Tab.catalogo

    enum Tab: String, CaseIterable {
        case catalogo = "Catálogo"
        case descobertas = "Descobertas"
    }

    var body: some View {
        VStack(spacing: 0) {
            DiskHeader(model: model)

            if model.phase == .done {
                ResultsView(model: model)
            } else {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
                .padding(.vertical, 10)

                Divider()

                switch tab {
                case .catalogo:    CatalogView(model: model)
                case .descobertas: DiscoveryView(model: model)
                }
            }

            Divider()
            footer
        }
        .frame(minWidth: 840, minHeight: 640)
        .task {
            model.scan()
            // Reavalia apps abertos periodicamente para que os avisos de bloqueio
            // desapareçam sozinhos quando o usuário fecha o app.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                model.refreshBlockers()
                if model.phase == .idle { model.refreshDisk() }
            }
        }
        .sheet(isPresented: $model.showConfirm) { ConfirmSheet(model: model) }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 12) {
            switch model.phase {
            case .scanning:
                ProgressView(value: Double(model.scanned), total: Double(max(1, model.scanTotal)))
                    .frame(width: 130)
                Text("\(model.scanned)/\(model.scanTotal) alvos")
                    .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button("Parar") { model.cancelScan() }

            case .cleaning:
                ProgressView(value: Double(model.cleanedCount),
                             total: Double(max(1, model.selectedItems.count)))
                    .frame(width: 130)
                Text(model.cleaningNow.isEmpty ? "Limpando…" : "Limpando \(model.cleaningNow)…")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()

            case .done:
                Button("Exportar relatório…") { model.exportReport() }
                Spacer()
                Button("Nova varredura") { model.reset() }
                    .buttonStyle(.borderedProminent)

            case .idle:
                Text(summaryLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reexaminar") { model.scan() }
                Button(model.selectedBytes > 0
                       ? "Revisar e limpar \(model.selectedBytes.humanSize)"
                       : "Nada selecionado") {
                    model.showConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedItems.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var summaryLine: String {
        let found = model.totalFound
        guard found > 0 else { return "Nada recuperável encontrado" }
        let sel = model.selectedItems.count
        return "\(found.humanSize) recuperáveis em \(model.visibleItems.count) alvos · "
             + (sel > 0 ? "\(sel) selecionados" : "nenhum selecionado")
    }
}
