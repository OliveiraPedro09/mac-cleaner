import SwiftUI
import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle, scanning, cleaning, done
    }

    var phase: Phase = .idle
    var disk = DiskInfo.current()
    var items: [ScanItem] = []
    var selection: Set<String> = []
    var scanned = 0
    var scanTotal = 0
    var currentlyScanning = ""

    var outcomes: [CleanOutcome] = []
    var diskBefore = DiskInfo()
    var cleaningNow = ""
    var cleanedCount = 0

    var bigDirs: [BigDir] = []
    var bigDirsScanning = false
    var bigDirsProgress = ""

    var liveBlockers: Set<String> = []
    var showConfirm = false

    // MARK: - Derivados

    var visibleItems: [ScanItem] { items.filter(\.hasWork) }

    func items(risk: Risk) -> [ScanItem] {
        visibleItems.filter { $0.target.risk == risk }.sorted { $0.bytes > $1.bytes }
    }

    func total(risk: Risk) -> Int64 {
        items(risk: risk).reduce(0) { $0 + $1.bytes }
    }

    var selectedItems: [ScanItem] { visibleItems.filter { selection.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var totalFound: Int64 { visibleItems.reduce(0) { $0 + $1.bytes } }

    /// Espaço livre projetado se a seleção atual for executada.
    var projectedFree: Int64 { disk.free + selectedBytes }

    var involvesUserData: Bool { selectedItems.contains { $0.target.risk == .userData } }

    /// Apps que precisam ser fechados para a seleção atual, que estão rodando agora.
    var pendingBlockers: [BlockingApp] {
        let needed = Set(selectedItems.flatMap(\.target.blockingApps))
        return needed.intersection(liveBlockers).sorted().map {
            BlockingApp(bundleID: $0, name: RunningApps.label(for: $0))
        }
    }

    func blockers(for item: ScanItem) -> [BlockingApp] {
        item.target.blockingApps.filter(liveBlockers.contains)
            .map { BlockingApp(bundleID: $0, name: RunningApps.label(for: $0)) }
    }

    var totalFreed: Int64 { outcomes.reduce(0) { $0 + $1.freed } }

    // MARK: - Ações

    func refreshBlockers() {
        let all = Array(Set(Catalog.all.flatMap(\.blockingApps)))
        liveBlockers = Set(RunningApps.running(among: all).map(\.bundleID))
    }

    func refreshDisk() { disk = DiskInfo.current() }

    private var scanTask: Task<Void, Never>?

    func scan() {
        scanTask?.cancel()
        phase = .scanning
        items = []
        selection = []
        outcomes = []
        scanned = 0
        scanTotal = Catalog.all.count
        refreshDisk()
        refreshBlockers()

        scanTask = Task {
            for await item in Scanner.scan(Catalog.all) {
                items.append(item)
                scanned += 1
                currentlyScanning = item.target.name
                // Pré-seleciona apenas a faixa de risco nulo, e nada que esteja bloqueado.
                if item.hasWork, item.bytes > 0, item.target.risk == .safe {
                    selection.insert(item.id)
                }
            }
            currentlyScanning = ""
            phase = .idle
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        phase = .idle
        currentlyScanning = ""
    }

    func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    func setAll(risk: Risk, on: Bool) {
        let ids = items(risk: risk).filter { $0.bytes > 0 }.map(\.id)
        if on { selection.formUnion(ids) } else { selection.subtract(ids) }
    }

    func allSelected(risk: Risk) -> Bool {
        let ids = items(risk: risk).filter { $0.bytes > 0 }.map(\.id)
        return !ids.isEmpty && ids.allSatisfy(selection.contains)
    }

    func quit(_ app: BlockingApp) {
        RunningApps.quit(app.bundleID)
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            refreshBlockers()
        }
    }

    func clean() {
        let batch = selectedItems.sorted { $0.target.risk < $1.target.risk }
        guard !batch.isEmpty else { return }
        diskBefore = DiskInfo.current()
        phase = .cleaning
        outcomes = []
        cleanedCount = 0

        Task {
            for item in batch {
                cleaningNow = item.target.name
                let outcome = await Cleaner.clean(item)
                outcomes.append(outcome)
                cleanedCount += 1
                refreshDisk()
            }
            cleaningNow = ""
            refreshDisk()
            phase = .done
        }
    }

    func scanBigDirs() {
        bigDirsScanning = true
        bigDirs = []
        Task {
            let found = await BigDirs.scan { [weak self] label in
                Task { @MainActor in self?.bigDirsProgress = label }
            }
            bigDirs = found
            bigDirsProgress = ""
            bigDirsScanning = false
        }
    }

    func reset() {
        phase = .idle
        outcomes = []
        scan()
    }

    func exportReport() {
        let md = ReportWriter.markdown(items: items, outcomes: outcomes,
                                       before: diskBefore, after: disk)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "faxina-relatorio.md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? md.write(to: url, atomically: true, encoding: .utf8)
    }
}
