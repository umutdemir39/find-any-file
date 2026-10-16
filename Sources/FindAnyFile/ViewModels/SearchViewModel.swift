import Foundation
import SwiftUI
import AppKit
import Quartz

@MainActor
public final class SearchViewModel: ObservableObject {
    // MARK: - Language (Default: English)
    @Published public var language: AppLanguage = .en {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "FAF_AppLanguage")
            scheduleFilterAndSort()
        }
    }

    // MARK: - Search Criteria State
    @Published public var target: SearchTargetType = .home
    @Published public var customPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @Published public var quickQuery: String = ""
    @Published public var rules: [SearchRule] = []
    @Published public var showAdvancedRules: Bool = false

    // MARK: - Search Options
    @Published public var caseSensitive: Bool = false
    @Published public var includeSpotlight: Bool = true
    @Published public var useRootMode: Bool = false

    // MARK: - Results & Filtering State
    @Published public private(set) var allFoundItems: [FoundFileItem] = []
    @Published public private(set) var displayedItems: [FoundFileItem] = []
    @Published public private(set) var treeNodes: [FileTreeNode] = []

    @Published public var resultsFilterText: String = "" {
        didSet { scheduleFilterAndSort() }
    }
    @Published public var invisiblesMode: VisibilityFilterMode = .showAll {
        didSet { scheduleFilterAndSort() }
    }
    @Published public var packageContentsMode: VisibilityFilterMode = .showAll {
        didSet { scheduleFilterAndSort() }
    }
    @Published public var trashedMode: VisibilityFilterMode = .hide {
        didSet { scheduleFilterAndSort() }
    }
    @Published public var quickKindFilter: FileKindCategory = .any {
        didSet { scheduleFilterAndSort() }
    }

    // MARK: - View & Sort State
    @Published public var viewMode: ResultsViewMode = .list {
        didSet {
            if viewMode == .tree {
                rebuildTree()
            }
        }
    }
    @Published public var sortColumn: SortColumn = .modifiedDate {
        didSet { scheduleFilterAndSort() }
    }
    @Published public var sortAscending: Bool = false {
        didSet { scheduleFilterAndSort() }
    }

    // MARK: - Selection & Panels
    @Published public var selectedItemIDs: Set<String> = []
    @Published public var showSidebar: Bool = true
    @Published public var showInspector: Bool = false
    @Published public var showShortcutsPopover: Bool = false

    public var primarySelectedItem: FoundFileItem? {
        guard let firstID = selectedItemIDs.first else { return nil }
        return allFoundItems.first(where: { $0.id == firstID })
    }

    // MARK: - Execution State
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var totalScannedCount: Int = 0
    @Published public private(set) var currentScanningDirectory: String = ""
    @Published public private(set) var lastElapsedSeconds: Double = 0
    @Published public var statusMessage: String = "Aramaya hazır"

    // MARK: - Presets & History
    @Published public var savedPresets: [SearchPreset] = []
    @Published public var recentQueries: [String] = []
    @Published public var showingSavePresetPopover: Bool = false
    @Published public var newPresetTitle: String = ""

    private let engine = FastSearchEngine()
    private var activeSearchTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?

    public init() {
        if let savedLang = UserDefaults.standard.string(forKey: "FAF_AppLanguage"),
           let parsed = AppLanguage(rawValue: savedLang) {
            self.language = parsed
        } else {
            self.language = .en
        }
        statusMessage = self.language.t("Ready to search", "Aramaya hazır")
        loadSavedPresets()
        loadRecentQueries()
    }

    // MARK: - Start / Stop Search
    public func startSearch() {
        stopSearch()

        let trimmedQuick = quickQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuick.isEmpty {
            addRecentQuery(trimmedQuick)
        }

        allFoundItems.removeAll(keepingCapacity: true)
        displayedItems.removeAll(keepingCapacity: true)
        treeNodes.removeAll()
        selectedItemIDs.removeAll()
        totalScannedCount = 0
        lastElapsedSeconds = 0
        isSearching = true
        statusMessage = useRootMode 
            ? language.t("Scanning with root privileges...", "Root yetkisiyle taranıyor...")
            : language.t("Scanning...", "Taranıyor...")

        let roots = target.resolvedPaths(customPath: customPath)
        let config = SearchConfiguration(
            rootPaths: roots,
            quickQuery: trimmedQuick,
            rules: rules,
            caseSensitive: caseSensitive,
            includeSpotlight: includeSpotlight
        )

        let runAsRoot = useRootMode
        let localEngine = engine

        activeSearchTask = Task { [weak self] in
            let result: (totalScanned: Int, elapsedSeconds: Double)
            if runAsRoot {
                do {
                    result = try await localEngine.searchAsRoot(config: config) { [weak self] batch in
                        Task { @MainActor [weak self] in
                            self?.handleIncomingBatch(batch)
                        }
                    }
                } catch {
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.isSearching = false
                        self.statusMessage = self.language.t("Root search cancelled or failed.", "Root araması iptal edildi veya başarısız oldu.")
                    }
                    return
                }
            } else {
                result = await localEngine.search(config: config) { [weak self] batch in
                    Task { @MainActor [weak self] in
                        self?.handleIncomingBatch(batch)
                    }
                }
            }

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isSearching = false
                self.totalScannedCount = max(self.totalScannedCount, result.totalScanned)
                self.lastElapsedSeconds = result.elapsedSeconds
                self.applyFilterAndSortNow()
                let formattedTime = String(format: "%.2f s", result.elapsedSeconds)
                self.statusMessage = self.language.t(
                    "\(self.displayedItems.count) items found (\(self.totalScannedCount.formatted()) scanned in \(formattedTime))",
                    "\(self.displayedItems.count) sonuç bulundu (\(self.totalScannedCount.formatted()) öğe \(formattedTime) içinde tarandı)"
                )
            }
        }
    }

    public func stopSearch() {
        activeSearchTask?.cancel()
        activeSearchTask = nil
        if isSearching {
            isSearching = false
            applyFilterAndSortNow()
            statusMessage = language.t(
                "Stopped • \(displayedItems.count) results (\(totalScannedCount.formatted()) scanned)",
                "Durduruldu • \(displayedItems.count) sonuç (\(totalScannedCount.formatted()) öğe tarandı)"
            )
        }
    }

    private func handleIncomingBatch(_ batch: SearchProgressBatch) {
        guard isSearching else { return }
        totalScannedCount = max(totalScannedCount, batch.scannedCount)
        currentScanningDirectory = batch.currentDirectory
        if !batch.newItems.isEmpty {
            allFoundItems.append(contentsOf: batch.newItems)
            scheduleFilterAndSort()
        }
    }

    // MARK: - Filtering, Sorting & Hierarchical Tree
    private func scheduleFilterAndSort() {
        filterTask?.cancel()
        filterTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 35_000_000) // 35ms debounce for smooth 60fps UI
            guard !Task.isCancelled, let self else { return }
            self.applyFilterAndSortNow()
        }
    }

    public func applyFilterAndSortNow() {
        let filterNeedle = resultsFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let invMode = invisiblesMode
        let pkgMode = packageContentsMode
        let trMode = trashedMode
        let kindCat = quickKindFilter

        var filtered = allFoundItems.filter { item in
            switch invMode {
            case .showAll: break
            case .hide: if item.isHidden { return false }
            case .exclusive: if !item.isHidden { return false }
            }

            switch pkgMode {
            case .showAll: break
            case .hide: if item.isInsidePackage { return false }
            case .exclusive: if !item.isInsidePackage { return false }
            }

            switch trMode {
            case .showAll: break
            case .hide: if item.isTrashed { return false }
            case .exclusive: if !item.isTrashed { return false }
            }

            if kindCat != .any {
                if !kindCat.matches(ext: item.fileExtension, isDirectory: item.isDirectory, isPackage: item.isPackage, isSymlink: item.isSymlink) {
                    return false
                }
            }

            if !filterNeedle.isEmpty {
                if !item.name.lowercased().contains(filterNeedle) && !item.path.lowercased().contains(filterNeedle) {
                    return false
                }
            }

            return true
        }

        let col = sortColumn
        let asc = sortAscending

        filtered.sort { a, b in
            let ordered: Bool
            switch col {
            case .name:
                ordered = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .path:
                ordered = a.path.localizedStandardCompare(b.path) == .orderedAscending
            case .size:
                if a.size == b.size {
                    ordered = a.name.localizedStandardCompare(b.name) == .orderedAscending
                } else {
                    ordered = a.size < b.size
                }
            case .kind:
                if a.kindDescription == b.kindDescription {
                    ordered = a.name.localizedStandardCompare(b.name) == .orderedAscending
                } else {
                    ordered = a.kindDescription.localizedStandardCompare(b.kindDescription) == .orderedAscending
                }
            case .modifiedDate:
                ordered = a.modifiedDate < b.modifiedDate
            case .createdDate:
                ordered = a.createdDate < b.createdDate
            }
            return asc ? ordered : !ordered
        }

        displayedItems = filtered

        if viewMode == .tree {
            rebuildTree()
        }
    }

    public func toggleSort(column: SortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = (column == .name || column == .path || column == .kind)
        }
    }

    // MARK: - Build Hierarchical Folder Tree (FAF Signature View)
    public func rebuildTree() {
        let items = displayedItems
        guard !items.isEmpty else {
            treeNodes = []
            return
        }

        // Limit tree building to first 3,500 items for instant UI responsiveness
        let cappedItems = items.prefix(3500)
        var directMatchMap: [String: FoundFileItem] = [:]
        var childrenMap: [String: Set<String>] = [:]

        for item in cappedItems {
            directMatchMap[item.path] = item
            var currentPath = item.path
            while currentPath != "/" && !currentPath.isEmpty {
                let parent = (currentPath as NSString).deletingLastPathComponent
                if parent.isEmpty || parent == currentPath { break }
                childrenMap[parent, default: []].insert(currentPath)
                currentPath = parent
            }
        }

        func buildNode(path: String) -> FileTreeNode {
            let name = path == "/" ? "/" : (path as NSString).lastPathComponent
            let directItem = directMatchMap[path]
            let childPaths = childrenMap[path]?.sorted {
                (($0 as NSString).lastPathComponent).localizedStandardCompare(($1 as NSString).lastPathComponent) == .orderedAscending
            } ?? []

            let childNodes: [FileTreeNode] = childPaths.map { buildNode(path: $0) }

            // Compact single-folder non-matching chains (e.g. /Users -> umutdemir -> Desktop) for cleaner navigation
            if directItem == nil && childNodes.count == 1 && childNodes[0].matchedItem == nil && (childNodes[0].children?.isEmpty == false) {
                let singleChild = childNodes[0]
                return FileTreeNode(
                    id: singleChild.id,
                    name: "\(name)/\(singleChild.name)",
                    path: singleChild.path,
                    isDirectMatch: false,
                    matchedItem: nil,
                    matchCountInSubtree: singleChild.matchCountInSubtree,
                    children: singleChild.children
                )
            }

            let subtreeMatches = (directItem != nil ? 1 : 0) + childNodes.reduce(0) { $0 + $1.matchCountInSubtree }
            return FileTreeNode(
                id: path,
                name: name,
                path: path,
                isDirectMatch: directItem != nil,
                matchedItem: directItem,
                matchCountInSubtree: subtreeMatches,
                children: childNodes.isEmpty ? nil : childNodes
            )
        }

        let rootChildPaths = childrenMap["/"]?.sorted() ?? []
        treeNodes = rootChildPaths.map { buildNode(path: $0) }
    }

    // MARK: - Rule Management
    public func addRule(field: RuleField = .name) {
        let defaultOp = field.availableOperators.first ?? .contains
        rules.append(SearchRule(field: field, op: defaultOp))
        showAdvancedRules = true
    }

    public func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    public func clearRules() {
        rules.removeAll()
        quickQuery = ""
        quickKindFilter = .any
        resultsFilterText = ""
    }

    public func applyPreset(_ preset: SearchPreset) {
        target = preset.target
        if !preset.customPath.isEmpty {
            customPath = preset.customPath
        }
        quickQuery = preset.quickQuery
        rules = preset.rules
        invisiblesMode = preset.invisiblesMode
        packageContentsMode = preset.packageContentsMode
        caseSensitive = preset.caseSensitive
        showAdvancedRules = !preset.rules.isEmpty
        startSearch()
    }

    public func saveCurrentSearchAsPreset(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let targetLabelEN = target.title(in: .en)
        let targetLabelTR = target.title(in: .tr)
        let ruleCountDescEN = "\(rules.count) rule\(rules.count == 1 ? "" : "s")"
        let ruleCountDescTR = "\(rules.count) kural"

        let preset = SearchPreset(
            titleEN: trimmed,
            titleTR: trimmed,
            subtitleEN: "\(targetLabelEN) • \(ruleCountDescEN)",
            subtitleTR: "\(targetLabelTR) • \(ruleCountDescTR)",
            iconName: "star.fill",
            accentHex: "#3B82F6",
            target: target,
            customPath: customPath,
            quickQuery: quickQuery,
            rules: rules,
            invisiblesMode: invisiblesMode,
            packageContentsMode: packageContentsMode,
            caseSensitive: caseSensitive
        )
        savedPresets.append(preset)
        persistSavedPresets()
    }

    public func deleteSavedPreset(id: UUID) {
        savedPresets.removeAll { $0.id == id }
        persistSavedPresets()
    }

    // MARK: - Folder Picker
    public func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.prompt = language.t("Search Here", "Bu Klasörde Ara")
        panel.message = language.t("Select folder or volume to search in", "Arama yapılacak klasörü veya diski seçin")
        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
            target = .custom
        }
    }

    // MARK: - File Actions (Finder, Open, Trash, QuickLook, Remove from Results)
    public func handleSingleClick(on item: FoundFileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
        } else {
            selectedItemIDs = [item.id]
        }
        QuickLookCoordinator.shared.updateQuickLookIfVisible(for: [item.url])
    }

    public func handleDoubleClick(on item: FoundFileItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            revealInFinder(item)
            statusMessage = language.t("Revealed in Finder: \(item.name)", "Finder'da klasörü açıldı ve seçildi: \(item.name)")
        } else if flags.contains(.option) {
            copyPath(item)
        } else {
            openItem(item)
        }
    }

    public func handlePathDoubleClick(path: String, matchedItem: FoundFileItem?) {
        if let matchedItem {
            handleDoubleClick(on: matchedItem)
            return
        }
        let url = URL(fileURLWithPath: path)
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            statusMessage = language.t("Revealed in Finder: \((path as NSString).lastPathComponent)", "Finder'da gösterildi: \((path as NSString).lastPathComponent)")
        } else if flags.contains(.option) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
            statusMessage = language.t("Path copied: \(path)", "Klasör yolu kopyalandı: \(path)")
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    public func openItem(_ item: FoundFileItem) {
        NSWorkspace.shared.open(item.url)
    }

    public func openSelectedItems() {
        for id in selectedItemIDs {
            if let item = allFoundItems.first(where: { $0.id == id }) {
                NSWorkspace.shared.open(item.url)
            }
        }
    }

    public func revealInFinder(_ item: FoundFileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    public func revealSelectedInFinder() {
        let urls = selectedItemIDs.compactMap { id in
            allFoundItems.first(where: { $0.id == id })?.url
        }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    public func copyPath(_ item: FoundFileItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
        statusMessage = language.t("Path copied: \(item.path)", "Yol kopyalandı: \(item.path)")
    }

    public func copySelectedPaths() {
        let paths = selectedItemIDs.sorted().joined(separator: "\n")
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
        statusMessage = language.t("\(selectedItemIDs.count) file paths copied to clipboard", "\(selectedItemIDs.count) dosyanın yolu panoya kopyalandı")
    }

    public func removeSelectedFromResults() {
        guard !selectedItemIDs.isEmpty else { return }
        let removedCount = selectedItemIDs.count
        allFoundItems.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
        applyFilterAndSortNow()
        statusMessage = language.t("\(removedCount) items removed from results (not deleted from disk)", "\(removedCount) öğe sonuç listesinden kaldırıldı (diskten silinmedi)")
    }

    public func moveItemToTrash(_ item: FoundFileItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            allFoundItems.removeAll { $0.id == item.id }
            selectedItemIDs.remove(item.id)
            applyFilterAndSortNow()
            statusMessage = language.t("Moved to Trash: \(item.name)", "Çöp Sepetine taşındı: \(item.name)")
        } catch {
            statusMessage = language.t("Could not move to Trash: \(error.localizedDescription)", "Çöp Sepetine taşınamadı: \(error.localizedDescription)")
        }
    }

    public func moveSelectedToTrash() {
        var trashedCount = 0
        for id in selectedItemIDs {
            if let item = allFoundItems.first(where: { $0.id == id }) {
                if (try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)) != nil {
                    trashedCount += 1
                    allFoundItems.removeAll { $0.id == id }
                }
            }
        }
        selectedItemIDs.removeAll()
        applyFilterAndSortNow()
        statusMessage = language.t("\(trashedCount) items moved to Trash", "\(trashedCount) öğe Çöp Sepetine taşındı")
    }

    public func exportResultsAsPathsFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = language.t("SearchResults.paths", "Arama_Sonuclari.paths")
        panel.prompt = language.t("Save", "Kaydet")
        if panel.runModal() == .OK, let url = panel.url {
            let content = displayedItems.map(\.path).joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = language.t("\(displayedItems.count) paths exported: \(url.lastPathComponent)", "\(displayedItems.count) dosya yolu dışa aktarıldı: \(url.lastPathComponent)")
        }
    }

    // MARK: - Persistence Helpers
    private func loadSavedPresets() {
        guard let data = UserDefaults.standard.data(forKey: "FAF_SavedPresets"),
              let decoded = try? JSONDecoder().decode([SearchPreset].self, from: data) else {
            return
        }
        savedPresets = decoded
    }

    private func persistSavedPresets() {
        if let data = try? JSONEncoder().encode(savedPresets) {
            UserDefaults.standard.set(data, forKey: "FAF_SavedPresets")
        }
    }

    private func loadRecentQueries() {
        recentQueries = UserDefaults.standard.stringArray(forKey: "FAF_RecentQueries") ?? []
    }

    private func addRecentQuery(_ q: String) {
        var list = recentQueries.filter { $0.lowercased() != q.lowercased() }
        list.insert(q, at: 0)
        if list.count > 12 {
            list = Array(list.prefix(12))
        }
        recentQueries = list
        UserDefaults.standard.set(list, forKey: "FAF_RecentQueries")
    }
}
