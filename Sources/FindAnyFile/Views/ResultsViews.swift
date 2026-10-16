import SwiftUI
import AppKit

public struct ResultsContainerView: View {
    @ObservedObject var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let lang = viewModel.language

        VStack(spacing: 0) {
            // MARK: - 1. Responsive Results Toolbar
            resultsToolbar(lang: lang)
            Divider()

            // MARK: - 2. Main Results Content
            if viewModel.displayedItems.isEmpty {
                emptyResultsState(lang: lang)
            } else {
                switch viewModel.viewMode {
                case .list:
                    flatListView(lang: lang)
                case .tree:
                    hierarchicalTreeView(lang: lang)
                case .grid:
                    previewGridView(lang: lang)
                }
            }

            Divider()
            // MARK: - 3. Bottom Status & Always-Visible Shortcut Bar
            bottomStatusAndShortcutBar(lang: lang)
        }
    }

    // MARK: - Results Toolbar
    private func resultsToolbar(lang: AppLanguage) -> some View {
        HStack(spacing: 6) {
            // View Mode Segmented Control (List / Tree / Grid)
            HStack(spacing: 2) {
                ForEach(ResultsViewMode.allCases) { mode in
                    let active = viewModel.viewMode == mode
                    Button {
                        viewModel.viewMode = mode
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(mode.title(in: lang))
                                .font(.system(size: 11, weight: active ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(active ? Color.accentColor : Color.clear)
                        )
                        .foregroundStyle(active ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .help("\(mode.fullTitle(in: lang)) (\(mode.shortcutLabel))")
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .fixedSize(horizontal: true, vertical: false)

            Divider()
                .frame(height: 16)

            // Scrollable 3-State Visibility Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ThreeStateFilterPill(
                        label: lang.t("Hidden", "Gizli"),
                        fullTitle: lang.t("Hidden Files (Invisibles)", "Gizli Dosyalar (Invisibles)"),
                        icon: "eye.slash.fill",
                        lang: lang,
                        selection: $viewModel.invisiblesMode
                    )

                    ThreeStateFilterPill(
                        label: lang.t("Package", "Paket İçi"),
                        fullTitle: lang.t("Package Contents (.app / .bundle)", "Paket İçerikleri (.app / .bundle)"),
                        icon: "shippingbox.fill",
                        lang: lang,
                        selection: $viewModel.packageContentsMode
                    )

                    ThreeStateFilterPill(
                        label: lang.t("Trash", "Çöp"),
                        fullTitle: lang.t("Trash Items (.Trash)", "Çöp Sepeti (.Trash)"),
                        icon: "trash.fill",
                        lang: lang,
                        selection: $viewModel.trashedMode
                    )
                }
            }

            Spacer(minLength: 4)

            // Live Filter Inside Results
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField(lang.t("Filter results...", "Sonuçlarda filtrele..."), text: $viewModel.resultsFilterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .frame(minWidth: 85, idealWidth: 135, maxWidth: 170)
                if !viewModel.resultsFilterText.isEmpty {
                    Button {
                        viewModel.resultsFilterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )

            // Shortcuts Guide Button
            Button {
                viewModel.showShortcutsPopover = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(lang.t("Shortcuts", "Kısayollar"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .help(lang.t("View All Mouse & Keyboard Shortcuts (⌘/)", "Tüm Fare ve Klavye Kısayollarını Gör (⌘/)"))

            // Export Button
            Button {
                viewModel.exportResultsAsPathsFile()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
                    .padding(5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.displayedItems.isEmpty)
            .help(lang.t("Export results as .paths file", "Sonuçların dosya yollarını (.paths) olarak dışa aktar"))

            // Inspector Toggle Button
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.showInspector.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.showInspector ? Color.accentColor : Color.secondary)
                    .padding(5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(viewModel.showInspector ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .help(lang.t("Toggle File Inspector (⌘⌥I)", "Dosya Denetçisini Göster / Gizle (⌘⌥I)"))
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 1. Flat List View
    private func flatListView(lang: AppLanguage) -> some View {
        GeometryReader { geo in
            let totalW = max(geo.size.width - 24, 420)
            let nameW = max(160, min(280, totalW * 0.34))
            let sizeW: CGFloat = 78
            let kindW: CGFloat = totalW > 620 ? 95 : 0
            let dateW: CGFloat = totalW > 520 ? 115 : 0

            VStack(spacing: 0) {
                // Sortable Column Headers
                HStack(spacing: 0) {
                    SortableColumnHeader(
                        title: SortColumn.name.title(in: lang),
                        column: .name,
                        currentColumn: viewModel.sortColumn,
                        ascending: viewModel.sortAscending
                    ) {
                        viewModel.toggleSort(column: .name)
                    }
                    .frame(width: nameW, alignment: .leading)

                    SortableColumnHeader(
                        title: SortColumn.path.title(in: lang),
                        column: .path,
                        currentColumn: viewModel.sortColumn,
                        ascending: viewModel.sortAscending
                    ) {
                        viewModel.toggleSort(column: .path)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SortableColumnHeader(
                        title: SortColumn.size.title(in: lang),
                        column: .size,
                        currentColumn: viewModel.sortColumn,
                        ascending: viewModel.sortAscending
                    ) {
                        viewModel.toggleSort(column: .size)
                    }
                    .frame(width: sizeW, alignment: .trailing)

                    if kindW > 0 {
                        SortableColumnHeader(
                            title: SortColumn.kind.title(in: lang),
                            column: .kind,
                            currentColumn: viewModel.sortColumn,
                            ascending: viewModel.sortAscending
                        ) {
                            viewModel.toggleSort(column: .kind)
                        }
                        .frame(width: kindW, alignment: .leading)
                        .padding(.leading, 10)
                    }

                    if dateW > 0 {
                        SortableColumnHeader(
                            title: SortColumn.modifiedDate.title(in: lang),
                            column: .modifiedDate,
                            currentColumn: viewModel.sortColumn,
                            ascending: viewModel.sortAscending
                        ) {
                            viewModel.toggleSort(column: .modifiedDate)
                        }
                        .frame(width: dateW, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5.5)
                .background(Color.primary.opacity(0.04))

                Divider()

                // High-Performance Lazy List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.displayedItems) { item in
                            let isSelected = viewModel.selectedItemIDs.contains(item.id)
                            FileListRowView(
                                item: item,
                                highlightQuery: viewModel.quickQuery,
                                isSelected: isSelected,
                                formattedDate: formatDate(item.modifiedDate, lang: lang),
                                lang: lang,
                                nameWidth: nameW,
                                sizeWidth: sizeW,
                                kindWidth: kindW,
                                dateWidth: dateW
                            )
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.handleDoubleClick(on: item)
                            }
                            .simultaneousGesture(
                                TapGesture(count: 1).onEnded {
                                    viewModel.handleSingleClick(on: item)
                                }
                            )
                            .contextMenu {
                                fileContextMenu(for: item, lang: lang)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 2. Hierarchical Folder Tree View
    private func hierarchicalTreeView(lang: AppLanguage) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 11))
                Text(lang.t(
                    "Folder Tree: Bold items are direct matches; dimmed/italic items are parent folders. (⌘ + Double-Click: Reveal in Finder)",
                    "Klasör Ağacı: Koyu yazılanlar doğrudan eşleşmelerdir, soluk/italik olanlar üst klasörlerdir. (⌘ + Çift Tık: Finder'da Göster)"
                ))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.05))

            Divider()

            List(viewModel.treeNodes, children: \.children, selection: $viewModel.selectedItemIDs) { node in
                HStack(spacing: 7) {
                    Image(nsImage: FileIconCache.shared.icon(
                        for: node.path,
                        isDirectory: node.matchedItem?.isDirectory ?? true,
                        fileExtension: (node.name as NSString).pathExtension
                    ))
                    .resizable()
                    .frame(width: 17, height: 17)

                    if node.isDirectMatch, let matched = node.matchedItem {
                        HighlightedFileNameText(name: node.name, query: viewModel.quickQuery)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if matched.isHidden {
                            BadgeLabel(text: lang.t("Hidden", "Gizli"), color: .purple)
                        }
                        Spacer()
                        Text(matched.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(formatDate(matched.modifiedDate, lang: lang))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .trailing)
                    } else {
                        // Enclosing non-matched parent folder
                        Text(node.name)
                            .font(.system(size: 12).italic())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text("\(node.matchCountInSubtree) \(lang.t("matches", "eşleşme"))")
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.secondary.opacity(0.14)))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    viewModel.handlePathDoubleClick(path: node.path, matchedItem: node.matchedItem)
                }
                .contextMenu {
                    if let matched = node.matchedItem {
                        fileContextMenu(for: matched, lang: lang)
                    } else {
                        Button(lang.t("Reveal Folder in Finder (⌘ + Double-Click)", "Klasörü Finder'da Göster (⌘ + Çift Tık)")) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
                        }
                        Button(lang.t("Open Folder (Double-Click)", "Klasörü Aç (Çift Tık)")) {
                            NSWorkspace.shared.open(URL(fileURLWithPath: node.path))
                        }
                        Button(lang.t("Copy Folder Path (⌥ + Double-Click)", "Klasör Yolunu Kopyala (⌥ + Çift Tık)")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(node.path, forType: .string)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: - 3. Preview / Icon Grid View
    private func previewGridView(lang: AppLanguage) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145, maximum: 185), spacing: 10)], spacing: 10) {
                ForEach(viewModel.displayedItems) { item in
                    let isSelected = viewModel.selectedItemIDs.contains(item.id)
                    FileGridCardView(
                        item: item,
                        isSelected: isSelected,
                        lang: lang
                    )
                    .onTapGesture(count: 2) {
                        viewModel.handleDoubleClick(on: item)
                    }
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            viewModel.handleSingleClick(on: item)
                        }
                    )
                    .contextMenu {
                        fileContextMenu(for: item, lang: lang)
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - Empty State
    private func emptyResultsState(lang: AppLanguage) -> some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 66, height: 66)
                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(viewModel.isSearching ? lang.t("Scanning Disk at High Speed...", "Disk Yüksek Hızda Taranıyor...") : lang.t("Ready to Search", "Aramaya Hazır"))
                .font(.system(size: 15.5, weight: .semibold))

            if viewModel.isSearching {
                Text("\(viewModel.totalScannedCount.formatted()) \(lang.t("files scanned", "dosya incelendi"))\n\(viewModel.currentScanningDirectory)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 440)
            } else {
                Text(lang.t(
                    "Type a file name above and press Return, or select a smart preset from the sidebar.",
                    "Yukarıdan bir dosya adı yazıp Enter'a basın veya sol menüdeki hazır akıllı aramalardan birini seçin."
                ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

                // Quick Shortcut Hint Pills
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("HANDY MOUSE & KEYBOARD SHORTCUTS", "PRATİK FARE VE KLAVYE KISAYOLLARI"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        EmptyStateShortcutPill(keys: lang.t("Double-Click", "Çift Tık"), label: lang.t("Open File", "Dosyayı Aç"))
                        EmptyStateShortcutPill(keys: lang.t("⌘ + Double-Click", "⌘ + Çift Tık"), label: lang.t("Reveal in Finder", "Klasörde Göster (Finder)"))
                        EmptyStateShortcutPill(keys: lang.t("⌥ + Double-Click", "⌥ + Çift Tık"), label: lang.t("Copy Path", "Yolu Kopyala"))
                    }
                    HStack(spacing: 8) {
                        EmptyStateShortcutPill(keys: lang.t("Space", "Boşluk"), label: lang.t("Quick Look Preview", "Quick Look Önizleme"))
                        EmptyStateShortcutPill(keys: "⌘ + ⌫", label: lang.t("Move to Trash", "Çöp Sepetine Taşı"))
                        EmptyStateShortcutPill(keys: "⌘1 / ⌘2 / ⌘3", label: lang.t("Switch Views", "Görünüm Değiştir"))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Status & Always-Visible Shortcut Strip
    private func bottomStatusAndShortcutBar(lang: AppLanguage) -> some View {
        VStack(spacing: 0) {
            // Row 1: Live Status + Selected Item Actions
            HStack(spacing: 10) {
                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Circle()
                        .fill(viewModel.displayedItems.isEmpty ? Color.secondary.opacity(0.5) : Color.green)
                        .frame(width: 7, height: 7)
                }

                Text(viewModel.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if !viewModel.selectedItemIDs.isEmpty {
                    HStack(spacing: 6) {
                        Text("\(viewModel.selectedItemIDs.count) \(lang.t("selected", "seçili"))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary)

                        Button {
                            viewModel.revealSelectedInFinder()
                        } label: {
                            Label(lang.t("Reveal in Finder", "Finder'da Göster"), systemImage: "folder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            let urls = viewModel.selectedItemIDs.compactMap { id in
                                viewModel.allFoundItems.first(where: { $0.id == id })?.url
                            }
                            QuickLookCoordinator.shared.toggleQuickLook(for: urls)
                        } label: {
                            Label(lang.t("Quick Look", "Quick Look"), systemImage: "eye")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            viewModel.showInspector = true
                        } label: {
                            Label(lang.t("Inspector", "Detaylar"), systemImage: "info.circle")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            Divider()

            // Row 2: Always-visible Shortcut Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    BottomShortcutBadge(keys: lang.t("Double-Click", "Çift Tık"), text: lang.t("Open", "Aç"))
                    BottomShortcutBadge(keys: lang.t("⌘ + Double-Click", "⌘ + Çift Tık"), text: lang.t("Reveal in Finder Folder", "Bulunduğu Klasörde Göster (Finder)"))
                    BottomShortcutBadge(keys: lang.t("⌥ + Double-Click", "⌥ + Çift Tık"), text: lang.t("Copy Path", "Yolu Kopyala"))
                    BottomShortcutBadge(keys: lang.t("Space", "Boşluk"), text: "Quick Look")
                    BottomShortcutBadge(keys: "⌘⇧R", text: lang.t("Reveal in Finder", "Finder'da Göster"))
                    BottomShortcutBadge(keys: "⌫", text: lang.t("Hide from List", "Listeden Gizle"))
                    BottomShortcutBadge(keys: "⌘⌫", text: lang.t("Move to Trash", "Çöpe Taşı"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .background(Color.primary.opacity(0.025))
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func fileContextMenu(for item: FoundFileItem, lang: AppLanguage) -> some View {
        Button {
            viewModel.openItem(item)
        } label: {
            Label(lang.t("Open (Double-Click)", "Aç (Çift Tık)"), systemImage: "arrow.up.forward.app")
        }

        Button {
            viewModel.revealInFinder(item)
        } label: {
            Label(lang.t("Reveal in Enclosing Folder (⌘ + Double-Click)", "Bulunduğu Klasörde Göster (⌘ + Çift Tık)"), systemImage: "folder")
        }

        Button {
            QuickLookCoordinator.shared.toggleQuickLook(for: [item.url])
        } label: {
            Label(lang.t("Quick Look Preview (Space)", "Quick Look Önizleme (Boşluk)"), systemImage: "eye")
        }

        Button {
            viewModel.selectedItemIDs = [item.id]
            viewModel.showInspector = true
        } label: {
            Label(lang.t("Show Inspector (⌘⌥I)", "Dosya Denetçisinde Göster (⌘⌥I)"), systemImage: "info.circle")
        }

        Divider()

        Button {
            viewModel.copyPath(item)
        } label: {
            Label(lang.t("Copy Full Path (⌥ + Double-Click)", "Tam Yolu Kopyala (⌥ + Çift Tık)"), systemImage: "doc.on.doc")
        }

        Button {
            viewModel.selectedItemIDs.insert(item.id)
            viewModel.removeSelectedFromResults()
        } label: {
            Label(lang.t("Remove from Results (⌫)", "Sonuç Listesinden Kaldır (⌫)"), systemImage: "eye.slash")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.moveItemToTrash(item)
        } label: {
            Label(lang.t("Move to Trash (⌘⌫)", "Çöp Sepetine Taşı (⌘⌫)"), systemImage: "trash")
        }
    }

    private func formatDate(_ date: Date, lang: AppLanguage) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        df.locale = lang.locale
        return df.string(from: date)
    }
}

// MARK: - Subviews for Rows & Cards
private struct FileListRowView: View {
    let item: FoundFileItem
    let highlightQuery: String
    let isSelected: Bool
    let formattedDate: String
    let lang: AppLanguage
    let nameWidth: CGFloat
    let sizeWidth: CGFloat
    let kindWidth: CGFloat
    let dateWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // Name + Icon + Badges
            HStack(spacing: 7) {
                Image(nsImage: FileIconCache.shared.icon(
                    for: item.path,
                    isDirectory: item.isDirectory,
                    fileExtension: item.fileExtension
                ))
                .resizable()
                .frame(width: 17, height: 17)

                HighlightedFileNameText(name: item.name, query: highlightQuery)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.isHidden {
                    BadgeLabel(text: lang.t("Hidden", "Gizli"), color: .purple)
                }
                if item.isInsidePackage {
                    BadgeLabel(text: lang.t("Package", "Paket"), color: .orange)
                }
                if item.isSymlink {
                    BadgeLabel(text: lang.t("Link", "Link"), color: .teal)
                }
            }
            .frame(width: nameWidth, alignment: .leading)
            .padding(.trailing, 6)

            // Parent Path
            Text(item.parentPath)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(item.formattedSize)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                .frame(width: sizeWidth, alignment: .trailing)

            // Kind
            if kindWidth > 0 {
                Text(item.kindDescription(in: lang))
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
                    .frame(width: kindWidth, alignment: .leading)
                    .padding(.leading, 10)
            }

            // Modified Date
            if dateWidth > 0 {
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .frame(width: dateWidth, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(
            isSelected
                ? Color.accentColor
                : Color.clear
        )
    }
}

private struct FileGridCardView: View {
    let item: FoundFileItem
    let isSelected: Bool
    let lang: AppLanguage

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: FileIconCache.shared.highResIcon(for: item.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .padding(.top, 6)

                if item.isHidden {
                    BadgeLabel(text: lang.t("Hidden", "Gizli"), color: .purple)
                        .offset(x: 6, y: 2)
                }
            }

            VStack(spacing: 2) {
                Text(item.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.middle)

                Text("\(item.kindDescription(in: lang)) • \(item.formattedSize)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text((item.parentPath as NSString).lastPathComponent)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 124)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
    }
}

private struct HighlightedFileNameText: View {
    let name: String
    let query: String

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text(name)
        } else if let range = name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) {
            let prefix = String(name[..<range.lowerBound])
            let match = String(name[range])
            let suffix = String(name[range.upperBound...])
            (Text(prefix) +
             Text(match).bold().foregroundColor(.orange) +
             Text(suffix))
        } else {
            Text(name)
        }
    }
}

private struct BadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

private struct BottomShortcutBadge: View {
    let keys: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.09))
                )
                .foregroundStyle(.primary.opacity(0.85))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

private struct EmptyStateShortcutPill: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                )
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct SortableColumnHeader: View {
    let title: String
    let column: SortColumn
    let currentColumn: SortColumn
    let ascending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: currentColumn == column ? .bold : .semibold))
                    .foregroundStyle(currentColumn == column ? .primary : .secondary)
                    .lineLimit(1)
                if currentColumn == column {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class FilterPillState: ObservableObject {
    @Published var isPopoverPresented: Bool = false
}

private struct ThreeStateFilterPill: View {
    let label: String
    let fullTitle: String
    let icon: String
    let lang: AppLanguage
    @Binding var selection: VisibilityFilterMode
    @StateObject private var pillState = FilterPillState()

    var body: some View {
        let isFiltered = selection != .showAll
        Button {
            pillState.isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(label): \(selection.shortTitle(in: lang))")
                    .font(.system(size: 10.5, weight: isFiltered ? .semibold : .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.75)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isFiltered ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isFiltered ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .foregroundStyle(isFiltered ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .popover(isPresented: $pillState.isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(fullTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)

                ForEach(VisibilityFilterMode.allCases) { mode in
                    let isSelected = selection == mode
                    Button {
                        selection = mode
                        pillState.isPopoverPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: modeIcon(mode))
                                .font(.system(size: 11.5))
                                .frame(width: 16)
                            Text(mode.fullDescription(in: lang))
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(7)
            .frame(width: 225)
        }
    }

    private func modeIcon(_ mode: VisibilityFilterMode) -> String {
        switch mode {
        case .showAll: return "eye.fill"
        case .hide: return "eye.slash.fill"
        case .exclusive: return "sparkle.magnifyingglass"
        }
    }
}
