import SwiftUI
import AppKit

@main
struct FindAnyFileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = SearchViewModel()

    var body: some Scene {
        let lang = viewModel.language

        WindowGroup("Find Any File (Ultra Fast & Free)") {
            MainView(viewModel: viewModel)
        }
        .defaultSize(width: 1260, height: 780)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandMenu(lang.t("Search", "Arama")) {
                Button(lang.t("Start Search", "Aramayı Başlat")) {
                    viewModel.startSearch()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button(lang.t("Stop Search", "Aramayı Durdur")) {
                    viewModel.stopSearch()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!viewModel.isSearching)

                Divider()

                Button(lang.t("Add New Rule", "Yeni Kural Ekle")) {
                    viewModel.addRule(field: .name)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button(lang.t("Clear Search & Rules", "Kuralları ve Sorguyu Temizle")) {
                    viewModel.clearRules()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button(lang.t("Choose Custom Folder...", "Özel Klasör Seç...")) {
                    viewModel.selectCustomFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu(lang.t("View", "Görünüm")) {
                Button(lang.t("Flat List View", "Liste Görünümü")) {
                    viewModel.viewMode = .list
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button(lang.t("Folder Tree View", "Klasör Ağacı Görünümü (Tree)")) {
                    viewModel.viewMode = .tree
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button(lang.t("Preview Grid View", "Önizleme Izgarası (Grid)")) {
                    viewModel.viewMode = .grid
                }
                .keyboardShortcut("3", modifiers: [.command])

                Divider()

                Button(lang.t("Toggle Left Sidebar", "Sol Menüyü Göster/Gizle")) {
                    viewModel.showSidebar.toggle()
                }
                .keyboardShortcut("0", modifiers: [.command])

                Button(lang.t("Toggle File Inspector", "Dosya Denetçisini Göster/Gizle")) {
                    viewModel.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Divider()

                Button(lang.t("Switch Language to Türkçe", "Dili English Olarak Değiştir")) {
                    viewModel.language = (viewModel.language == .en) ? .tr : .en
                }

                Button(lang.t("Mouse & Keyboard Shortcuts Guide...", "Fare ve Klavye Kısayolları Rehberi...")) {
                    viewModel.showShortcutsPopover = true
                }
                .keyboardShortcut("/", modifiers: [.command])
            }

            CommandMenu(lang.t("Actions", "Sonuç İşlemleri")) {
                Button(lang.t("Open Selected Files", "Seçili Öğeleri Aç")) {
                    viewModel.openSelectedItems()
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])
                .disabled(viewModel.selectedItemIDs.isEmpty)

                Button(lang.t("Reveal in Finder", "Finder'da Göster")) {
                    viewModel.revealSelectedInFinder()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(viewModel.selectedItemIDs.isEmpty)

                Button(lang.t("Copy Full Paths", "Tam Yolu Kopyala")) {
                    viewModel.copySelectedPaths()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(viewModel.selectedItemIDs.isEmpty)

                Button(lang.t("Hide from Results List", "Sonuç Listesinden Kaldır")) {
                    viewModel.removeSelectedFromResults()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(viewModel.selectedItemIDs.isEmpty)

                Divider()

                Button(lang.t("Move to Trash", "Çöp Sepetine Taşı")) {
                    viewModel.moveSelectedToTrash()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(viewModel.selectedItemIDs.isEmpty)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
