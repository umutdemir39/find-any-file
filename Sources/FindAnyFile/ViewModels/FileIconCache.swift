import AppKit
import Quartz

@MainActor
public final class FileIconCache {
    public static let shared = FileIconCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 2500
    }

    public func icon(for path: String, isDirectory: Bool, fileExtension: String) -> NSImage {
        let key: NSString
        if !isDirectory && !fileExtension.isEmpty && !path.hasSuffix(".app") {
            // Cache by extension for standard files so scrolling 50,000 rows is 120fps
            key = "ext_\(fileExtension.lowercased())" as NSString
        } else {
            key = path as NSString
        }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 24, height: 24)
        cache.setObject(img, forKey: key)
        return img
    }

    public func highResIcon(for path: String) -> NSImage {
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: 128, height: 128)
        return img
    }
}

@MainActor
public final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookCoordinator()
    private var urls: [URL] = []

    public func toggleQuickLook(for urls: [URL]) {
        self.urls = urls
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            panel.reloadData()
        }
    }

    public func updateQuickLookIfVisible(for urls: [URL]) {
        self.urls = urls
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        panel.dataSource = self
        panel.reloadData()
    }

    nonisolated public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            urls.count
        }
    }

    nonisolated public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            guard index >= 0 && index < urls.count else { return nil }
            return urls[index] as NSURL
        }
    }
}

