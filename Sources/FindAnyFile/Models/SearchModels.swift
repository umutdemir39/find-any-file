import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Application Language (Default: English)
public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case en = "en"
    case tr = "tr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }

    public var shortCode: String {
        switch self {
        case .en: return "EN"
        case .tr: return "TR"
        }
    }

    public var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_US")
        case .tr: return Locale(identifier: "tr_TR")
        }
    }

    public func t(_ en: String, _ tr: String) -> String {
        self == .en ? en : tr
    }
}

// MARK: - Search Target / Scope
public enum SearchTargetType: String, CaseIterable, Identifiable, Codable, Sendable {
    case home = "home"
    case desktop = "desktop"
    case documents = "documents"
    case downloads = "downloads"
    case applications = "applications"
    case userLibrary = "userLibrary"
    case systemLibrary = "systemLibrary"
    case startupDisk = "startupDisk"
    case allVolumes = "allVolumes"
    case custom = "custom"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .home: return lang.t("Home Folder (~)", "Ev Klasörü (Home)")
        case .desktop: return lang.t("Desktop", "Masaüstü (Desktop)")
        case .documents: return lang.t("Documents", "Belgeler (Documents)")
        case .downloads: return lang.t("Downloads", "İndirilenler (Downloads)")
        case .applications: return lang.t("Applications (/Apps)", "Uygulamalar (/Apps)")
        case .userLibrary: return lang.t("User Library (~/Library)", "Kullanıcı Library (~/Lib)")
        case .systemLibrary: return lang.t("System Library (/Library)", "Sistem Library (/Lib)")
        case .startupDisk: return lang.t("Startup Disk (/)", "Başlangıç Diski (/)")
        case .allVolumes: return lang.t("All Volumes (/Volumes)", "Tüm Diskler (/Volumes)")
        case .custom: return lang.t("Choose Custom Folder...", "Özel Klasör Seç...")
        }
    }

    public func shortTitle(in lang: AppLanguage, customPath: String) -> String {
        if self == .custom {
            let folderName = (customPath as NSString).lastPathComponent
            return folderName.isEmpty ? customPath : folderName
        }
        switch self {
        case .home: return lang.t("Home", "Ev Klasörü")
        case .desktop: return lang.t("Desktop", "Masaüstü")
        case .documents: return lang.t("Documents", "Belgeler")
        case .downloads: return lang.t("Downloads", "İndirilenler")
        case .applications: return lang.t("Applications", "Uygulamalar")
        case .userLibrary: return "~/Library"
        case .systemLibrary: return lang.t("System Lib", "Sistem Library")
        case .startupDisk: return lang.t("Startup Disk (/)", "Tüm Disk (/)")
        case .allVolumes: return lang.t("All Disks", "Tüm Diskler")
        case .custom: return lang.t("Custom", "Özel Klasör")
        }
    }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .desktop: return "menubar.dock.rectangle"
        case .documents: return "doc.text.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .applications: return "app.badge.fill"
        case .userLibrary: return "building.columns.fill"
        case .systemLibrary: return "gearshape.2.fill"
        case .startupDisk: return "internaldrive.fill"
        case .allVolumes: return "externaldrive.connected.to.line.below.fill"
        case .custom: return "folder.badge.gearshape"
        }
    }

    public func resolvedPaths(customPath: String) -> [String] {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .home:
            return [homeDir]
        case .desktop:
            return [(homeDir as NSString).appendingPathComponent("Desktop")]
        case .documents:
            return [(homeDir as NSString).appendingPathComponent("Documents")]
        case .downloads:
            return [(homeDir as NSString).appendingPathComponent("Downloads")]
        case .applications:
            return ["/Applications", (homeDir as NSString).appendingPathComponent("Applications")]
        case .userLibrary:
            return [(homeDir as NSString).appendingPathComponent("Library")]
        case .systemLibrary:
            return ["/Library", "/System/Library", (homeDir as NSString).appendingPathComponent("Library")]
        case .startupDisk:
            return ["/"]
        case .allVolumes:
            var paths = ["/"]
            if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) {
                for url in urls where url.path != "/" {
                    paths.append(url.path)
                }
            }
            return Array(Set(paths))
        case .custom:
            return customPath.isEmpty ? [homeDir] : [customPath]
        }
    }
}

// MARK: - Rule Definitions
public enum RuleField: String, CaseIterable, Identifiable, Codable, Sendable {
    case name = "name"
    case nameWithoutExtension = "nameWithoutExtension"
    case fileExtension = "fileExtension"
    case fullPath = "fullPath"
    case content = "content"
    case kind = "kind"
    case size = "size"
    case modifiedDate = "modifiedDate"
    case createdDate = "createdDate"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .name: return lang.t("Name", "Dosya Adı")
        case .nameWithoutExtension: return lang.t("Name without Extension", "Uzantısız Ad")
        case .fileExtension: return lang.t("Extension", "Uzantı")
        case .fullPath: return lang.t("Full Path", "Tam Yol")
        case .content: return lang.t("File Content (Text)", "Dosya İçeriği (Metin)")
        case .kind: return lang.t("File Kind", "Dosya Türü")
        case .size: return lang.t("File Size", "Dosya Boyutu")
        case .modifiedDate: return lang.t("Date Modified", "Değiştirilme Tarihi")
        case .createdDate: return lang.t("Date Created", "Oluşturulma Tarihi")
        }
    }

    public var icon: String {
        switch self {
        case .name: return "textformat"
        case .nameWithoutExtension: return "character.cursor.ibeam"
        case .fileExtension: return "puzzlepiece.extension"
        case .fullPath: return "point.topleft.down.curvedto.point.bottomright.up"
        case .content: return "doc.text.magnifyingglass"
        case .kind: return "square.grid.2x2"
        case .size: return "internaldrive"
        case .modifiedDate: return "clock.arrow.circlepath"
        case .createdDate: return "calendar.badge.plus"
        }
    }

    public var availableOperators: [RuleOperator] {
        switch self {
        case .name, .nameWithoutExtension, .fullPath:
            return [.contains, .beginsWith, .endsWith, .equals, .doesNotContain, .matchesRegex]
        case .fileExtension:
            return [.equals, .contains, .isAnyOf, .doesNotContain]
        case .content:
            return [.contains, .doesNotContain, .matchesRegex]
        case .kind:
            return [.equals, .isNot]
        case .size:
            return [.greaterThan, .lessThan, .equals]
        case .modifiedDate, .createdDate:
            return [.inLast, .afterDate, .beforeDate]
        }
    }
}

public enum RuleOperator: String, CaseIterable, Identifiable, Codable, Sendable {
    case contains = "contains"
    case beginsWith = "beginsWith"
    case endsWith = "endsWith"
    case equals = "equals"
    case isNot = "isNot"
    case doesNotContain = "doesNotContain"
    case isAnyOf = "isAnyOf"
    case matchesRegex = "matchesRegex"
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    case inLast = "inLast"
    case afterDate = "afterDate"
    case beforeDate = "beforeDate"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .contains: return lang.t("contains", "içerir")
        case .beginsWith: return lang.t("begins with", "ile başlar")
        case .endsWith: return lang.t("ends with", "ile biter")
        case .equals: return lang.t("is (equals)", "eşittir")
        case .isNot: return lang.t("is not", "değildir")
        case .doesNotContain: return lang.t("does not contain", "içermez")
        case .isAnyOf: return lang.t("is any of (comma-sep)", "şunlardan biri (virgülle)")
        case .matchesRegex: return lang.t("matches Regex", "Regex eşleşir")
        case .greaterThan: return lang.t("is greater than (>)", "büyüktür (>)")
        case .lessThan: return lang.t("is less than (<)", "küçüktür (<)")
        case .inLast: return lang.t("within last", "son şu sürede")
        case .afterDate: return lang.t("is after", "şu tarihten sonra")
        case .beforeDate: return lang.t("is before", "şu tarihten önce")
        }
    }
}

public enum SizeUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case bytes = "B"
    case kb = "KB"
    case mb = "MB"
    case gb = "GB"

    public var id: String { rawValue }

    public var multiplier: Int64 {
        switch self {
        case .bytes: return 1
        case .kb: return 1_024
        case .mb: return 1_048_576
        case .gb: return 1_073_741_824
        }
    }
}

public enum TimeUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case minutes = "minutes"
    case hours = "hours"
    case days = "days"
    case weeks = "weeks"
    case months = "months"
    case years = "years"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .minutes: return lang.t("Minutes", "Dakika")
        case .hours: return lang.t("Hours", "Saat")
        case .days: return lang.t("Days", "Gün")
        case .weeks: return lang.t("Weeks", "Hafta")
        case .months: return lang.t("Months", "Ay")
        case .years: return lang.t("Years", "Yıl")
        }
    }

    public var secondsMultiplier: TimeInterval {
        switch self {
        case .minutes: return 60
        case .hours: return 3_600
        case .days: return 86_400
        case .weeks: return 604_800
        case .months: return 2_592_000
        case .years: return 31_536_000
        }
    }
}

public enum FileKindCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case any = "any"
    case file = "file"
    case folder = "folder"
    case package = "package"
    case application = "application"
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    case pdf = "pdf"
    case code = "code"
    case archive = "archive"
    case symlink = "symlink"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .any: return lang.t("Any Kind", "Tümü (Any)")
        case .file: return lang.t("Regular File", "Normal Dosya")
        case .folder: return lang.t("Folder", "Klasör")
        case .package: return lang.t("Package / Bundle", "Paket / Bundle")
        case .application: return lang.t("Application (.app)", "Uygulama (.app)")
        case .image: return lang.t("Image (PNG, JPG, HEIC, SVG...)", "Görsel (PNG, JPG, HEIC, SVG...)")
        case .video: return lang.t("Video (MP4, MOV, MKV...)", "Video (MP4, MOV, MKV...)")
        case .audio: return lang.t("Audio (MP3, WAV, M4A, FLAC...)", "Ses (MP3, WAV, M4A, FLAC...)")
        case .document: return lang.t("Document (PDF, Word, Pages, TXT...)", "Belge (PDF, Word, Pages, TXT...)")
        case .pdf: return lang.t("PDF Document (.pdf)", "PDF Belgesi (.pdf)")
        case .code: return lang.t("Source Code (Swift, JS, Py, JSON...)", "Kaynak Kod (Swift, JS, Py, JSON...)")
        case .archive: return lang.t("Archive (ZIP, RAR, TAR, DMG...)", "Arşiv (ZIP, RAR, TAR, DMG...)")
        case .symlink: return lang.t("Symlink / Alias", "Sembolik Bağ / Alias")
        }
    }

    public func shortTitle(in lang: AppLanguage) -> String {
        switch self {
        case .any: return lang.t("All", "Tümü")
        case .file: return lang.t("Files", "Dosya")
        case .folder: return lang.t("Folders", "Klasör")
        case .package: return lang.t("Packages", "Paket")
        case .application: return lang.t("Apps", "Uygulama")
        case .image: return lang.t("Images", "Görsel")
        case .video: return lang.t("Videos", "Video")
        case .audio: return lang.t("Audio", "Ses")
        case .document: return lang.t("Docs", "Belge")
        case .pdf: return "PDF"
        case .code: return lang.t("Code", "Kod")
        case .archive: return lang.t("Archives", "Arşiv")
        case .symlink: return lang.t("Links", "Link")
        }
    }

    public var iconName: String {
        switch self {
        case .any: return "sparkles"
        case .file: return "doc.fill"
        case .folder: return "folder.fill"
        case .package: return "shippingbox.fill"
        case .application: return "app.badge.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "waveform"
        case .document: return "doc.richtext.fill"
        case .pdf: return "doc.viewfinder.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .archive: return "archivebox.fill"
        case .symlink: return "link"
        }
    }

    private static let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "webp", "svg", "tiff", "tif", "bmp", "ico", "raw", "cr2", "nef", "psd", "ai"]
    private static let videoExts: Set<String> = ["mp4", "mov", "m4v", "mkv", "avi", "webm", "flv", "wmv", "mpeg", "mpg"]
    private static let audioExts: Set<String> = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "wma", "aiff", "alac"]
    private static let docExts: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "rtfd", "md", "csv", "odt"]
    private static let codeExts: Set<String> = ["swift", "py", "js", "ts", "jsx", "tsx", "html", "css", "scss", "json", "xml", "yaml", "yml", "c", "cpp", "h", "hpp", "rs", "go", "java", "kt", "rb", "php", "sh", "zsh", "sql", "toml", "plist"]
    private static let archiveExts: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "dmg", "iso", "pkg"]

    public func matches(ext: String, isDirectory: Bool, isPackage: Bool, isSymlink: Bool) -> Bool {
        let lowerExt = ext.lowercased()
        switch self {
        case .any:
            return true
        case .file:
            return !isDirectory && !isPackage
        case .folder:
            return isDirectory && !isPackage
        case .package:
            return isPackage
        case .application:
            return lowerExt == "app"
        case .image:
            return !isDirectory && Self.imageExts.contains(lowerExt)
        case .video:
            return !isDirectory && Self.videoExts.contains(lowerExt)
        case .audio:
            return !isDirectory && Self.audioExts.contains(lowerExt)
        case .document:
            return !isDirectory && Self.docExts.contains(lowerExt)
        case .pdf:
            return !isDirectory && lowerExt == "pdf"
        case .code:
            return !isDirectory && Self.codeExts.contains(lowerExt)
        case .archive:
            return !isDirectory && Self.archiveExts.contains(lowerExt)
        case .symlink:
            return isSymlink
        }
    }
}

public struct SearchRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var field: RuleField
    public var op: RuleOperator
    public var stringValue: String
    public var numberValue: Double
    public var sizeUnit: SizeUnit
    public var timeUnit: TimeUnit
    public var dateValue: Date
    public var kindValue: FileKindCategory

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        field: RuleField = .name,
        op: RuleOperator = .contains,
        stringValue: String = "",
        numberValue: Double = 10,
        sizeUnit: SizeUnit = .mb,
        timeUnit: TimeUnit = .days,
        dateValue: Date = Date().addingTimeInterval(-86400 * 7),
        kindValue: FileKindCategory = .any
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.field = field
        self.op = op
        self.stringValue = stringValue
        self.numberValue = numberValue
        self.sizeUnit = sizeUnit
        self.timeUnit = timeUnit
        self.dateValue = dateValue
        self.kindValue = kindValue
    }
}

// MARK: - Visibility Modes (FAF's 3-state Toolbar Options: Show All / Hide / Only)
public enum VisibilityFilterMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case showAll = "showAll"
    case hide = "hide"
    case exclusive = "exclusive"

    public var id: String { rawValue }

    public func shortTitle(in lang: AppLanguage) -> String {
        switch self {
        case .showAll: return lang.t("Show", "Göster")
        case .hide: return lang.t("Hide", "Gizle")
        case .exclusive: return lang.t("Only", "Sadece")
        }
    }

    public func fullDescription(in lang: AppLanguage) -> String {
        switch self {
        case .showAll: return lang.t("Show All (Include)", "Göster (Dahil Et)")
        case .hide: return lang.t("Hide (Exclude)", "Gizle (Hariç Tut)")
        case .exclusive: return lang.t("Show Only These", "Sadece Bunları Göster")
        }
    }
}

// MARK: - View & Sort Modes
public enum ResultsViewMode: String, CaseIterable, Identifiable, Sendable {
    case list = "list"
    case tree = "tree"
    case grid = "grid"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .list: return lang.t("List", "Liste")
        case .tree: return lang.t("Tree", "Ağaç")
        case .grid: return lang.t("Grid", "Izgara")
        }
    }

    public func fullTitle(in lang: AppLanguage) -> String {
        switch self {
        case .list: return lang.t("Flat List View", "Liste Görünümü")
        case .tree: return lang.t("Hierarchical Folder Tree", "Klasör Ağacı Görünümü")
        case .grid: return lang.t("Preview Grid View", "Önizleme Izgarası")
        }
    }

    public var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .tree: return "list.bullet.indent"
        case .grid: return "square.grid.3x3.fill"
        }
    }

    public var shortcutLabel: String {
        switch self {
        case .list: return "⌘1"
        case .tree: return "⌘2"
        case .grid: return "⌘3"
        }
    }
}

public enum SortColumn: String, CaseIterable, Identifiable, Sendable {
    case name = "name"
    case path = "path"
    case size = "size"
    case kind = "kind"
    case modifiedDate = "modifiedDate"
    case createdDate = "createdDate"

    public var id: String { rawValue }

    public func title(in lang: AppLanguage) -> String {
        switch self {
        case .name: return lang.t("Name", "Dosya Adı")
        case .path: return lang.t("Path (Location)", "Konum (Klasör Yolu)")
        case .size: return lang.t("Size", "Boyut")
        case .kind: return lang.t("Kind", "Tür")
        case .modifiedDate: return lang.t("Modified", "Değiştirilme")
        case .createdDate: return lang.t("Created", "Oluşturulma")
        }
    }
}

// MARK: - Found File Item
public struct FoundFileItem: Identifiable, Hashable, Sendable {
    public let id: String // Full file path
    public let name: String
    public let path: String
    public let parentPath: String
    public let fileExtension: String
    public let size: Int64
    public let modifiedDate: Date
    public let createdDate: Date
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isHidden: Bool
    public let isSymlink: Bool
    public let isTrashed: Bool
    public let isInsidePackage: Bool
    public let posixPermissions: Int

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public var formattedSize: String {
        if isDirectory && !isPackage && size == 0 {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var kindDescription: String {
        kindDescription(in: .en)
    }

    public func kindDescription(in lang: AppLanguage) -> String {
        if isApplication { return lang.t("Application", "Uygulama") }
        if isPackage { return lang.t("Package (Bundle)", "Paket (Bundle)") }
        if isDirectory { return lang.t("Folder", "Klasör") }
        if isSymlink { return lang.t("Symlink", "Sembolik Bağ") }
        if fileExtension.isEmpty { return lang.t("File", "Dosya") }
        return lang.t("\(fileExtension.uppercased()) File", "\(fileExtension.uppercased()) Dosyası")
    }

    public var isApplication: Bool {
        fileExtension.lowercased() == "app"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: FoundFileItem, rhs: FoundFileItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hierarchical Tree Node (FAF Signature Feature)
public struct FileTreeNode: Identifiable, Hashable, Sendable {
    public let id: String // Full path
    public let name: String
    public let path: String
    public let isDirectMatch: Bool // True = Bold/Highlighted, False = Dimmed/Cursive Enclosing Folder
    public let matchedItem: FoundFileItem?
    public let matchCountInSubtree: Int
    public var children: [FileTreeNode]?
}

// MARK: - Smart Presets & Saved Searches
public struct SearchPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var titleEN: String
    public var titleTR: String
    public var subtitleEN: String
    public var subtitleTR: String
    public var iconName: String
    public var accentHex: String
    public var target: SearchTargetType
    public var customPath: String
    public var quickQuery: String
    public var rules: [SearchRule]
    public var invisiblesMode: VisibilityFilterMode
    public var packageContentsMode: VisibilityFilterMode
    public var caseSensitive: Bool

    public func title(in lang: AppLanguage) -> String {
        lang == .en ? titleEN : titleTR
    }

    public func subtitle(in lang: AppLanguage) -> String {
        lang == .en ? subtitleEN : subtitleTR
    }

    public init(
        id: UUID = UUID(),
        titleEN: String,
        titleTR: String,
        subtitleEN: String,
        subtitleTR: String,
        iconName: String,
        accentHex: String = "#3B82F6",
        target: SearchTargetType = .home,
        customPath: String = "",
        quickQuery: String = "",
        rules: [SearchRule] = [],
        invisiblesMode: VisibilityFilterMode = .showAll,
        packageContentsMode: VisibilityFilterMode = .showAll,
        caseSensitive: Bool = false
    ) {
        self.id = id
        self.titleEN = titleEN
        self.titleTR = titleTR
        self.subtitleEN = subtitleEN
        self.subtitleTR = subtitleTR
        self.iconName = iconName
        self.accentHex = accentHex
        self.target = target
        self.customPath = customPath
        self.quickQuery = quickQuery
        self.rules = rules
        self.invisiblesMode = invisiblesMode
        self.packageContentsMode = packageContentsMode
        self.caseSensitive = caseSensitive
    }

    public static let builtInPresets: [SearchPreset] = [
        SearchPreset(
            titleEN: "Modified in Last 24h",
            titleTR: "Son 24 Saatte Değişenler",
            subtitleEN: "Recently installed or modified files",
            subtitleTR: "Yeni yüklenen veya değiştirilen dosyalar",
            iconName: "clock.badge.exclamationmark.fill",
            accentHex: "#10B981",
            target: .home,
            rules: [
                SearchRule(field: .modifiedDate, op: .inLast, numberValue: 24, timeUnit: .hours),
                SearchRule(field: .name, op: .doesNotContain, stringValue: ".DS_Store")
            ]
        ),
        SearchPreset(
            titleEN: "Large Files (> 100 MB)",
            titleTR: "Dev Dosyalar (> 100 MB)",
            subtitleEN: "Find biggest disk space consumers",
            subtitleTR: "Diskte en çok yer kaplayan dosyaları bul",
            iconName: "externaldrive.fill.badge.exclamationmark",
            accentHex: "#F59E0B",
            target: .home,
            rules: [
                SearchRule(field: .size, op: .greaterThan, numberValue: 100, sizeUnit: .mb),
                SearchRule(field: .kind, op: .equals, kindValue: .file)
            ]
        ),
        SearchPreset(
            titleEN: "App Leftovers (~/Library)",
            titleTR: "Uygulama Kalıntıları (Library)",
            subtitleEN: "Search support/cache files in ~/Library",
            subtitleTR: "Silinen uygulamaların ~/Library izleri",
            iconName: "trash.slash.fill",
            accentHex: "#EF4444",
            target: .userLibrary,
            rules: [
                SearchRule(field: .name, op: .contains, stringValue: "")
            ],
            invisiblesMode: .showAll,
            packageContentsMode: .hide
        ),
        SearchPreset(
            titleEN: "Hidden & Dot (.) Files",
            titleTR: "Gizli ve Nokta (.) Dosyaları",
            subtitleEN: "Config & system files Spotlight skips",
            subtitleTR: "Spotlight'ın gizlediği yapılandırma dosyaları",
            iconName: "eye.trianglebadge.exclamationmark.fill",
            accentHex: "#8B5CF6",
            target: .home,
            rules: [
                SearchRule(field: .name, op: .beginsWith, stringValue: ".")
            ],
            invisiblesMode: .exclusive
        ),
        SearchPreset(
            titleEN: "Images & Media Archive",
            titleTR: "Görsel ve Medya Arşivi",
            subtitleEN: "All photos, icons, and design assets",
            subtitleTR: "Tüm fotoğraf ve tasarım dosyaları",
            iconName: "photo.stack.fill",
            accentHex: "#EC4899",
            target: .home,
            rules: [
                SearchRule(field: .kind, op: .equals, kindValue: .image)
            ]
        ),
        SearchPreset(
            titleEN: "Source Code & Configs",
            titleTR: "Kaynak Kod ve Yapılandırma",
            subtitleEN: "Swift, JS, Python, JSON, Plist files",
            subtitleTR: "Swift, JS, Python, JSON, Plist dosyaları",
            iconName: "terminal.fill",
            accentHex: "#06B6D4",
            target: .home,
            rules: [
                SearchRule(field: .kind, op: .equals, kindValue: .code)
            ]
        )
    ]
}
