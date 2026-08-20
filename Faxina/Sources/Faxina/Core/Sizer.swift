import Foundation

/// Mede o espaço realmente ocupado em disco (blocos alocados), não o tamanho lógico.
/// É a mesma conta que `du` faz, e é a que importa: um arquivo esparso de 10 GB pode
/// ocupar 2 GB reais.
enum Sizer {
    struct Measurement: Sendable {
        var bytes: Int64 = 0
        var files: Int = 0
        /// Caminhos que existem mas não pudemos ler — quase sempre falta de Acesso Total ao Disco.
        var unreadable: Int = 0
    }

    static func measure(_ url: URL) async -> Measurement {
        var m = Measurement()
        let fm = FileManager.default

        guard let vals = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            m.unreadable = 1
            return m
        }
        if vals.isSymbolicLink == true { return m }

        if vals.isDirectory != true {
            m.bytes = allocated(url)
            m.files = 1
            return m
        }

        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                      .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey]
        guard let en = fm.enumerator(at: url, includingPropertiesForKeys: keys,
                                     options: [], errorHandler: { _, _ in true }) else {
            m.unreadable = 1
            return m
        }

        var seen = 0
        while let object = en.nextObject() {
            guard let child = object as? URL else { continue }
            m.bytes += allocated(child)
            m.files += 1
            seen += 1
            // Cede o processador periodicamente para manter a UI viva e permitir cancelamento.
            if seen & 0x1FFF == 0 {
                if Task.isCancelled { return m }
                await Task.yield()
            }
        }
        return m
    }

    /// Soma de vários caminhos, em paralelo limitado.
    static func measure(_ urls: [URL]) async -> Measurement {
        var total = Measurement()
        for url in urls {
            if Task.isCancelled { return total }
            let m = await measure(url)
            total.bytes += m.bytes
            total.files += m.files
            total.unreadable += m.unreadable
        }
        return total
    }

    private static func allocated(_ url: URL) -> Int64 {
        guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                                                        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        else { return 0 }
        if v.isSymbolicLink == true { return 0 }
        guard v.isRegularFile == true else { return 0 }
        return Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }
}

extension Int64 {
    /// Formatação em base 10, igual à do Finder ("1 GB" = 1.000.000.000 bytes).
    var humanSize: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f.string(fromByteCount: self)
    }
}
