import Foundation

/// Como os caminhos concretos de um alvo são descobertos em tempo de varredura.
enum Source: Sendable {
    /// Caminhos literais, com `~` expandido. Os que não existirem são ignorados.
    case paths([String])
    /// Padrão glob, ex. `~/.android/avd/*/snapshots`.
    case glob(String)
    /// Lógica dedicada — versões obsoletas, órfãos de runtime, etc.
    case provider(ProviderID)

    static func path(_ p: String) -> Source { .paths([p]) }
}

/// Providers resolvem alvos que exigem decisão, não só um caminho fixo:
/// "as versões antigas", "os órfãos", "tudo menos o atual".
enum ProviderID: String, Sendable, CaseIterable {
    case nvmObsolete            // Node fora do default e dos maiores de cada major
    case simulatorsUnavailable  // devices cujo runtime foi desinstalado
    case simulatorsOldRuntime   // devices de runtimes iOS anteriores ao mais novo
    case deviceSupportOld       // iOS/watchOS/tvOS DeviceSupport fora da versão mais nova
    case jetbrainsOld           // versões antigas por produto JetBrains
    case discordOld             // app-X.Y.Z antigos do Discord
    case xcodeArchivesOld       // .xcarchive com mais de 60 dias
}

/// Um comando externo, para casos em que apagar o diretório na mão corromperia um índice.
/// Simuladores são o exemplo: o CoreSimulator mantém catálogo próprio, então
/// `simctl delete` é obrigatório em vez de `rm -rf`.
struct Command: Sendable, Hashable {
    let tool: String
    let args: [String]
    var display: String { ([tool] + args).joined(separator: " ") }
}

/// Resultado da descoberta de um alvo.
struct Discovery: Sendable {
    var paths: [URL] = []
    /// Se não estiver vazio, executa estes comandos em vez de apagar `paths` diretamente.
    /// `paths` continua servindo para calcular o tamanho e para mostrar o que será afetado.
    var commands: [Command] = []
    var note: String? = nil

    var isEmpty: Bool { paths.isEmpty && commands.isEmpty }
}

struct Target: Identifiable, Sendable {
    let id: String
    let name: String
    let group: String
    let risk: Risk
    /// Função técnica do diretório — o "o que é isto".
    let what: String
    /// Impacto prático de remover — o "o que muda na minha vida".
    let consequence: String
    let source: Source

    /// Bundle IDs que precisam estar fechados. A UI oferece encerrar cada um.
    var blockingApps: [String] = []
    /// Exige senha de administrador (caminhos fora da home, root-owned).
    var requiresAdmin: Bool = false
    /// Libera a guarda que recusa caminhos dentro de repositórios git.
    var allowInsideRepo: Bool = false
}
