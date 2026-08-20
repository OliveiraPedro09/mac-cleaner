import SwiftUI

/// Faixa de risco de um alvo de limpeza. A ordem importa: a UI agrupa e ordena por ela,
/// e a faixa `.userData` exige confirmação digitada antes de executar.
enum Risk: Int, CaseIterable, Codable, Sendable, Comparable {
    case safe = 1         // cache 100% regenerável, nenhuma decisão envolvida
    case regenerable = 2  // recuperável, mas custa re-download ou perda de estado de UI
    case userData = 3     // dados que só o usuário pode decidir descartar

    static func < (a: Risk, b: Risk) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .safe:        return "Risco nulo — cache regenerável"
        case .regenerable: return "Regenerável com custo"
        case .userData:    return "Dados de usuário"
        }
    }

    var blurb: String {
        switch self {
        case .safe:
            return "Reconstruído sob demanda. Nenhum código, credencial ou configuração é afetado."
        case .regenerable:
            return "Volta, mas cobra o preço: re-download pela rede ou perda de estado de interface."
        case .userData:
            return "Conteúdo seu. Só apague se souber que existe cópia em outro lugar."
        }
    }

    var tint: Color {
        switch self {
        case .safe:        return .green
        case .regenerable: return .orange
        case .userData:    return .red
        }
    }

    var symbol: String {
        switch self {
        case .safe:        return "checkmark.shield.fill"
        case .regenerable: return "arrow.clockwise.circle.fill"
        case .userData:    return "exclamationmark.triangle.fill"
        }
    }
}
