import Foundation

struct DiskInfo: Sendable, Equatable {
    var total: Int64 = 0
    var free: Int64 = 0
    var used: Int64 { max(0, total - free) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    var percent: Int { Int((usedFraction * 100).rounded()) }

    /// Mede o volume de dados. Em APFS, `/` é somente-leitura e reporta apenas o
    /// snapshot do sistema; o espaço que o usuário sente está em /System/Volumes/Data.
    static func current() -> DiskInfo {
        for path in ["/System/Volumes/Data", "/"] {
            var s = statfs()
            guard statfs(path, &s) == 0 else { continue }
            let block = Int64(s.f_bsize)
            let info = DiskInfo(total: Int64(s.f_blocks) * block,
                                free: Int64(s.f_bavail) * block)
            if info.total > 0 { return info }
        }
        return DiskInfo()
    }
}
