import SwiftUI

struct CatalogView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(Risk.allCases, id: \.self) { risk in
                    let rows = model.items(risk: risk)
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows) { item in
                                TargetRow(model: model, item: item)
                                Divider().padding(.leading, 20)
                            }
                        } header: {
                            header(risk, count: rows.count)
                        }
                    }
                }

                if model.phase == .scanning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(model.currentlyScanning.isEmpty
                             ? "Medindo…" : "Medindo \(model.currentlyScanning)…")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                } else if model.visibleItems.isEmpty {
                    ContentUnavailableView("Nada a limpar",
                                           systemImage: "sparkles",
                                           description: Text("Nenhum dos \(Catalog.all.count) alvos do catálogo tem conteúdo nesta máquina."))
                        .padding(.vertical, 40)
                }
            }
        }
    }

    private func header(_ risk: Risk, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: risk.symbol)
                .font(.system(size: 12))
                .foregroundStyle(risk.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(risk.title).font(.system(size: 12, weight: .semibold))
                Text(risk.blurb).font(.system(size: 10.5)).foregroundStyle(.secondary)
            }

            Spacer()

            Text(model.total(risk: risk).humanSize)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button(model.allSelected(risk: risk) ? "Nenhum" : "Todos") {
                model.setAll(risk: risk, on: !model.allSelected(risk: risk))
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}
