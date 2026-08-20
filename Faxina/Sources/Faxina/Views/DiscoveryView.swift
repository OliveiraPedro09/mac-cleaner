import SwiftUI

/// Aba de descobertas: diretórios grandes fora do catálogo.
/// Somente leitura por princípio — o app não sabe o que essas pastas significam,
/// então não oferece um botão de apagar. Ele mostra, explica de onde vem, e deixa
/// a decisão com quem sabe.
struct DiscoveryView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                banner

                if model.bigDirsScanning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(model.bigDirsProgress.isEmpty ? "Medindo…" : "Medindo \(model.bigDirsProgress)…")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(20)
                }

                ForEach(model.bigDirs) { dir in
                    HStack(spacing: 10) {
                        Image(systemName: dir.coveredByCatalog ? "checkmark.circle" : "questionmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(dir.coveredByCatalog ? .green : .orange)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(dir.display)
                                .font(.system(size: 11.5, design: .monospaced))
                                .textSelection(.enabled)
                            Text(dir.coveredByCatalog
                                 ? "Já coberto por um alvo do catálogo"
                                 : "Fora do catálogo — avalie manualmente")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text(dir.bytes.humanSize)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()

                        Button {
                            NSWorkspace.shared.selectFile(dir.url.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "arrow.up.forward.app").font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Revelar no Finder")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    Divider().padding(.leading, 20)
                }

                if model.bigDirs.isEmpty && !model.bigDirsScanning {
                    ContentUnavailableView {
                        Label("Descobrir o que mais ocupa espaço", systemImage: "binoculars")
                    } description: {
                        Text("Mede os diretórios de primeiro nível da sua home e de /Applications e lista tudo acima de 500 MB, marcando o que o catálogo já cobre.\n\nÉ o passo que catálogo fixo não resolve: numa máquina real os maiores consumidores costumam ser específicos dela — mídia de um mensageiro, assets de um jogo, um modelo baixado à mão.")
                    } actions: {
                        Button("Varrer") { model.scanBigDirs() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 30)
                }
            }
        }
    }

    private var banner: some View {
        Group {
            if !model.bigDirs.isEmpty {
                HStack {
                    Text("\(model.bigDirs.count) diretórios acima de 500 MB")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Button("Varrer de novo") { model.scanBigDirs() }
                        .buttonStyle(.link).font(.system(size: 11))
                }
                .padding(.horizontal, 20).padding(.vertical, 9)
                .background(.bar)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
    }
}
