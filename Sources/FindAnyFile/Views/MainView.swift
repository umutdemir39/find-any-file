import SwiftUI

public struct MainView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let lang = viewModel.language

        HStack(spacing: 0) {
            // MARK: - 1. Custom Responsive Left Sidebar
            if viewModel.showSidebar {
                sidebarView(lang: lang)
                    .frame(width: 220)
                    .transition(.move(edge: .leading))
                Divider()
            }

            // MARK: - 2. Flexible Center Area
            VStack(spacing: 0) {
                RuleBuilderView(
                    viewModel: viewModel,
                    isSearchFieldFocused: $isSearchFieldFocused
                )
                Divider()
                ResultsContainerView(viewModel: viewModel)
            }
            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - 3. Collapsible Right Inspector
            if viewModel.showInspector {
                Divider()
                InspectorView(viewModel: viewModel)
                    .frame(width: 255)
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(minWidth: 740, minHeight: 480)
        .onAppear {
            isSearchFieldFocused = true
        }
        .sheet(isPresented: $viewModel.showShortcutsPopover) {
            ShortcutsGuideSheet(isPresented: $viewModel.showShortcutsPopover, lang: viewModel.language)
        }
    }

    // MARK: - Custom Compact Sidebar
    private func sidebarView(lang: AppLanguage) -> some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Section 1: Target Disks & Folders
                    VStack(alignment: .leading, spacing: 3) {
                        sidebarSectionHeader(lang.t("SEARCH SCOPE", "ARAMA KONUMU"), icon: "externaldrive.fill")

                        ForEach(SearchTargetType.allCases) { loc in
                            let isSelected = viewModel.target == loc
                            Button {
                                if loc == .custom {
                                    viewModel.selectCustomFolder()
                                } else {
                                    viewModel.target = loc
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: loc.iconName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(isSelected ? .white : .blue)
                                        .frame(width: 16)
                                    Text(loc.title(in: lang))
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
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

                    Divider()

                    // Section 2: Smart Presets
                    VStack(alignment: .leading, spacing: 4) {
                        sidebarSectionHeader(lang.t("SMART PRESETS", "HAZIR AKILLI ARAMALAR"), icon: "sparkles")

                        ForEach(SearchPreset.builtInPresets) { preset in
                            Button {
                                viewModel.applyPreset(preset)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: preset.iconName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: preset.accentHex))
                                        .frame(width: 22, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color(hex: preset.accentHex).opacity(0.14))
                                        )

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(preset.title(in: lang))
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(preset.subtitle(in: lang))
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.primary.opacity(0.03))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider()

                    // Section 3: Saved Searches
                    VStack(alignment: .leading, spacing: 4) {
                        sidebarSectionHeader(lang.t("SAVED SEARCHES", "KAYITLI ARAMALARIM"), icon: "star.fill")

                        if viewModel.savedPresets.isEmpty {
                            Text(lang.t("Save frequent searches to run with one click.", "Sık kullandığınız kuralları kaydedip tek tıkla çalıştırın."))
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                        } else {
                            ForEach(viewModel.savedPresets) { saved in
                                HStack(spacing: 6) {
                                    Button {
                                        viewModel.applyPreset(saved)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                                .font(.system(size: 11))
                                            Text(saved.title(in: lang))
                                                .font(.system(size: 11.5, weight: .medium))
                                                .lineLimit(1)
                                            Spacer(minLength: 0)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        viewModel.deleteSavedPreset(id: saved.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                            }
                        }

                        Button {
                            viewModel.newPresetTitle = viewModel.quickQuery.isEmpty 
                                ? lang.t("Custom Search", "Özel Arama") 
                                : viewModel.quickQuery
                            viewModel.showingSavePresetPopover = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                Text(lang.t("Save Current Search", "Mevcut Aramayı Kaydet"))
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $viewModel.showingSavePresetPopover) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(lang.t("Save Search", "Aramayı Kaydet"))
                                    .font(.system(size: 13, weight: .bold))
                                TextField(lang.t("Search name...", "Arama adı..."), text: $viewModel.newPresetTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 210)
                                HStack {
                                    Spacer()
                                    Button(lang.t("Cancel", "İptal")) {
                                        viewModel.showingSavePresetPopover = false
                                    }
                                    Button(lang.t("Save", "Kaydet")) {
                                        viewModel.saveCurrentSearchAsPreset(title: viewModel.newPresetTitle)
                                        viewModel.showingSavePresetPopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(12)
                        }
                    }
                }
                .padding(10)
            }

            Divider()

            // Fixed Bottom Quick Shortcuts Card in Sidebar
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label(lang.t("Quick Shortcuts", "Hızlı Kısayollar"), systemImage: "command.square.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(lang.t("All", "Tümü")) {
                        viewModel.showShortcutsPopover = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                }

                SidebarShortcutRow(keys: lang.t("Double-Click", "Çift Tık"), desc: lang.t("Open File", "Dosyayı Aç"))
                SidebarShortcutRow(keys: lang.t("⌘ + Double-Click", "⌘ + Çift Tık"), desc: lang.t("Reveal in Finder", "Klasörde Göster"))
                SidebarShortcutRow(keys: lang.t("⌥ + Double-Click", "⌥ + Çift Tık"), desc: lang.t("Copy Path", "Yolu Kopyala"))
                SidebarShortcutRow(keys: lang.t("Space", "Boşluk"), desc: "Quick Look")
                SidebarShortcutRow(keys: "⌘ + ⌫", desc: lang.t("Move to Trash", "Çöpe Taşı"))
            }
            .padding(10)
            .background(Color.primary.opacity(0.035))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sidebarSectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

private struct SidebarShortcutRow: View {
    let keys: String
    let desc: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.09))
                )
            Spacer(minLength: 4)
            Text(desc)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Full Shortcuts Reference Sheet
public struct ShortcutsGuideSheet: View {
    @Binding var isPresented: Bool
    let lang: AppLanguage

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(lang.t("Mouse & Keyboard Shortcuts Guide", "Fare ve Klavye Kısayolları Rehberi"), systemImage: "keyboard.fill")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("🖱️ Mouse Actions (In Results List)", "🖱️ Fare Kısayolları (Sonuç Listesinde)"))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.blue)

                    ShortcutDetailRow(
                        keys: lang.t("Left Double-Click", "Sol Çift Tık"),
                        action: lang.t("Opens the file or folder directly", "Dosyayı veya klasörü doğrudan açar")
                    )
                    ShortcutDetailRow(
                        keys: lang.t("⌘ Command + Double-Click", "⌘ Command + Çift Tık"),
                        action: lang.t("Opens enclosing folder in Finder and selects the file", "Bulunduğu klasörü Finder'da açar ve dosyayı seçili gösterir")
                    )
                    ShortcutDetailRow(
                        keys: lang.t("⌥ Option + Double-Click", "⌥ Option + Çift Tık"),
                        action: lang.t("Copies the full path to clipboard", "Dosyanın tam yolunu panoya kopyalar")
                    )
                    ShortcutDetailRow(
                        keys: lang.t("⌘ Command + Single-Click", "⌘ Command + Tek Tık"),
                        action: lang.t("Selects / unselects multiple files", "Çoklu dosya seçimi yapar / kaldırır")
                    )
                    ShortcutDetailRow(
                        keys: lang.t("Right-Click", "Sağ Tık"),
                        action: lang.t("Opens quick action context menu", "Hızlı işlem menüsünü açar")
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("⌨️ Keyboard Shortcuts", "⌨️ Klavye Kısayolları"))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.indigo)

                    ShortcutDetailRow(
                        keys: lang.t("Spacebar", "Boşluk (Space)"),
                        action: lang.t("Instant Quick Look preview for selected file", "Seçili dosyayı Quick Look ile anında önizler")
                    )
                    ShortcutDetailRow(
                        keys: "⌘ + ⇧ + R",
                        action: lang.t("Reveal selected files in Finder", "Seçili dosyayı Finder'da klasörüyle gösterir")
                    )
                    ShortcutDetailRow(
                        keys: lang.t("⌘ + ↓ (Down Arrow)", "⌘ + ↓ (Aşağı Ok)"),
                        action: lang.t("Open selected files", "Seçili dosyayı açar")
                    )
                    ShortcutDetailRow(
                        keys: "⌘ + ⌥ + C",
                        action: lang.t("Copy full paths of selected files", "Seçili dosyanın tam yolunu kopyalar")
                    )
                    ShortcutDetailRow(
                        keys: "⌫ (Delete)",
                        action: lang.t("Hide from results list (does not delete from disk)", "Sonuç listesinden kaldırır (Diskten silmez)")
                    )
                    ShortcutDetailRow(
                        keys: "⌘ + ⌫",
                        action: lang.t("Move selected files to Trash", "Seçili dosyayı Çöp Sepetine taşır")
                    )
                    ShortcutDetailRow(
                        keys: "⌘1 / ⌘2 / ⌘3",
                        action: lang.t("Switch between List / Tree / Grid view", "Liste / Klasör Ağacı / Izgara görünümü")
                    )
                    ShortcutDetailRow(
                        keys: "⌘0 / ⌘⌥I",
                        action: lang.t("Toggle Left Sidebar / Right Inspector", "Sol Menüyü / Sağ Denetçiyi göster-gizle")
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Text(lang.t(
                    "Tip: You can drag and drop any folder from Finder onto the search bar to search inside it.",
                    "İpucu: Arama çubuğuna Finder'dan herhangi bir klasörü sürükleyip bırakarak doğrudan o klasörde arama yapabilirsiniz."
                ))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                Spacer()
                Button(lang.t("Got it", "Tamam")) {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 660, height: 360)
    }
}

private struct ShortcutDetailRow: View {
    let keys: String
    let action: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(keys)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            Text(action)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (59, 130, 246)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1.0
        )
    }
}
