import SwiftUI

struct TargetRow: View {
    let model: AppModel
    let item: ScanItem
    @State private var expanded = false

    private var blockers: [BlockingApp] { model.blockers(for: item) }
    private var isSelected: Bool { model.selection.contains(item.id) }
    private var selectable: Bool { item.bytes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in model.toggle(item.id) }
                ))
                .labelsHidden()
                .disabled(!selectable)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.target.name).font(.system(size: 12.5, weight: .medium))
                        Text(item.target.group)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                        if !blockers.isEmpty {
                            Label("feche \(blockers.map(\.name).joined(separator: ", "))",
                                  systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        if !item.blocked.isEmpty {
                            Label("\(item.blocked.count) recusado", systemImage: "shield.lefthalf.filled")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(item.target.consequence)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(expanded ? nil : 1)
                }

                Spacer(minLength: 8)

                Text(item.bytes.humanSize)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.bytes > 0 ? .primary : .tertiary)

                Button {
                    withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .onTapGesture { if selectable { model.toggle(item.id) } }

            if expanded { detail }
        }
        .background(isSelected ? Color.accentColor.opacity(0.06) : .clear)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Row(label: "O que é", text: item.target.what)
            Row(label: "Ao remover", text: item.target.consequence)
            if let note = item.note, !note.isEmpty {
                Row(label: "Descoberta", text: note)
            }
            if item.files > 0 {
                Row(label: "Conteúdo", text: "\(item.files) arquivos · \(item.bytes.humanSize)")
            }

            if !item.commands.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("COMANDOS").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    ForEach(item.commands, id: \.self) { c in
                        Text(c.display)
                            .font(.system(size: 10.5, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }

            if !item.paths.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.commands.isEmpty ? "SERÁ REMOVIDO" : "DIRETÓRIOS AFETADOS")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    ForEach(item.paths.prefix(12), id: \.path) { p in
                        HStack(spacing: 5) {
                            Text(Paths.display(p))
                                .font(.system(size: 10.5, design: .monospaced))
                                .textSelection(.enabled)
                            Button {
                                NSWorkspace.shared.selectFile(p.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Image(systemName: "arrow.up.forward.app").font(.system(size: 9))
                            }
                            .buttonStyle(.plain).foregroundStyle(.tertiary)
                        }
                    }
                    if item.paths.count > 12 {
                        Text("e \(item.paths.count - 12) mais")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
            }

            if !item.blocked.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RECUSADO PELA GUARDA")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
                    ForEach(item.blocked, id: \.self) { b in
                        Text("\(b.path) — \(b.rule)")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !blockers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(blockers) { app in
                        Button("Encerrar \(app.name)") { model.quit(app) }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.leading, 26)
        .padding(.bottom, 12)
        .padding(.top, 2)
    }

    private struct Row: View {
        let label: String
        let text: String
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 78, alignment: .leading)
                Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
