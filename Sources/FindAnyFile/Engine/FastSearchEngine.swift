import Foundation
import Darwin

public struct SearchConfiguration: Sendable {
    public let rootPaths: [String]
    public let quickQuery: String
    public let rules: [SearchRule]
    public let caseSensitive: Bool
    public let includeSpotlight: Bool
    public let excludedPaths: Set<String>
    public let maxResults: Int

    public init(
        rootPaths: [String],
        quickQuery: String,
        rules: [SearchRule],
        caseSensitive: Bool = false,
        includeSpotlight: Bool = true,
        excludedPaths: Set<String> = ["/System/Volumes/Data", "/dev", "/Volumes/Recovery", "/Volumes/Preboot", "/Volumes/VM"],
        maxResults: Int = 100_000
    ) {
        self.rootPaths = rootPaths
        self.quickQuery = quickQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rules = rules.filter { $0.isEnabled }
        self.caseSensitive = caseSensitive
        self.includeSpotlight = includeSpotlight
        self.excludedPaths = excludedPaths
        self.maxResults = maxResults
    }
}

public struct SearchProgressBatch: Sendable {
    public let newItems: [FoundFileItem]
    public let scannedCount: Int
    public let currentDirectory: String
}

public final class FastSearchEngine: Sendable {
    private static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "xcodeproj", "xcworkspace",
        "playground", "photoslibrary", "aplibrary", "fcpbundle", "rtfd", "pages", "numbers", "key"
    ]

    public init() {}

    /// Performs a blazing-fast hybrid multi-core POSIX `fts` + optional Spotlight search.
    public func search(
        config: SearchConfiguration,
        onBatch: @escaping @Sendable (SearchProgressBatch) -> Void
    ) async -> (totalScanned: Int, elapsedSeconds: Double) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let activeRules = compiledRules(from: config)
        let seenState = SeenPathsLockedState(maxResults: config.maxResults)

        // Expand top-level directories into shards so all CPU cores scan concurrently
        var shardPaths: [String] = []
        let fm = FileManager.default
        for root in config.rootPaths {
            if config.excludedPaths.contains(root) { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root, isDirectory: &isDir) else { continue }
            if !isDir.boolValue {
                shardPaths.append(root)
                continue
            }
            if let children = try? fm.contentsOfDirectory(atPath: root), children.count > 1 {
                for child in children {
                    let full = (root == "/") ? "/\(child)" : "\(root)/\(child)"
                    if !config.excludedPaths.contains(full) {
                        shardPaths.append(full)
                    }
                }
            } else {
                shardPaths.append(root)
            }
        }

        await withTaskGroup(of: Void.self) { group in
            // 1. Optional Spotlight Turbo acceleration for instant initial results
            if config.includeSpotlight && !config.quickQuery.isEmpty && activeRules.allSatisfy({ $0.rule.field != .content }) {
                group.addTask {
                    await self.runSpotlightTurbo(
                        config: config,
                        activeRules: activeRules,
                        seenState: seenState,
                        onBatch: onBatch
                    )
                }
            }

            // 2. Concurrent POSIX fts_open workers across shards
            let maxConcurrency = max(4, ProcessInfo.processInfo.activeProcessorCount)
            let chunkedShards = Self.distributeShards(shardPaths, bucketCount: maxConcurrency)

            for bucket in chunkedShards where !bucket.isEmpty {
                group.addTask {
                    self.scanShardBucket(
                        paths: bucket,
                        config: config,
                        activeRules: activeRules,
                        seenState: seenState,
                        onBatch: onBatch
                    )
                }
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (seenState.totalScanned, elapsed)
    }

    // MARK: - Root Mode (Elevated Privileges Search via Administrator Prompt)
    public func searchAsRoot(
        config: SearchConfiguration,
        onBatch: @escaping @Sendable (SearchProgressBatch) -> Void
    ) async throws -> (totalScanned: Int, elapsedSeconds: Double) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let activeRules = compiledRules(from: config)
        let seenState = SeenPathsLockedState(maxResults: config.maxResults)

        let targetPath = config.rootPaths.first ?? "/"
        let nameFilter = config.quickQuery.replacingOccurrences(of: "'", with: "'\\''")
        let findCmd: String
        if nameFilter.isEmpty {
            findCmd = "find '\(targetPath)' -xdev 2>/dev/null | head -n \(config.maxResults)"
        } else {
            findCmd = "find '\(targetPath)' -xdev -iname '*\(nameFilter)*' 2>/dev/null | head -n \(config.maxResults)"
        }

        let appleScript = "do shell script \"\(findCmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if let output = String(data: data, encoding: .utf8) {
            let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
            var batch: [FoundFileItem] = []
            var count = 0
            for lineSub in lines {
                if Task.isCancelled { break }
                let fullPath = String(lineSub)
                count += 1
                if let item = Self.evaluateSinglePath(fullPath, config: config, activeRules: activeRules) {
                    if seenState.insertIfNew(fullPath) {
                        batch.append(item)
                        if batch.count >= 200 {
                            let toSend = batch
                            batch.removeAll(keepingCapacity: true)
                            seenState.addScanned(200)
                            onBatch(SearchProgressBatch(newItems: toSend, scannedCount: seenState.totalScanned, currentDirectory: item.parentPath))
                        }
                    }
                }
            }
            if !batch.isEmpty {
                seenState.addScanned(count % 200)
                onBatch(SearchProgressBatch(newItems: batch, scannedCount: seenState.totalScanned, currentDirectory: targetPath))
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (seenState.totalScanned, elapsed)
    }

    // MARK: - POSIX FTS Scanner
    private func scanShardBucket(
        paths: [String],
        config: SearchConfiguration,
        activeRules: [CompiledRule],
        seenState: SeenPathsLockedState,
        onBatch: @escaping @Sendable (SearchProgressBatch) -> Void
    ) {
        let cPaths: [UnsafeMutablePointer<CChar>?] = paths.map { strdup($0) } + [nil]
        defer {
            for ptr in cPaths where ptr != nil {
                free(ptr)
            }
        }

        let flags = FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV
        guard let fts = cPaths.withUnsafeBufferPointer({ buf -> UnsafeMutablePointer<FTS>? in
            guard let base = buf.baseAddress else { return nil }
            return fts_open(base, flags, nil)
        }) else {
            return
        }
        defer { fts_close(fts) }

        var localBatch: [FoundFileItem] = []
        localBatch.reserveCapacity(128)
        var localScanned = 0
        var lastFlushTime = CFAbsoluteTimeGetCurrent()
        var currentDirPath = paths.first ?? ""

        let quickNeedles: [String] = config.quickQuery.isEmpty
            ? []
            : config.quickQuery
                .split(separator: " ")
                .map { config.caseSensitive ? String($0) : String($0).lowercased() }

        while !Task.isCancelled && !seenState.isLimitReached {
            guard let ent = fts_read(fts) else { break }
            let info = Int32(ent.pointee.fts_info)

            // Skip post-order directory visits, dot-dirs, or cyclical directories
            if info == FTS_DP || info == FTS_DC || info == FTS_DOT {
                continue
            }

            guard let pathPtr = ent.pointee.fts_path else { continue }
            let fullPath = String(cString: pathPtr)

            if info == FTS_D {
                if config.excludedPaths.contains(fullPath) {
                    fts_set(fts, ent, FTS_SKIP)
                    continue
                }
                currentDirPath = fullPath
            }

            localScanned += 1

            let name: String = withUnsafePointer(to: &ent.pointee.fts_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(ent.pointee.fts_namelen) + 1) { cStr in
                    String(cString: cStr)
                }
            }

            if name.isEmpty || name == "." || name == ".." {
                continue
            }

            // Fast path: check quick query needles before stat bridging
            if !quickNeedles.isEmpty {
                let candidateName = config.caseSensitive ? name : name.lowercased()
                var allMatched = true
                for needle in quickNeedles {
                    if !candidateName.contains(needle) {
                        allMatched = false
                        break
                    }
                }
                if !allMatched {
                    if localScanned >= 1500 {
                        let now = CFAbsoluteTimeGetCurrent()
                        if now - lastFlushTime > 0.08 {
                            seenState.addScanned(localScanned)
                            localScanned = 0
                            lastFlushTime = now
                            let itemsToSend = localBatch
                            localBatch.removeAll(keepingCapacity: true)
                            onBatch(SearchProgressBatch(
                                newItems: itemsToSend,
                                scannedCount: seenState.totalScanned,
                                currentDirectory: currentDirPath
                            ))
                        }
                    }
                    continue
                }
            }

            let isDir = (info == FTS_D || info == FTS_DOT)
            let isSymlink = (info == FTS_SL || info == FTS_SLNONE)

            var fileSize: Int64 = 0
            var modTime: TimeInterval = 0
            var createTime: TimeInterval = 0
            var posixMode: Int = 0

            if let statPtr = ent.pointee.fts_statp {
                fileSize = Int64(statPtr.pointee.st_size)
                modTime = TimeInterval(statPtr.pointee.st_mtimespec.tv_sec)
                createTime = TimeInterval(statPtr.pointee.st_birthtimespec.tv_sec)
                posixMode = Int(statPtr.pointee.st_mode & 0o777)
            }

            let ext = (name as NSString).pathExtension
            let isPackage = isDir && Self.packageExtensions.contains(ext.lowercased())

            // Check all active rules
            if !Self.matchesAllRules(
                activeRules,
                name: name,
                ext: ext,
                fullPath: fullPath,
                size: fileSize,
                modTime: modTime,
                createTime: createTime,
                isDir: isDir,
                isPackage: isPackage,
                isSymlink: isSymlink,
                caseSensitive: config.caseSensitive
            ) {
                if localScanned >= 1500 {
                    let now = CFAbsoluteTimeGetCurrent()
                    if now - lastFlushTime > 0.08 {
                        seenState.addScanned(localScanned)
                        localScanned = 0
                        lastFlushTime = now
                        let itemsToSend = localBatch
                        localBatch.removeAll(keepingCapacity: true)
                        onBatch(SearchProgressBatch(
                            newItems: itemsToSend,
                            scannedCount: seenState.totalScanned,
                            currentDirectory: currentDirPath
                        ))
                    }
                }
                continue
            }

            // Dedup with Spotlight / other workers
            guard seenState.insertIfNew(fullPath) else { continue }

            let parentPath = (fullPath as NSString).deletingLastPathComponent
            let isHidden = name.hasPrefix(".") || fullPath.contains("/.") || fullPath.hasPrefix("/private") || fullPath.hasPrefix("/usr")
            let isTrashed = fullPath.contains("/.Trash/") || fullPath.hasSuffix("/.Trash")
            let isInsidePackage = Self.checkIsInsidePackage(parentPath: parentPath)

            let foundItem = FoundFileItem(
                id: fullPath,
                name: name,
                path: fullPath,
                parentPath: parentPath,
                fileExtension: ext,
                size: fileSize,
                modifiedDate: Date(timeIntervalSince1970: modTime),
                createdDate: Date(timeIntervalSince1970: createTime),
                isDirectory: isDir,
                isPackage: isPackage,
                isHidden: isHidden,
                isSymlink: isSymlink,
                isTrashed: isTrashed,
                isInsidePackage: isInsidePackage,
                posixPermissions: posixMode
            )

            localBatch.append(foundItem)

            let now = CFAbsoluteTimeGetCurrent()
            if localBatch.count >= 64 || (now - lastFlushTime > 0.05 && !localBatch.isEmpty) {
                seenState.addScanned(localScanned)
                localScanned = 0
                lastFlushTime = now
                let itemsToSend = localBatch
                localBatch.removeAll(keepingCapacity: true)
                onBatch(SearchProgressBatch(
                    newItems: itemsToSend,
                    scannedCount: seenState.totalScanned,
                    currentDirectory: currentDirPath
                ))
            }
        }

        if localScanned > 0 || !localBatch.isEmpty {
            seenState.addScanned(localScanned)
            onBatch(SearchProgressBatch(
                newItems: localBatch,
                scannedCount: seenState.totalScanned,
                currentDirectory: currentDirPath
            ))
        }
    }

    // MARK: - Spotlight Turbo Helper
    private func runSpotlightTurbo(
        config: SearchConfiguration,
        activeRules: [CompiledRule],
        seenState: SeenPathsLockedState,
        onBatch: @escaping @Sendable (SearchProgressBatch) -> Void
    ) async {
        let escaped = config.quickQuery.replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        var args: [String] = []
        for root in config.rootPaths where root != "/" {
            args.append(contentsOf: ["-onlyin", root])
        }
        args.append("kMDItemFSName == '*\(escaped)*'cd")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard !Task.isCancelled, let text = String(data: data, encoding: .utf8) else { return }
        let paths = text.split(separator: "\n", omittingEmptySubsequences: true)
        var batch: [FoundFileItem] = []

        for line in paths.prefix(2000) {
            if Task.isCancelled || seenState.isLimitReached { break }
            let fullPath = String(line)
            if seenState.contains(fullPath) { continue }
            if let item = Self.evaluateSinglePath(fullPath, config: config, activeRules: activeRules) {
                if seenState.insertIfNew(fullPath) {
                    batch.append(item)
                    if batch.count >= 80 {
                        let toSend = batch
                        batch.removeAll(keepingCapacity: true)
                        onBatch(SearchProgressBatch(
                            newItems: toSend,
                            scannedCount: seenState.totalScanned,
                            currentDirectory: "Spotlight Hızlı İndeks"
                        ))
                    }
                }
            }
        }

        if !batch.isEmpty {
            onBatch(SearchProgressBatch(
                newItems: batch,
                scannedCount: seenState.totalScanned,
                currentDirectory: "Spotlight Hızlı İndeks"
            ))
        }
    }

    // MARK: - Rule Evaluation
    private struct CompiledRule: Sendable {
        let rule: SearchRule
        let lowercasedValue: String
        let splitValues: [String]
        let thresholdBytes: Int64
        let cutoffTimestamp: TimeInterval
    }

    private func compiledRules(from config: SearchConfiguration) -> [CompiledRule] {
        let now = Date().timeIntervalSince1970
        return config.rules.compactMap { rule -> CompiledRule? in
            // Ignore empty text rules
            switch rule.field {
            case .name, .nameWithoutExtension, .fileExtension, .fullPath, .content:
                let trimmed = rule.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }
            case .kind:
                if rule.kindValue == .any { return nil }
            default:
                break
            }

            let val = config.caseSensitive ? rule.stringValue : rule.stringValue.lowercased()
            let splits = val
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
                .filter { !$0.isEmpty }
            let bytes = Int64(rule.numberValue * Double(rule.sizeUnit.multiplier))
            let cutoff: TimeInterval
            if rule.op == .inLast {
                cutoff = now - (rule.numberValue * rule.timeUnit.secondsMultiplier)
            } else {
                cutoff = rule.dateValue.timeIntervalSince1970
            }

            return CompiledRule(
                rule: rule,
                lowercasedValue: val,
                splitValues: splits,
                thresholdBytes: bytes,
                cutoffTimestamp: cutoff
            )
        }
    }

    private static func matchesAllRules(
        _ rules: [CompiledRule],
        name: String,
        ext: String,
        fullPath: String,
        size: Int64,
        modTime: TimeInterval,
        createTime: TimeInterval,
        isDir: Bool,
        isPackage: Bool,
        isSymlink: Bool,
        caseSensitive: Bool
    ) -> Bool {
        for compiled in rules {
            let r = compiled.rule
            switch r.field {
            case .name:
                let target = caseSensitive ? name : name.lowercased()
                if !matchString(target, op: r.op, pattern: compiled.lowercasedValue, splits: compiled.splitValues, caseSensitive: caseSensitive) {
                    return false
                }
            case .nameWithoutExtension:
                let base = (name as NSString).deletingPathExtension
                let target = caseSensitive ? base : base.lowercased()
                if !matchString(target, op: r.op, pattern: compiled.lowercasedValue, splits: compiled.splitValues, caseSensitive: caseSensitive) {
                    return false
                }
            case .fileExtension:
                let cleanExt = caseSensitive ? ext : ext.lowercased()
                let cleanPattern = compiled.lowercasedValue.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                if !matchString(cleanExt, op: r.op, pattern: cleanPattern, splits: compiled.splitValues, caseSensitive: caseSensitive) {
                    return false
                }
            case .fullPath:
                let target = caseSensitive ? fullPath : fullPath.lowercased()
                if !matchString(target, op: r.op, pattern: compiled.lowercasedValue, splits: compiled.splitValues, caseSensitive: caseSensitive) {
                    return false
                }
            case .kind:
                let matchedKind = r.kindValue.matches(ext: ext, isDirectory: isDir, isPackage: isPackage, isSymlink: isSymlink)
                if r.op == .equals && !matchedKind { return false }
                if r.op == .isNot && matchedKind { return false }
            case .size:
                if isDir && !isPackage { return false }
                switch r.op {
                case .greaterThan:
                    if size <= compiled.thresholdBytes { return false }
                case .lessThan:
                    if size >= compiled.thresholdBytes { return false }
                case .equals:
                    if abs(size - compiled.thresholdBytes) > 1024 { return false }
                default:
                    break
                }
            case .modifiedDate:
                if !matchDate(modTime, op: r.op, cutoff: compiled.cutoffTimestamp) {
                    return false
                }
            case .createdDate:
                if !matchDate(createTime, op: r.op, cutoff: compiled.cutoffTimestamp) {
                    return false
                }
            case .content:
                if isDir || isSymlink || size == 0 || size > 35_000_000 {
                    return false
                }
                if !matchFileContent(atPath: fullPath, op: r.op, query: compiled.lowercasedValue, caseSensitive: caseSensitive) {
                    return false
                }
            }
        }
        return true
    }

    private static func matchString(
        _ target: String,
        op: RuleOperator,
        pattern: String,
        splits: [String],
        caseSensitive: Bool
    ) -> Bool {
        switch op {
        case .contains:
            return target.contains(pattern)
        case .beginsWith:
            return target.hasPrefix(pattern)
        case .endsWith:
            return target.hasSuffix(pattern)
        case .equals:
            return target == pattern
        case .isNot:
            return target != pattern
        case .doesNotContain:
            return !target.contains(pattern)
        case .isAnyOf:
            return splits.contains(where: { target == $0 || target.contains($0) })
        case .matchesRegex:
            let opts: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: opts) else { return false }
            let range = NSRange(target.startIndex..<target.endIndex, in: target)
            return regex.firstMatch(in: target, options: [], range: range) != nil
        default:
            return target.contains(pattern)
        }
    }

    private static func matchDate(_ timestamp: TimeInterval, op: RuleOperator, cutoff: TimeInterval) -> Bool {
        switch op {
        case .inLast, .afterDate:
            return timestamp >= cutoff
        case .beforeDate:
            return timestamp <= cutoff
        default:
            return true
        }
    }

    private static func matchFileContent(
        atPath path: String,
        op: RuleOperator,
        query: String,
        caseSensitive: Bool
    ) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), !data.isEmpty else {
            return false
        }
        // Quick binary check on first 512 bytes
        let checkCount = min(data.count, 512)
        if data.prefix(checkCount).contains(0) {
            return false
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return false
        }
        let haystack = caseSensitive ? text : text.lowercased()
        switch op {
        case .contains:
            return haystack.contains(query)
        case .doesNotContain:
            return !haystack.contains(query)
        case .matchesRegex:
            let opts: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: query, options: opts) else { return false }
            let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
            return regex.firstMatch(in: haystack, options: [], range: range) != nil
        default:
            return haystack.contains(query)
        }
    }

    private static func evaluateSinglePath(
        _ fullPath: String,
        config: SearchConfiguration,
        activeRules: [CompiledRule]
    ) -> FoundFileItem? {
        var st = stat()
        guard lstat(fullPath, &st) == 0 else { return nil }
        let name = (fullPath as NSString).lastPathComponent
        if !config.quickQuery.isEmpty {
            let candidate = config.caseSensitive ? name : name.lowercased()
            let needles = config.quickQuery.split(separator: " ").map { config.caseSensitive ? String($0) : String($0).lowercased() }
            if !needles.allSatisfy({ candidate.contains($0) }) {
                return nil
            }
        }
        let ext = (name as NSString).pathExtension
        let mode = st.st_mode & S_IFMT
        let isDir = (mode == S_IFDIR)
        let isSymlink = (mode == S_IFLNK)
        let isPackage = isDir && packageExtensions.contains(ext.lowercased())
        let size = Int64(st.st_size)
        let modTime = TimeInterval(st.st_mtimespec.tv_sec)
        let createTime = TimeInterval(st.st_birthtimespec.tv_sec)

        guard matchesAllRules(
            activeRules,
            name: name,
            ext: ext,
            fullPath: fullPath,
            size: size,
            modTime: modTime,
            createTime: createTime,
            isDir: isDir,
            isPackage: isPackage,
            isSymlink: isSymlink,
            caseSensitive: config.caseSensitive
        ) else {
            return nil
        }

        let parentPath = (fullPath as NSString).deletingLastPathComponent
        let isHidden = name.hasPrefix(".") || fullPath.contains("/.") || fullPath.hasPrefix("/private") || fullPath.hasPrefix("/usr")
        let isTrashed = fullPath.contains("/.Trash/") || fullPath.hasSuffix("/.Trash")
        let isInsidePackage = checkIsInsidePackage(parentPath: parentPath)

        return FoundFileItem(
            id: fullPath,
            name: name,
            path: fullPath,
            parentPath: parentPath,
            fileExtension: ext,
            size: size,
            modifiedDate: Date(timeIntervalSince1970: modTime),
            createdDate: Date(timeIntervalSince1970: createTime),
            isDirectory: isDir,
            isPackage: isPackage,
            isHidden: isHidden,
            isSymlink: isSymlink,
            isTrashed: isTrashed,
            isInsidePackage: isInsidePackage,
            posixPermissions: Int(st.st_mode & 0o777)
        )
    }

    private static func checkIsInsidePackage(parentPath: String) -> Bool {
        if parentPath.contains(".app/") || parentPath.hasSuffix(".app") ||
           parentPath.contains(".framework/") || parentPath.contains(".bundle/") ||
           parentPath.contains(".xcodeproj/") || parentPath.contains(".photoslibrary/") {
            return true
        }
        return false
    }

    private static func distributeShards(_ items: [String], bucketCount: Int) -> [[String]] {
        guard bucketCount > 0, !items.isEmpty else { return [] }
        var buckets = Array(repeating: [String](), count: min(bucketCount, items.count))
        for (idx, item) in items.enumerated() {
            buckets[idx % buckets.count].append(item)
        }
        return buckets
    }
}

// MARK: - Thread-Safe Deduplication & Counter State
private final class SeenPathsLockedState: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var seen: Set<String> = []
    private var scanned: Int = 0
    private let maxResults: Int

    init(maxResults: Int) {
        self.maxResults = maxResults
        self.seen.reserveCapacity(4096)
    }

    var isLimitReached: Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return seen.count >= maxResults
    }

    var totalScanned: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return scanned
    }

    func addScanned(_ delta: Int) {
        os_unfair_lock_lock(&lock)
        scanned += delta
        os_unfair_lock_unlock(&lock)
    }

    func contains(_ path: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return seen.contains(path)
    }

    func insertIfNew(_ path: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if seen.count >= maxResults { return false }
        let (inserted, _) = seen.insert(path)
        return inserted
    }
}

