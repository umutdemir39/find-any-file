import SwiftUI

public struct RuleBuilderView: View {
    @ObservedObject var viewModel: SearchViewModel
    @FocusState.Binding var isSearchFieldFocused: Bool

    @StateObject private var uiState = RuleBuilderUIState()

    public init(viewModel: SearchViewModel, isSearchFieldFocused: FocusState<Bool>.Binding) {
        self.viewModel = viewModel
        self._isSearchFieldFocused = isSearchFieldFocused
    }

    public var body: some View {
        let lang = viewModel.language

        VStack(alignment: .leading, spacing: 8) {
            // MARK: - 1. Primary Search Bar Row (Fully Responsive)
            HStack(spacing: 7) {
                // Toggle Left Sidebar Button
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.showSidebar ? Color.accentColor : .secondary)
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(viewModel.showSidebar ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help(lang.t("Toggle Sidebar (⌘0)", "Sol Menüyü Göster / Gizle (⌘0)"))

                // Target Location Button + Popover
                Button {
                    uiState.showTargetPopover.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.target.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text(targetDisplayLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .popover(isPresented: $uiState.showTargetPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.t("Select Search Location", "Arama Konumu Seçin"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)

                        ForEach(SearchTargetType.allCases) { targetType in
                            let isSelected = viewModel.target == targetType
                            Button {
                                uiState.showTargetPopover = false
                                if targetType == .custom {
                                    viewModel.selectCustomFolder()
                                } else {
                                    viewModel.target = targetType
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: targetType.iconName)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(isSelected ? .white : .blue)
                                        .frame(width: 18)
                                    Text(targetType.title(in: lang))
                                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
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
                    .padding(8)
                    .frame(width: 270)
                }

                // Instant Search Input Field
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField(
                        lang.t("Search file name, extension (.pdf, .plist) or words...", "Dosya adı, uzantı (.pdf, .plist) veya kelime ara..."),
                        text: $viewModel.quickQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        viewModel.startSearch()
                    }

                    if !viewModel.quickQuery.isEmpty {
                        Button {
                            viewModel.quickQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSearchFieldFocused ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isSearchFieldFocused ? 1.5 : 1)
                )

                // Advanced Rules Toggle Button
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if viewModel.rules.isEmpty {
                            viewModel.addRule(field: .name)
                        } else {
                            viewModel.showAdvancedRules.toggle()
                        }
                    }
                } label: {
                    let isOpen = viewModel.showAdvancedRules && !viewModel.rules.isEmpty
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text(viewModel.rules.isEmpty ? lang.t("Add Rule", "Kural Ekle") : "\(lang.t("Rules", "Kurallar")) (\(viewModel.rules.count))")
                            .font(.system(size: 11.5, weight: .semibold))
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isOpen ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isOpen ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .foregroundStyle(isOpen ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)

                // Primary Search / Stop Button
                if viewModel.isSearching {
                    Button {
                        viewModel.stopSearch()
                    } label: {
                        HStack(spacing: 5) {
                            ProgressView()
                                .controlSize(.small)
                            Text(lang.t("Stop", "Durdur"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.red)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button {
                        viewModel.startSearch()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.useRootMode ? "lock.shield.fill" : "bolt.fill")
                                .font(.system(size: 11.5))
                            Text(viewModel.useRootMode ? lang.t("Find as Root", "Root İle Bul") : lang.t("Find", "Bul"))
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 6.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: viewModel.useRootMode
                                            ? [Color.orange, Color.red]
                                            : [Color.blue, Color.indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .keyboardShortcut(.defaultAction)
                }

                // Language Switcher Pill (EN | TR)
                Button {
                    viewModel.language = (viewModel.language == .en) ? .tr : .en
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "globe")
                            .font(.system(size: 10.5))
                        Text(viewModel.language == .en ? "EN" : "TR")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help(lang.t("Switch Language (EN / TR)", "Dili Değiştir (EN / TR)"))
            }

            // MARK: - 2. Scrollable Category & Engine Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach([
                        FileKindCategory.any,
                        .file,
                        .folder,
                        .application,
                        .image,
                        .video,
                        .audio,
                        .document,
                        .pdf,
                        .code,
                        .archive
                    ]) { kind in
                        let isSelected = viewModel.quickKindFilter == kind
                        Button {
                            viewModel.quickKindFilter = kind
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: kind.iconName)
                                    .font(.system(size: 10))
                                Text(kind.shortTitle(in: lang))
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(height: 16)
                        .padding(.horizontal, 3)

                    OptionTogglePill(
                        title: "Spotlight Turbo",
                        icon: "bolt.horizontal.fill",
                        isOn: $viewModel.includeSpotlight,
                        activeColor: .teal,
                        helpText: lang.t(
                            "Combines Spotlight index with direct multi-core filesystem scanning for maximum speed",
                            "Spotlight indeksini ve doğrudan dosya sistemi taramasını hibrit olarak birlikte çalıştırır"
                        )
                    )

                    OptionTogglePill(
                        title: lang.t("Case-Sensitive", "Harf Duyarlı"),
                        icon: "textformat",
                        isOn: $viewModel.caseSensitive,
                        activeColor: .purple,
                        helpText: lang.t("Case-sensitive search", "Büyük/küçük harf duyarlı arama")
                    )

                    OptionTogglePill(
                        title: lang.t("Root Mode", "Root Modu"),
                        icon: "key.fill",
                        isOn: $viewModel.useRootMode,
                        activeColor: .orange,
                        helpText: lang.t(
                            "Scan restricted system and other users' directories with root privileges",
                            "Yönetici (Root) yetkisiyle kısıtlı klasörleri de tarar"
                        )
                    )
                }
            }

            // MARK: - 3. Multi-Rule Criteria Builder Panel
            if viewModel.showAdvancedRules && !viewModel.rules.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Label(lang.t("Advanced Rules:", "Gelişmiş Kurallar:"), systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)

                            QuickAddRuleChip(title: lang.t("+ File Size", "+ Boyut Filtresi"), icon: "internaldrive") {
                                viewModel.rules.append(SearchRule(field: .size, op: .greaterThan, numberValue: 50, sizeUnit: .mb))
                            }
                            QuickAddRuleChip(title: lang.t("+ Date Modified", "+ Tarih Filtresi"), icon: "calendar") {
                                viewModel.rules.append(SearchRule(field: .modifiedDate, op: .inLast, numberValue: 7, timeUnit: .days))
                            }
                            QuickAddRuleChip(title: lang.t("+ Extension", "+ Uzantı"), icon: "puzzlepiece.extension") {
                                viewModel.rules.append(SearchRule(field: .fileExtension, op: .equals, stringValue: "pdf"))
                            }
                            QuickAddRuleChip(title: lang.t("+ Text Content", "+ İçerik (Metin)"), icon: "doc.text.magnifyingglass") {
                                viewModel.rules.append(SearchRule(field: .content, op: .contains, stringValue: ""))
                            }
                        }
                    }

                    ForEach($viewModel.rules) { $rule in
                        RuleRowView(
                            rule: $rule,
                            lang: lang,
                            onSubmit: {
                                viewModel.startSearch()
                            },
                            onAddBelow: {
                                viewModel.addRule(field: .name)
                            },
                            onRemove: {
                                viewModel.removeRule(id: rule.id)
                            }
                        )
                    }

                    HStack {
                        Button {
                            viewModel.addRule(field: .name)
                        } label: {
                            Label(lang.t("Add New Rule Row", "Yeni Kural Satırı Ekle"), systemImage: "plus.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.rules.removeAll()
                                viewModel.showAdvancedRules = false
                            }
                        } label: {
                            Label(lang.t("Clear All Rules", "Kuralları Temizle"), systemImage: "trash")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var targetDisplayLabel: String {
        viewModel.target.shortTitle(in: viewModel.language, customPath: viewModel.customPath)
    }
}

@MainActor
private final class RuleBuilderUIState: ObservableObject {
    @Published var showTargetPopover: Bool = false
}

// MARK: - Individual Rule Row
private struct RuleRowView: View {
    @Binding var rule: SearchRule
    let lang: AppLanguage
    let onSubmit: () -> Void
    let onAddBelow: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Picker("", selection: $rule.field) {
                ForEach(RuleField.allCases) { f in
                    Text(f.title(in: lang)).tag(f)
                }
            }
            .labelsHidden()
            .frame(width: 175)
            .onChange(of: rule.field) { _, newField in
                let validOps = newField.availableOperators
                if !validOps.contains(rule.op), let first = validOps.first {
                    rule.op = first
                }
            }

            Picker("", selection: $rule.op) {
                ForEach(rule.field.availableOperators) { op in
                    Text(op.title(in: lang)).tag(op)
                }
            }
            .labelsHidden()
            .frame(width: 155)

            ruleValueInput
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

            Button(action: onAddBelow) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(lang.t("Add rule below", "Altına kural ekle"))

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help(lang.t("Remove this rule", "Bu kuralı sil"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .opacity(rule.isEnabled ? 1.0 : 0.5)
    }

    @ViewBuilder
    private var ruleValueInput: some View {
        switch rule.field {
        case .name, .nameWithoutExtension, .fileExtension, .fullPath, .content:
            TextField(placeholderForField(rule.field), text: $rule.stringValue)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSubmit)
        case .kind:
            Picker("", selection: $rule.kindValue) {
                ForEach(FileKindCategory.allCases) { k in
                    Text(k.title(in: lang)).tag(k)
                }
            }
            .labelsHidden()
        case .size:
            HStack(spacing: 5) {
                TextField(lang.t("Value", "Değer"), value: $rule.numberValue, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit(onSubmit)
                Picker("", selection: $rule.sizeUnit) {
                    ForEach(SizeUnit.allCases) { u in
                        Text(u.rawValue).tag(u)
                    }
                }
                .labelsHidden()
                .frame(width: 85)
            }
        case .modifiedDate, .createdDate:
            if rule.op == .inLast {
                HStack(spacing: 5) {
                    TextField(lang.t("Time", "Süre"), value: $rule.numberValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 65)
                        .onSubmit(onSubmit)
                    Picker("", selection: $rule.timeUnit) {
                        ForEach(TimeUnit.allCases) { tu in
                            Text(tu.title(in: lang)).tag(tu)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 95)
                }
            } else {
                DatePicker("", selection: $rule.dateValue, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
    }

    private func placeholderForField(_ field: RuleField) -> String {
        switch field {
        case .name: return lang.t("File name (e.g. report, config)...", "Dosya adı (Örn: rapor, config)...")
        case .nameWithoutExtension: return lang.t("Name w/o extension...", "Uzantısız ad...")
        case .fileExtension: return lang.t("Extension (e.g. pdf, dmg, zip)...", "Uzantı (Örn: pdf, dmg, zip)...")
        case .fullPath: return lang.t("Folder path snippet...", "Klasör yolu...")
        case .content: return lang.t("Text inside file...", "Dosya içi metin...")
        default: return lang.t("Enter value...", "Değer girin...")
        }
    }
}

private struct QuickAddRuleChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }
}

private struct OptionTogglePill: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let activeColor: Color
    let helpText: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isOn ? activeColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? activeColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .foregroundStyle(isOn ? activeColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
