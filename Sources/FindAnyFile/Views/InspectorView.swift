import SwiftUI
import AppKit

public struct InspectorView: View {
    @ObservedObject var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let lang = viewModel.language

        VStack(spacing: 0) {
            // Header
            HStack {
                Label(lang.t("File Inspector", "Dosya Denetçisi"), systemImage: "info.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.showInspector = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(lang.t("Close Inspector (⌘⌥I)", "Denetçiyi Kapat (⌘⌥I)"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))

            Divider()

            if let item = viewModel.primarySelectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Preview Hero Card
                        previewHeader(for: item, lang: lang)

                        // Quick Action Buttons
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ActionCardButton(title: lang.t("Open", "Aç"), icon: "arrow.up.forward.app.fill", color: .blue) {
                                viewModel.openItem(item)
                            }
                            ActionCardButton(title: lang.t("In Finder", "Finder'da Göster"), icon: "folder.fill", color: .indigo) {
                                viewModel.revealInFinder(item)
                            }
                            ActionCardButton(title: "Quick Look", icon: "eye.fill", color: .teal) {
                                QuickLookCoordinator.shared.toggleQuickLook(for: [item.url])
                            }
                            ActionCardButton(title: lang.t("Copy Path", "Yolu Kopyala"), icon: "doc.on.doc.fill", color: .purple) {
                                viewModel.copyPath(item)
                            }
                        }

                        Divider()

                        // Interactive Path Breadcrumbs
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lang.t("LOCATION HIERARCHY", "KONUM HİYERARŞİSİ"))
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.secondary)

                            PathBreadcrumbView(fullPath: item.path) { clickedFolderPath in
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: clickedFolderPath)])
                            }
                        }

                        Divider()

                        // Metadata Table
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("PROPERTIES", "ÖZELLİKLER"))
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.secondary)

                            MetadataRow(label: lang.t("Kind", "Tür"), value: item.kindDescription(in: lang))
                            MetadataRow(label: lang.t("Size", "Boyut"), value: "\(item.formattedSize) (\(item.size.formatted()) \(lang.t("bytes", "bayt")))")
                            MetadataRow(label: lang.t("Modified", "Değiştirilme"), value: formatDetailDate(item.modifiedDate, lang: lang))
                            MetadataRow(label: lang.t("Created", "Oluşturulma"), value: formatDetailDate(item.createdDate, lang: lang))
                            MetadataRow(label: lang.t("Permissions", "İzinler (POSIX)"), value: String(format: "0%o (%@)", item.posixPermissions, symbolicPermissions(item.posixPermissions)))
                            MetadataRow(label: lang.t("Hidden Item", "Gizli Öğe"), value: item.isHidden ? lang.t("Yes", "Evet") : lang.t("No", "Hayır"))
                            MetadataRow(label: lang.t("In Package", "Paket İçinde"), value: item.isInsidePackage ? lang.t("Yes", "Evet") : lang.t("No", "Hayır"))
                        }

                        // Text/Code Snippet Preview if readable
                        if let snippet = loadTextPreview(for: item) {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(lang.t("CONTENT PREVIEW", "İÇERİK ÖNİZLEMESİ"))
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(.secondary)

                                Text(snippet)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.primary.opacity(0.85))
                                    .lineLimit(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }

                        Divider()

                        // Destructive Action
                        Button(role: .destructive) {
                            viewModel.moveItemToTrash(item)
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text(lang.t("Move to Trash", "Çöp Sepetine Taşı"))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red.opacity(0.12))
                            )
                            .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                }
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(lang.t(
                        "Select a file to inspect details, preview content, and perform quick actions",
                        "Detaylarını ve önizlemesini görmek için listeden bir dosya seçin"
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 255)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func previewHeader(for item: FoundFileItem, lang: AppLanguage) -> some View {
        VStack(spacing: 10) {
            if isImageFile(item.fileExtension), let nsImg = NSImage(contentsOfFile: item.path) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(radius: 3)
            } else {
                Image(nsImage: FileIconCache.shared.highResIcon(for: item.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
            }

            Text(item.name)
                .font(.system(size: 13.5, weight: .bold))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            Text(item.kindDescription(in: lang))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func isImageFile(_ ext: String) -> Bool {
        let lower = ext.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "ico"].contains(lower)
    }

    private func loadTextPreview(for item: FoundFileItem) -> String? {
        guard !item.isDirectory && item.size > 0 && item.size < 500_000 else { return nil }
        guard let handle = FileHandle(forReadingAtPath: item.path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 2048), !data.isEmpty else { return nil }
        if data.contains(0) { return nil } // Skip binary
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDetailDate(_ date: Date, lang: AppLanguage) -> String {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .medium
        df.locale = lang.locale
        return df.string(from: date)
    }

    private func symbolicPermissions(_ mode: Int) -> String {
        let chars = [
            (mode & 0o400) != 0 ? "r" : "-",
            (mode & 0o200) != 0 ? "w" : "-",
            (mode & 0o100) != 0 ? "x" : "-",
            (mode & 0o040) != 0 ? "r" : "-",
            (mode & 0o020) != 0 ? "w" : "-",
            (mode & 0o010) != 0 ? "x" : "-",
            (mode & 0o004) != 0 ? "r" : "-",
            (mode & 0o002) != 0 ? "w" : "-",
            (mode & 0o001) != 0 ? "x" : "-"
        ]
        return chars.joined()
    }
}

private struct ActionCardButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(width: 95, alignment: .leading)
            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PathBreadcrumbView: View {
    let fullPath: String
    let onSelectFolder: (String) -> Void

    var body: some View {
        let components = pathComponents(from: fullPath)
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(components.enumerated()), id: \.offset) { idx, comp in
                Button {
                    onSelectFolder(comp.path)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: idx == components.count - 1 ? "doc.fill" : "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(idx == components.count - 1 ? Color.accentColor : .secondary)
                        Text(comp.name)
                            .font(.system(size: 11, weight: idx == components.count - 1 ? .semibold : .regular))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.leading, CGFloat(min(idx, 6) * 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func pathComponents(from path: String) -> [(name: String, path: String)] {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        var result: [(String, String)] = []
        var accum = ""
        for p in parts {
            accum += "/\(p)"
            result.append((String(p), accum))
        }
        if result.count > 6 {
            return Array(result.suffix(6))
        }
        return result
    }
}
