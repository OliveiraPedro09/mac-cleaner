import SwiftUI

struct DiskHeader: View {
    let model: AppModel

    private var projectedFraction: Double {
        guard model.disk.total > 0 else { return 0 }
        return Double(model.disk.used - model.selectedBytes) / Double(model.disk.total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(model.disk.used.humanSize) de \(model.disk.total.humanSize) em uso")
                    .font(.system(size: 13, weight: .medium))
                Text("\(model.disk.percent)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.disk.usedFraction > 0.9 ? .red
                                     : model.disk.usedFraction > 0.75 ? .orange : .secondary)
                Spacer()
                if model.selectedBytes > 0 {
                    HStack(spacing: 6) {
                        Text("livre \(model.disk.free.humanSize)")
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                        Text(model.projectedFree.humanSize)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .font(.system(size: 12))
                    .contentTransition(.numericText())
                } else {
                    Text("livre \(model.disk.free.humanSize)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            // Barra: o trecho em destaque é o que a seleção atual devolveria.
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(model.disk.usedFraction > 0.9 ? Color.red.opacity(0.75) : Color.accentColor)
                        .frame(width: w * model.disk.usedFraction)
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: max(0, w * (model.disk.usedFraction - projectedFraction)))
                        .offset(x: w * projectedFraction)
                }
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.25), value: model.selectedBytes)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }
}
