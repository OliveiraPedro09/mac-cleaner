import Foundation

/// Recusa caminhos que nunca devem ser apagados, independentemente do que o catálogo diga.
///
/// Esta é a última linha de defesa: roda imediatamente antes de cada remoção, sobre o
/// caminho já resolvido. Um alvo mal escrito, um glob amplo demais ou uma seleção manual
/// na aba de Descobertas param aqui.
enum SafetyGuard {
    struct Rejection: Error, Sendable {
        let path: String
        let rule: String
    }

    /// Diretórios e arquivos intocáveis — e, por extensão, qualquer ancestral deles.
    private static let protected: [String] = [
        "~/.ssh", "~/.gnupg", "~/.aws", "~/.kube", "~/.azure", "~/.docker/config.json",
        "~/.config", "~/.claude", "~/.cursor/argv.json", "~/.netrc", "~/.npmrc", "~/.gitconfig",
        "~/.zshrc", "~/.zshenv", "~/.zprofile", "~/.bashrc", "~/.profile",
        "~/Library/Keychains", "~/Library/Mobile Documents", "~/Library/CloudStorage",
        "~/Library/Application Support/AddressBook", "~/Library/Application Support/MobileSync",
        "~/Library/Messages", "~/Library/Mail", "~/Library/Preferences",
        "~/Documents", "~/Desktop", "~/Downloads", "~/Movies", "~/Music", "~/Pictures",
        "~/Applications", "~/Public",
    ]

    /// Raízes fora da home onde a remoção é admitida, e só nelas.
    private static let allowedForeignRoots: [String] = [
        "/Applications",
        "/Library/Application Support/com.apple.idleassetsd",
        "/Library/Developer/CoreSimulator",
        "/Library/Caches",
    ]

    private static let protectedURLs: [URL] = protected.map(Paths.expand)

    static func validate(_ url: URL, allowInsideRepo: Bool = false) throws {
        let u = url.standardizedFileURL
        let path = u.path
        let home = Paths.home.path

        // 1. Caminho absoluto e não vazio.
        guard path.hasPrefix("/"), path != "/" else {
            throw Rejection(path: path, rule: "caminho raiz ou relativo")
        }

        // 2. Nada de apagar a própria home, /Users ou raízes de sistema.
        let hardDeny = ["/", "/Users", home, "/System", "/Library", "/Applications",
                        "/bin", "/usr", "/etc", "/var", "/private", "/opt"]
        guard !hardDeny.contains(path) else {
            throw Rejection(path: path, rule: "diretório de sistema ou home do usuário")
        }

        // 3. Precisa estar dentro da home ou de uma raiz externa explicitamente liberada.
        let insideHome = path.hasPrefix(home + "/")
        let insideAllowedForeign = allowedForeignRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
        guard insideHome || insideAllowedForeign else {
            throw Rejection(path: path, rule: "fora da home e fora das raízes permitidas")
        }

        // 4. Não pode ser, conter ou estar dentro de um caminho protegido.
        for p in protectedURLs {
            let pp = p.path
            if path == pp {
                throw Rejection(path: path, rule: "protegido: \(Paths.display(p))")
            }
            if path.hasPrefix(pp + "/") {
                throw Rejection(path: path, rule: "dentro de protegido: \(Paths.display(p))")
            }
            if pp.hasPrefix(path + "/") {
                throw Rejection(path: path, rule: "contém protegido: \(Paths.display(p))")
            }
        }

        // 5. Nada dentro de um repositório git — é onde vive código de verdade.
        if !allowInsideRepo, let repo = enclosingRepo(of: u) {
            throw Rejection(path: path, rule: "dentro do repositório git \(Paths.display(repo))")
        }

        // 6. Não atravessar ponto de montagem: o alvo deve estar no mesmo volume do pai.
        if isMountPoint(u) {
            throw Rejection(path: path, rule: "ponto de montagem de outro volume")
        }

        // 7. O último componente não pode ser um symlink — apagar seguiria para fora.
        let vals = try? u.resourceValues(forKeys: [.isSymbolicLinkKey])
        if vals?.isSymbolicLink == true {
            throw Rejection(path: path, rule: "link simbólico")
        }
    }

    /// Sobe a árvore procurando um `.git`, parando na home. Retorna a raiz do repo, se houver.
    private static func enclosingRepo(of url: URL) -> URL? {
        let home = Paths.home.path
        var cur = url.deletingLastPathComponent()
        while cur.path.hasPrefix(home) && cur.path != home && cur.path != "/" {
            if FileManager.default.fileExists(atPath: cur.appendingPathComponent(".git").path) {
                return cur
            }
            cur = cur.deletingLastPathComponent()
        }
        return nil
    }

    private static func isMountPoint(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent()
        let a = try? url.resourceValues(forKeys: [.volumeIdentifierKey])
        let b = try? parent.resourceValues(forKeys: [.volumeIdentifierKey])
        guard let va = a?.volumeIdentifier, let vb = b?.volumeIdentifier else { return false }
        return !va.isEqual(vb)
    }
}
