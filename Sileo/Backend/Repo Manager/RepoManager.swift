//
//  RepoManager.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation

// swiftlint:disable:next type_body_length
final class RepoManager {
    // This check is here because it's used in multiple places throughout the code
    #if targetEnvironment(simulator)
    public final let isMobileProcursus = true
    #else
    public final let isMobileProcursus = FileManager.default.fileExists(atPath: "\(CommandPath.prefix)/.procursus_strapped")
    #endif
    public final lazy var isProcursus: Bool = {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return isMobileProcursus
        #endif
    }()
    static let progressNotification = Notification.Name("SileoRepoManagerProgress")
    private var repoDatabase = DispatchQueue(label: "org.coolstar.SileoStore.repo-database")

    enum RepoHashType: String, CaseIterable {
        case sha256
        case sha512

        var hashType: HashType {
            switch self {
            case .sha256: return .sha256
            case .sha512: return .sha512
            }
        }
    }

    static let shared = RepoManager()

    private(set) var repoList: [Repo] = []
    private var repoListLock = DispatchSemaphore(value: 1)

    public func update(_ repo: Repo) {
        repoDatabase.async(flags: .barrier) {
            repo.releaseProgress = 0
            repo.packagesProgress = 0
            repo.releaseGPGProgress = 0
            repo.startedRefresh = false
        }
    }

    public func update(_ repos: [Repo]) {
        repoDatabase.sync(flags: .barrier) {
            for repo in repos {
                repo.releaseProgress = 0
                repo.packagesProgress = 0
                repo.releaseGPGProgress = 0
                repo.startedRefresh = false
            }
        }
    }

    // swiftlint:disable:next force_try
    lazy private var dataDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    #if targetEnvironment(simulator) || TARGET_SANDBOX
    private var sourcesURL: URL {
        FileManager.default.documentDirectory.appendingPathComponent("sileo.sources")
    }
    #endif

    init() {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let containerURL = FileManager.default.documentDirectory.deletingLastPathComponent()
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: containerURL.path) {
            for path in contents {
                if path.starts(with: "(A Document Being Saved By Sileo") {
                    let fullURL = containerURL.appendingPathComponent(path)
                    try? FileManager.default.removeItem(at: fullURL)
                }
            }
        }
        #else
        spawnAsRoot(args: [CommandPath.rm, "-rf", "/var/tmp/\\(A\\ Document\\ Being\\ Saved\\ By\\ Sileo*"])
        #endif

        #if targetEnvironment(simulator) || TARGET_SANDBOX
        repoListLock.wait()
        let jailbreakRepo = Repo()
        jailbreakRepo.rawURL = "https://apt.procurs.us/"
        jailbreakRepo.suite = "iphoneos-arm64/\(UIDevice.current.cfMajorVersion)"
        jailbreakRepo.components = ["main"]
        jailbreakRepo.rawEntry = """
        Types: deb
        URIs: https://apt.procurs.us/
        Suites: iphoneos-arm64/\(UIDevice.current.cfMajorVersion)
        Components: main
        """
        jailbreakRepo.entryFile = "\(CommandPath.sourcesListD)/procursus.sources"
        repoList.append(jailbreakRepo)
        repoListLock.signal()

        if sourcesURL.exists {
            parseSourcesFile(at: sourcesURL)
        } else {
            writeListToFile()
        }
        #else
        fixLists()
        let directory = URL(fileURLWithPath: CommandPath.sourcesListD)
        for item in directory.implicitContents {
            if item.pathExtension == "list" {
                parseListFile(at: item)
            } else if item.pathExtension == "sources" {
                parseSourcesFile(at: item)
            }
        }
        #endif
    }

    @discardableResult func addRepos(with urls: [URL]) -> [Repo] {
        var repos = [Repo]()
        func handleDistRepo(_ url: URL) -> Bool {
            let host = url.host?.lowercased()
            switch host {
            case "apt.bigboss.org", "apt.thebigboss.org", "thebigboss.org", "bigboss.org":
                let bigBoss = Repo()
                bigBoss.rawURL = "http://apt.thebigboss.org/repofiles/cydia/"
                bigBoss.suite = "stable"
                bigBoss.components = ["main"]
                bigBoss.rawEntry = """
                Types: deb
                URIs: http://apt.thebigboss.org/repofiles/cydia/
                Suites: stable
                Components: main
                """
                bigBoss.entryFile = "\(CommandPath.sourcesListD)/sileo.sources"
                repoList.append(bigBoss)
                repos.append(bigBoss)
                return true
            case "apt.procurs.us":
                let jailbreakRepo = Repo()
                jailbreakRepo.rawURL = "https://apt.procurs.us/"
                jailbreakRepo.suite = "iphoneos-arm64/\(UIDevice.current.cfMajorVersion)"
                jailbreakRepo.components = ["main"]
                jailbreakRepo.rawEntry = """
                Types: deb
                URIs: https://apt.procurs.us/
                Suites: iphoneos-arm64/\(UIDevice.current.cfMajorVersion)
                Components: main
                """
                jailbreakRepo.entryFile = "\(CommandPath.sourcesListD)/procursus.sources"
                repoList.append(jailbreakRepo)
                repos.append(jailbreakRepo)
                return true
            default: return false
            }
        }

        for url in urls {
            var normalizedStr = url.absoluteString
            if normalizedStr.last != "/" {
                normalizedStr.append("/")
            }
            guard let normalizedURL = URL(string: normalizedStr) else {
                continue
            }

            guard shouldAddRepo(normalizedURL) else { continue }
            repoListLock.wait()
            if !handleDistRepo(url) {
                let repo = Repo()
                repo.rawURL = normalizedStr
                repo.suite = "./"
                repo.rawEntry = """
                Types: deb
                URIs: \(repo.repoURL)
                Suites: ./
                Components:
                """
                repo.entryFile = "\(CommandPath.sourcesListD)/sileo.sources"
                repoList.append(repo)
                repos.append(repo)
            }
            repoListLock.signal()
        }
        writeListToFile()
        return repos
    }
    
    public func shouldAddRepo(_ url: URL) -> Bool {
        guard !hasRepo(with: url) else { return false }
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if isMobileProcursus {
            guard !(url.host?.localizedCaseInsensitiveContains("apt.bingner.com") ?? false),
                  !(url.host?.localizedCaseInsensitiveContains("test.apt.bingner.com") ?? false),
                  !(url.host?.localizedCaseInsensitiveContains("apt.elucubratus.com") ?? false) else { return false }
        } else {
            guard !(url.host?.localizedCaseInsensitiveContains("apt.procurs.us") ?? false) else { return false }
        }
        return true
        #endif
    }

    public func addDistRepo(url: URL, suites: String, components: String) -> Repo? {
        var normalizedStr = url.absoluteString
        if normalizedStr.last != "/" {
            normalizedStr.append("/")
        }
        guard let normalizedURL = URL(string: normalizedStr) else {
            return nil
        }
        
        guard shouldAddRepo(normalizedURL) else { return nil }

        repoListLock.wait()
        let repo = Repo()
        var suites = suites
        if suites.isEmpty {
            suites = "./"
        }
        repo.rawURL = normalizedStr
        repo.suite = suites
        repo.components = components.split(separator: " ") as? [String] ?? [components]
        repo.rawEntry = """
        Types: deb
        URIs: \(repo.rawURL)
        Suites: \(suites)
        Components: \(components)
        """
        repo.entryFile = "\(CommandPath.sourcesListD)/sileo.sources"
        repoList.append(repo)
        repoListLock.signal()
        writeListToFile()
        return repo
    }

    @discardableResult func addRepo(with url: URL) -> [Repo] {
        addRepos(with: [url])
    }

    func remove(repos: [Repo]) {
        repoListLock.wait()
        repoList.removeAll { repos.contains($0) }
        repoListLock.signal()
        writeListToFile()
        for repo in repos {
            DatabaseManager.shared.deleteRepo(repo: repo)
        }
        NotificationCenter.default.post(name: NewsViewController.reloadNotification, object: nil)
    }

    func remove(repo: Repo) {
        remove(repos: [repo])
    }

    func repo(with url: URL) -> Repo? {
        var normalizedStr = url.absoluteString.lowercased()
        if normalizedStr.last != "/" {
            normalizedStr.append("/")
        }
        normalizedStr = normalizedStr.replacingOccurrences(of: "https://", with: "")
        normalizedStr = normalizedStr.replacingOccurrences(of: "http://", with: "")
        return repoList.first(where: {
            var repoNormalizedStr = $0.rawURL.lowercased()
            if repoNormalizedStr.last != "/" {
                repoNormalizedStr.append("/")
            }
            repoNormalizedStr = repoNormalizedStr.replacingOccurrences(of: "https://", with: "")
            repoNormalizedStr = repoNormalizedStr.replacingOccurrences(of: "http://", with: "")
            return repoNormalizedStr == normalizedStr
        })
    }

    func repo(withSourceFile sourceFile: String) -> Repo? {
        repoList.first { $0.rawEntry == sourceFile }
    }

    func hasRepo(with url: URL) -> Bool {
        if url.host?.lowercased() == "apt.bigboss.org" ||
            url.host?.lowercased() == "bigboss.org" ||
            url.host?.lowercased() == "apt.thebigboss.org" ||
            url.host?.lowercased() == "thebigboss.org" {
            let repo = self.repo(with: URL(string: "http://apt.thebigboss.org/repofiles/cydia/")!)
            return repo != nil
        }
        if url.host?.lowercased() == "apt.procurs.us" {
            let repo = self.repo(with: URL(string: "https://apt.procurs.us/")!)
            return repo != nil
        }
        let repo = self.repo(with: url)
        return repo != nil
    }

    private func parseRepoEntry(_ repoEntry: String, at url: URL, withTypes types: [String], uris: [String], suites: [String], components: [String]?) {
        guard types.contains("deb") else {
            return
        }

        for repoURL in uris {
            guard !repoURL.localizedCaseInsensitiveContains("repo.chariz.io"),
                  !hasRepo(with: URL(string: repoURL)!)
            else {
                continue
            }

            let repos = suites.map { (suite: String) -> Repo in
                let repo = Repo()
                repo.rawEntry = repoEntry
                repo.rawURL = {
                    repoURL + (repoURL.last == "/" ? "" : "/")
                }()
                var suite = suite
                if suite.isEmpty {
                    suite = "./"
                }
                repo.suite = suite
                repo.components = components ?? []
                repo.entryFile = url.absoluteString
                return repo
            }

            repoListLock.wait()
            repoList += repos
            repoListLock.signal()
        }
    }

    var cachePrefix: URL {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let listsURL = FileManager.default.documentDirectory.appendingPathComponent("lists")
        if !listsURL.dirExists {
            try? FileManager.default.createDirectory(at: listsURL, withIntermediateDirectories: true)
        }
        return listsURL
        #else
        return URL(fileURLWithPath: CommandPath.lists)
        #endif
    }

    func cachePrefix(for repo: Repo) -> URL {
        var prefix = repo.repoURL
        prefix = String(prefix.drop(prefix: "https://"))
        prefix = String(prefix.drop(prefix: "http://"))
        if !prefix.hasSuffix("/") {
            prefix += "/"
        }
        if repo.isFlat {
            prefix += repo.suite
        }
        prefix = prefix.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "/", with: "_")
        return cachePrefix.appendingPathComponent(prefix)
    }

    func cacheFile(named name: String, for repo: Repo) -> URL {
        let arch = DpkgWrapper.getArchitectures.first ?? ""
        let prefix = cachePrefix(for: repo)
        if !repo.isFlat && name == "Packages" {
            return prefix
            .deletingLastPathComponent()
                .appendingPathComponent(prefix.lastPathComponent +
                    repo.components.joined(separator: "_") + "_"
                    + "binary-" + arch + "_"
                    + name)
        }
        return prefix
            .deletingLastPathComponent()
            .appendingPathComponent(prefix.lastPathComponent + name)
    }

    private func _checkUpdatesInBackground(_ repos: [Repo]) {
        let metadataUpdateGroup = DispatchGroup()
        for repo in repos {
            metadataUpdateGroup.enter()

            if !repo.isLoaded {
                let releaseFile = cacheFile(named: "Release", for: repo)
                if let info = releaseFile.aptContents,
                    let release = try? ControlFileParser.dictionary(controlFile: info, isReleaseFile: true).0,
                    let repoName = release["origin"] {
                    repo.repoName = repoName
                    let links = dataDetector.matches(
                        in: repo.repoName, range: NSRange(repoName.startIndex..<repoName.endIndex, in: repoName)
                    )
                    if !links.isEmpty {
                        repo.repoName = ""
                    }

                    repo.repoDescription = release["description"] ?? ""
                    repo.isLoaded = true
                }
            }

            if repo.isIconLoaded {
                metadataUpdateGroup.leave()
            } else {
                repo.isIconLoaded = true
                DispatchQueue.global().async {
                    if repo.url?.host == "apt.thebigboss.org" {
                        repo.repoIcon = UIImage(named: "BigBoss")
                        return
                    }
                    let scale = Int(UIScreen.main.scale)
                    for i in (1...scale).reversed() {
                        let filename = i == 1 ? CommandPath.RepoIcon : "\(CommandPath.RepoIcon)@\(i)x"
                        if let iconURL = URL(string: repo.repoURL)?
                            .appendingPathComponent(filename)
                            .appendingPathExtension("png") {
                            let cache = AmyNetworkResolver.shared.imageCache(iconURL, scale: CGFloat(i))
                            if let image = cache.1 {
                                DispatchQueue.main.async {
                                    repo.repoIcon = image
                                }
                                if !cache.0 {
                                    break
                                }
                            }
                            if let iconData = try? Data(contentsOf: iconURL) {
                                DispatchQueue.main.async {
                                    repo.repoIcon = UIImage(data: iconData, scale: CGFloat(i))
                                    AmyNetworkResolver.shared.saveCache(iconURL, data: iconData)
                                }
                                break
                            }
                        }
                    }
                    metadataUpdateGroup.leave()
                }
            }
        }
    }

    private func fixLists() {
        #if !targetEnvironment(simulator) && !TARGET_SANDBOX
        spawnAsRoot(args: [CommandPath.mkdir, "-p", CommandPath.lists])
        spawnAsRoot(args: [CommandPath.chown, "-R", "root:wheel", CommandPath.lists])
        spawnAsRoot(args: [CommandPath.chmod, "-R", "0755", CommandPath.lists])
        #endif
    }

    func checkUpdatesInBackground() {
        _checkUpdatesInBackground(repoList)
    }

    @discardableResult
    func queue(
        from url: URL?,
        progress: ((Progress) -> Void)?,
        success: @escaping (URL) -> Void,
        failure: @escaping (Int, Error?) -> Void,
        waiting: ((String) -> Void)? = nil
    ) -> AmyDownloadParser? {
        guard let url = url else {
            failure(520, nil)
            return nil
        }

        let request = URLManager.urlRequest(url)
        guard let task = AmyDownloadParser(request: request) else { return nil }
        task.progressCallback = { responseProgress in
            progress?(responseProgress)
        }
        task.errorCallback = { status, error, url in
            if let url = url {
                try? FileManager.default.removeItem(at: url)
            }
            failure(status, error)
        }
        task.didFinishCallback = { _, url in
            success(url)
        }
        task.waitingCallback = { message in
            waiting?(message)
        }
        task.make()
        return task
    }

    func fetch(
        from url: URL,
        withExtensionsUntilSuccess extensions: [String],
        progress: ((Progress) -> Void)?,
        success: @escaping (URL, URL) -> Void,
        failure: @escaping (Int, Error?) -> Void
    ) {
        guard !extensions.isEmpty else {
            failure(404, nil)
            return
        }
        let fullURL: URL
        if extensions[0] == "" {
            fullURL = url
        } else {
            fullURL = url.appendingPathExtension(extensions[0])
        }
        queue(
            from: fullURL,
            progress: progress,
            success: {
                success(fullURL, $0)
            },
            failure: { status, error in
                let newExtensions = Array(extensions.dropFirst())
                guard !newExtensions.isEmpty else { return failure(status, error) }
                self.fetch(from: url, withExtensionsUntilSuccess: newExtensions, progress: progress, success: success, failure: failure)
            }
        )?.resume()
    }

    private func repoRequiresUpdate(_ repo: Repo) -> Bool {
        PackageListManager.shared.initWait()
        let packagesFile = cacheFile(named: "Packages", for: repo)
        if !packagesFile.exists {
            return true
        }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: packagesFile.path),
              let modifiedDate = attributes[.modificationDate] as? Date
        else {
            return true
        }
        return Date().timeIntervalSince(modifiedDate) > 3 * 3600
    }

    public func postProgressNotification(_ repo: Repo?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: RepoManager.progressNotification, object: repo)
        }
    }

    // swiftlint:disable function_body_length
    private func _update (
        force: Bool,
        forceReload: Bool,
        isBackground: Bool,
        repos: [Repo],
        completion: @escaping (Bool, NSAttributedString) -> Void
    ) {
        var directory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: CommandPath.lists, isDirectory: &directory)
        if !exists ||  !directory.boolValue {
            fixLists()
        }
        var reposUpdated = 0
        let dpkgArchitectures = DpkgWrapper.getArchitectures
        let updateGroup = DispatchGroup()

        var backgroundIdentifier: UIBackgroundTaskIdentifier?
        backgroundIdentifier = UIApplication.shared.beginBackgroundTask {
            backgroundIdentifier.map(UIApplication.shared.endBackgroundTask)
            backgroundIdentifier = nil
        }

        var errorsFound = false
        let errorOutput = NSMutableAttributedString()
        var repos = repos
        let lock = NSLock()

        for threadID in 0..<(ProcessInfo.processInfo.processorCount * 2) {
            updateGroup.enter()
            let repoQueue = DispatchQueue(label: "repo-queue-\(threadID)")
            repoQueue.async {
                while true {
                    lock.lock()
                    guard !repos.isEmpty else {
                        lock.unlock()
                        break
                    }
                    let repo = repos.removeFirst()
                    lock.unlock()

                    repo.startedRefresh = true

                    if !force && !self.repoRequiresUpdate(repo) && !repo.packageDict.isEmpty {
                        if !repo.isLoaded {
                            repo.isLoaded = true
                            self.postProgressNotification(repo)
                        }
                        continue
                    }

                    let semaphore = DispatchSemaphore(value: 0)

                    enum LogType: CustomStringConvertible {
                        case error
                        case warning

                        var description: String {
                            switch self {
                            case .error:
                                return "Error"
                            case .warning:
                                return "Warning"
                            }
                        }

                        var color: UIColor {
                            switch self {
                            case .error:
                                return UIColor(red: 219/255, green: 44/255, blue: 56/255, alpha: 1)
                            case .warning:
                                return UIColor(red: 1, green: 231/255, blue: 146/255, alpha: 1)
                            }
                        }
                    }
                    func log(_ message: String, type: LogType) {
                        errorOutput.append(NSAttributedString(
                            string: "\(type): \(message)\n",
                            attributes: [.foregroundColor: type.color])
                        )
                    }

                    var preferredArch: String?
                    var optReleaseFile: (url: URL, dict: [String: String])?
                    var optPackagesFile: (url: URL, name: String)?
                    var releaseGPGFileURL: URL?

                    let releaseURL = URL(string: repo.repoURL)!.appendingPathComponent("Release")
                    let releaseTask = self.queue(
                        from: releaseURL,
                        progress: { progress in
                            repo.releaseProgress = CGFloat(progress.fractionCompleted)
                            self.postProgressNotification(repo)
                        },
                        success: { fileURL in
                            defer {
                                semaphore.signal()
                            }

                            guard let releaseContents = fileURL.aptContents else {
                                log("Could not parse release file from \(releaseURL)", type: .error)
                                errorsFound = true
                                return
                            }

                            let releaseDict: [String: String]
                            do {
                                releaseDict = try ControlFileParser.dictionary(controlFile: releaseContents, isReleaseFile: true).0
                            } catch {
                                log("Could not parse release file: \(error)", type: .error)
                                errorsFound = true
                                return
                            }

                            let repoArchs = releaseDict["architectures"]?.components(separatedBy: " ") ?? releaseDict["architecture"].map { [$0] }
                            preferredArch = repoArchs.flatMap { dpkgArchitectures.first(where: $0.contains) }

                            guard preferredArch != nil else {
                                log("Didn't find architectures \(dpkgArchitectures) in \(releaseURL)", type: .error)
                                errorsFound = true
                                return
                            }

                            guard ["components"].allSatisfy(releaseDict.keys.contains) else {
                                try? FileManager.default.removeItem(at: fileURL)
                                log("Could not parse release file.", type: .error)
                                errorsFound = true
                                return
                            }

                            optReleaseFile = (fileURL, releaseDict)

                            repo.releaseProgress = 1
                            self.postProgressNotification(repo)
                        },
                        failure: { status, error in
                            defer {
                                semaphore.signal()
                            }

                            log("\(releaseURL) returned status \(status). \(error?.localizedDescription ?? "")", type: .error)
                            errorsFound = true
                            repo.releaseProgress = 1
                            self.postProgressNotification(repo)
                        }
                    )
                    releaseTask?.resume()

                    let startTime = Date()
                    let refreshTimeout: TimeInterval = isBackground ? 10 : 20
                    if !repo.isFlat { // we have to wait for preferredArch to be determined
                        let refreshInterval: DispatchTime = .now() + refreshTimeout
                        if semaphore.wait(timeout: refreshInterval) != .success {
                            releaseTask?.cancel()
                        }
                    }

                    let packages: URL?
                    if repo.isFlat || preferredArch != nil {
                        packages = repo.packagesURL(arch: preferredArch)
                    } else {
                        packages = nil
                    }

                    var succeededExtension = ""
                    var extensions = ["bz2", "gz", ""]
                    #if !targetEnvironment(simulator) && !TARGET_SANDBOX
                    if ZSTD.available {
                        extensions.insert("zst", at: 0)
                    }
                    if XZ.available {
                        var buffer = 0
                        if extensions.count == 3 {
                            buffer = 1
                        }
                        extensions.insert("xz", at: 1 - buffer)
                        extensions.insert("lzma", at: 2 - buffer)
                    }
                    #endif
                    var breakOff = false
                    packages.map { url in self.fetch(
                        from: url,
                        withExtensionsUntilSuccess: extensions,
                        progress: { progress in
                            if !breakOff {
                                repo.packagesProgress = CGFloat(progress.fractionCompleted)
                                self.postProgressNotification(repo)
                            } else {
                                AmyDownloadParserDelegate.shared.terminate(url)
                            }
                        },
                        success: { succeededURL, fileURL in
                            defer {
                                if !breakOff {
                                    semaphore.signal()
                                }
                            }

                            if !breakOff {
                                succeededExtension = succeededURL.pathExtension

                                // to calculate the package file name, subtract the base URL from it. Ensure there's no leading /
                                let repoURL = repo.repoURL
                                let substringOffset = repoURL.hasSuffix("/") ? 0 : 1

                                let fileName = succeededURL.absoluteString.dropFirst(repoURL.count + substringOffset)
                                optPackagesFile = (fileURL, String(fileName))

                                repo.packagesProgress = 1
                                self.postProgressNotification(repo)
                            } else {
                                repo.packagesProgress = 0
                                repo.releaseProgress = 0
                                repo.releaseGPGProgress = 0
                                self.postProgressNotification(repo)
                            }
                        },
                        failure: { status, error in
                            defer {
                                semaphore.signal()
                            }
                            log("\(url) returned status \(status). \(error?.localizedDescription ?? "")", type: .error)
                            errorsFound = true
                            repo.packagesProgress = 1
                            self.postProgressNotification(repo)
                        }
                    )
                    }
                    let releaseGPGFileDst = self.cacheFile(named: "Release.gpg", for: repo)
                    let releaseGPGURL = URL(string: repo.repoURL)!.appendingPathComponent("Release.gpg")
                    let releaseGPGTask = self.queue(
                        from: releaseGPGURL,
                        progress: { progress in
                            repo.releaseGPGProgress = CGFloat(progress.fractionCompleted)
                            self.postProgressNotification(repo)
                        },
                        success: { fileURL in
                            defer {
                                semaphore.signal()
                            }
                            releaseGPGFileURL = fileURL
                            repo.releaseGPGProgress = 1
                            self.postProgressNotification(repo)
                        },
                        failure: { status, error in
                            defer {
                                semaphore.signal()
                            }

                            if FileManager.default.fileExists(atPath: releaseGPGFileDst.aptPath) {
                                log("\(releaseGPGURL) returned status \(status). \(error?.localizedDescription ?? "")", type: .error)
                                errorsFound = true
                            }
                            repo.releaseGPGProgress = 1
                            self.postProgressNotification(repo)
                        }
                    )
                    releaseGPGTask?.resume()

                    // if the repo is flat, then we didn't wait for Release earlier so wait now
                    let numReleaseWaits = repo.isFlat ? 2 : 1
                    var isReleaseGPGValid = false

                    func escapeEarly() {
                        #if targetEnvironment(macCatalyst)
                        guard isReleaseGPGValid else { return }
                        #endif
                        guard !breakOff,
                              !repo.packageDict.isEmpty,
                              repo.packagesExist,
                              optPackagesFile == nil,
                              let releaseFile = optReleaseFile else { return }
                        let supportedHashTypes = RepoHashType.allCases.compactMap { type in releaseFile.dict[type.rawValue].map { (type, $0) } }
                        guard !supportedHashTypes.isEmpty else { return }
                        let hashes: (RepoManager.RepoHashType, String)
                        if let tmp = supportedHashTypes.first(where: { $0.0 == RepoHashType.sha256 }) {
                            hashes = tmp
                        } else if let tmp = supportedHashTypes.first(where: { $0.0 == RepoHashType.sha512 }) {
                            hashes = tmp
                        } else { return }
                        let jsonPath = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("RepoHashCache").appendingPathExtension("json")
                        guard let url = URL(string: repo.repoURL),
                              let cachedData = try? Data(contentsOf: jsonPath),
                              let cacheTmp = (try? JSONSerialization.jsonObject(with: cachedData, options: .mutableContainers)) as? [String: [String: String]],
                              let cacheDict = cacheTmp[hashes.0.rawValue] else { return }
                        var hashDict = [String: String]()
                        let extensions = ["zst", "xz", "bz2", "gz", ""]
                        for ext in extensions {
                            if let hash = cacheDict[url.appendingPathComponent("Packages").appendingPathExtension(ext).absoluteString] {
                                hashDict[ext] = hash
                            }
                        }
                        if hashDict.isEmpty { return }

                        let repoHashStrings = hashes.1
                        let files = repoHashStrings.components(separatedBy: "\n")
                        for file in files {
                            var seperated = file.components(separatedBy: " ")
                            seperated.removeAll { $0.isEmpty }
                            if seperated.count != 3 { continue }
                            var file = seperated[2]
                            if file.contains("/") {
                                let tmp = file.components(separatedBy: "/")
                                guard let last = tmp.last else { continue }
                                file = last
                            }
                            if file.prefix(8) != "Packages" { continue }
                            var ext = ""
                            if file.contains(".") {
                                let tmp = file.components(separatedBy: ".")
                                guard let last = tmp.last else { continue }
                                ext = last
                            }
                            guard let key = hashDict[ext] else { continue }
                            if key == seperated[0] {
                                breakOff = true
                                repo.packagesProgress = 1
                                semaphore.signal()
                                return
                            }
                        }
                    }

                    escapeEarly()

                    if !breakOff {
                        if packages != nil {
                            let timeout = refreshTimeout - Date().timeIntervalSince(startTime)
                            _ = semaphore.wait(timeout: .now() + timeout) // Packages
                        }
                    }
                    for _ in 0..<numReleaseWaits {
                        let timeout = refreshTimeout - Date().timeIntervalSince(startTime)
                        _ = semaphore.wait(timeout: .now() + timeout)
                    }
                    releaseTask?.cancel()
                    releaseGPGTask?.cancel()
                    guard let releaseFile = optReleaseFile else {
                        log("Could not find release file for \(repo.repoURL)", type: .error)
                        errorsFound = true
                        reposUpdated += 1
                        self.checkUpdatesInBackground()
                        continue
                    }

                    if let releaseGPGFileURL = releaseGPGFileURL {
                        var error: String = ""
                        let validAndTrusted = APTWrapper.verifySignature(key: releaseGPGFileURL.aptPath, data: releaseFile.url.aptPath, error: &error)
                        if !validAndTrusted || !error.isEmpty {
                            if FileManager.default.fileExists(atPath: releaseGPGFileDst.aptPath) {
                                log("Invalid GPG signature at \(releaseGPGURL)", type: .error)
                                errorsFound = true
                                #if targetEnvironment(macCatalyst)
                                repo.packageDict = [:]
                                reposUpdated += 1
                                self.checkUpdatesInBackground()
                                continue
                                #endif
                            }
                        } else {
                            isReleaseGPGValid = true
                        }
                    }

                    #if targetEnvironment(macCatalyst)
                    if !isReleaseGPGValid {
                        repo.packageDict = [:]
                        errorsFound = true
                        log("\(repo.repoURL) had no valid GPG signature", type: .error)
                        reposUpdated += 1
                        self.checkUpdatesInBackground()
                        continue
                    }
                    #endif

                    let packagesFileDst = self.cacheFile(named: "Packages", for: repo)
                    var skipPackages = false
                    if !breakOff {
                        guard let packagesFile = optPackagesFile else {
                            log("Could not find packages file for \(repo.repoURL)", type: .error)
                            errorsFound = true
                            reposUpdated += 1
                            self.checkUpdatesInBackground()
                            continue
                        }

                        let supportedHashTypes = RepoHashType.allCases.compactMap { type in releaseFile.dict[type.rawValue].map { (type, $0) } }
                        let releaseFileContainsHashes = !supportedHashTypes.isEmpty
                        var isPackagesFileValid = supportedHashTypes.allSatisfy {
                            self.isHashValid(hashKey: $1, hashType: $0, url: packagesFile.url, fileName: packagesFile.name)
                        }
                        let hashToSave: RepoHashType = supportedHashTypes.contains(where: { $0.0.hashType == .sha512 })
                            ? .sha512 : .sha256
                        if releaseFileContainsHashes && !isPackagesFileValid {
                            log("Hash for \(packagesFile.name) from \(repo.repoURL) is invalid!", type: .error)
                            errorsFound = true
                        }

                        if let packagesData = try? Data(contentsOf: packagesFile.url) {
                            let (shouldSkip, hash) = self.ignorePackages(repo: repo, data: packagesData, type: succeededExtension, path: packagesFileDst, hashtype: hashToSave)
                            skipPackages = shouldSkip

                            func loadPackageData() {
                                if !skipPackages {
                                    do {
                                        #if !targetEnvironment(simulator) && !TARGET_SANDBOX
                                        if succeededExtension == "zst" {
                                            let (error, data) = ZSTD.decompress(path: packagesFile.url.path)
                                            if let data = data {
                                                try data.write(to: packagesFile.url, options: .atomic)
                                            } else {
                                                throw error ?? "Unknown Error"
                                            }
                                            if let hash = hash {
                                                self.ignorePackage(repo: repo.repoURL, type: succeededExtension, hash: hash, hashtype: hashToSave)
                                            }
                                            return
                                        }

                                        if succeededExtension == "xz" || succeededExtension == "lzma" {
                                            let (error, data) = XZ.decompress(path: packagesFile.url.path, type: succeededExtension == "xz" ? .xz : .lzma)
                                            if let data = data {
                                                try data.write(to: packagesFile.url, options: .atomic)
                                            } else {
                                                throw error ?? "Unknown Error"
                                            }
                                            if let hash = hash {
                                                self.ignorePackage(repo: repo.repoURL, type: succeededExtension, hash: hash, hashtype: hashToSave)
                                            }
                                            return
                                        }
                                        #endif
                                        if succeededExtension == "bz2" {
                                            let (error, data) = BZIP.decompress(path: packagesFile.url.path)
                                            if let data = data {
                                                try data.write(to: packagesFile.url, options: .atomic)
                                            } else {
                                                throw error ?? "Unknown Error"
                                            }
                                        } else if succeededExtension == "gz" {
                                            let (error, data) = GZIP.decompress(path: packagesFile.url.path)
                                            if let data = data {
                                                try data.write(to: packagesFile.url, options: .atomic)
                                            } else {
                                                throw error ?? "Unknown Error"
                                            }
                                        } else {
                                            try packagesData.write(to: packagesFile.url, options: .atomic)
                                        }
                                        if let hash = hash {
                                            self.ignorePackage(repo: repo.repoURL, type: succeededExtension, hash: hash, hashtype: hashToSave)
                                        }
                                    } catch {
                                        log("Could not decompress packages from \(repo.repoURL) (\(succeededExtension)): \(error.localizedDescription)", type: .error)
                                        isPackagesFileValid = false
                                        errorsFound = true
                                    }
                                }
                            }
                            loadPackageData()
                        }

                        if !skipPackages {
                            if !releaseFileContainsHashes || (releaseFileContainsHashes && isPackagesFileValid) {
                                let packageDict = repo.packageDict
                                repo.packageDict = PackageListManager.readPackages(repoContext: repo, packagesFile: packagesFile.url)
                                let databaseChanges = Array(repo.packageDict.values).filter { package -> Bool in
                                    if let tmp = packageDict[package.packageID] {
                                        if tmp.version == package.version {
                                            return false
                                        }
                                    }
                                    return true
                                }
                                DatabaseManager.shared.addToSaveQueue(packages: databaseChanges)
                                self.update(repo)
                            } else {
                                repo.packageDict = [:]
                                self.update(repo)
                            }
                            reposUpdated += 1
                        }

                        if !releaseFileContainsHashes || (releaseFileContainsHashes && isPackagesFileValid) {
                            if !skipPackages {
                                moveFileAsRoot(from: packagesFile.url, to: packagesFileDst)
                            }
                        } else if releaseFileContainsHashes && !isPackagesFileValid {
                            deleteFileAsRoot(packagesFileDst)
                        }
                        try? FileManager.default.removeItem(at: packagesFile.url.aptUrl)
                    }
                    if (skipPackages || breakOff) && FileManager.default.fileExists(atPath: packagesFileDst.path) {
                        let attributes = [FileAttributeKey.modificationDate: Date()]
                        try? FileManager.default.setAttributes(attributes, ofItemAtPath: packagesFileDst.path)
                    }
                    if FileManager.default.fileExists(atPath: releaseGPGFileDst.aptPath) && !isReleaseGPGValid {
                        reposUpdated += 1
                        self.checkUpdatesInBackground()
                        continue
                    }

                    let releaseFileDst = self.cacheFile(named: "Release", for: repo)
                    moveFileAsRoot(from: releaseFile.url, to: releaseFileDst)

                    if let releaseGPGFileURL = releaseGPGFileURL {
                        if isReleaseGPGValid {
                            moveFileAsRoot(from: releaseGPGFileURL, to: releaseGPGFileDst)
                        } else {
                            deleteFileAsRoot(releaseGPGFileDst)
                        }
                    }

                    try? FileManager.default.removeItem(at: releaseFile.url.aptUrl)
                    releaseGPGFileURL.map { try? FileManager.default.removeItem(at: $0) }

                    self.checkUpdatesInBackground()
                }

                updateGroup.leave()
            }
        }

        updateGroup.notify(queue: .main) {
            #if !targetEnvironment(macCatalyst)
            var files = self.cachePrefix.implicitContents

            var expectedFiles: [String] = []
            expectedFiles = self.repoList.flatMap { (repo: Repo) -> [String] in
                var names = [
                    "Release",
                    "Packages",
                    "Release.gpg"
                ]
                #if ENABLECACHINGBETA
                names.append("Packages.plist")
                #endif
                repo.releaseProgress = 0
                repo.packagesProgress = 0
                repo.releaseGPGProgress = 0
                repo.startedRefresh = false
                return names.map {
                    self.cacheFile(named: $0, for: repo).lastPathComponent
                }
            }
            expectedFiles.append("lock")
            expectedFiles.append("partial")

            files.removeAll { expectedFiles.contains($0.lastPathComponent) }
            files.forEach(deleteFileAsRoot)
            #endif
            self.postProgressNotification(nil)
            DatabaseManager.shared.saveQueue()

            DispatchQueue.main.async {
                if reposUpdated > 0 {
                    DownloadManager.aptQueue.async {
                        DownloadManager.shared.repoRefresh()
                        DependencyResolverAccelerator.shared.preflightInstalled()
                    }
                    NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                    NotificationCenter.default.post(name: NewsViewController.reloadNotification, object: nil)
                }
                backgroundIdentifier.map(UIApplication.shared.endBackgroundTask)
                NotificationCenter.default.post(name: CanisterResolver.RepoRefresh, object: nil)
                completion(errorsFound, errorOutput)
            }
        }
    }

    private func ignorePackage(repo: String, type: String, hash: String, hashtype: RepoHashType) {
        guard let repo = URL(string: repo) else { return }
        let repoPath = repo.appendingPathComponent("Packages").appendingPathExtension(type)
        let jsonPath = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("RepoHashCache").appendingPathExtension("json")
        var dict = [String: [String: String]]()
        if let cachedData = try? Data(contentsOf: jsonPath),
           let tmp = try? JSONSerialization.jsonObject(with: cachedData, options: .mutableContainers) as? [String: [String: String]] {
            dict = tmp
        }
        var hashDict = dict[hashtype.rawValue] ?? [:]
        hashDict[repoPath.absoluteString] = hash
        dict[hashtype.rawValue] = hashDict
        if let jsonData = try? JSONEncoder().encode(dict) {
            try? jsonData.write(to: jsonPath)
        }
    }

    private func ignorePackages(repo: Repo, data: Data?, type: String, path: URL, hashtype: RepoHashType) -> (Bool, String?) {
        guard let data = data,
              !repo.packageDict.isEmpty,
              repo.packagesExist,
              let repo = URL(string: repo.repoURL) else { return (false, nil) }
        let hash = data.hash(ofType: hashtype.hashType)
        if !FileManager.default.fileExists(atPath: path.path) {
            return (false, hash)
        }
        let repoPath = repo.appendingPathComponent("Packages").appendingPathExtension(type)
        let jsonPath = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("RepoHashCache").appendingPathExtension("json")
        let cachedData = try? Data(contentsOf: jsonPath)
        let dict = (try? JSONSerialization.jsonObject(with: cachedData ?? Data(), options: .mutableContainers) as? [String: [String: String]]) ?? [String: [String: String]]()
        let hashDict = dict[hashtype.rawValue] ?? [:]
        return ((hashDict[repoPath.absoluteString]) == hash, hash)
    }

    func update(force: Bool, forceReload: Bool, isBackground: Bool, repos: [Repo] = RepoManager.shared.repoList, completion: @escaping (Bool, NSAttributedString) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            PackageListManager.shared.initWait()
            DispatchQueue.main.async {
                self._update(force: force, forceReload: forceReload, isBackground: isBackground, repos: repos, completion: completion)
            }
        }
    }

    func isHashValid(hashKey: String, hashType: RepoHashType, url: URL, fileName: String) -> Bool {
        guard let packagesData = try? Data(contentsOf: url) else { return false }
        let refhash = packagesData.hash(ofType: hashType.hashType)

        let hashEntries = hashKey.components(separatedBy: "\n")

        return hashEntries.contains {
            var components = $0.components(separatedBy: " ")
            components.removeAll { $0.isEmpty }

            return components.count >= 3 &&
                   components[0] == refhash &&
                   components[1] == "\(packagesData.count)" &&
                   components[2] == fileName
        }
    }
    
    private func parseListFile(at url: URL) {
        if isMobileProcursus {
            guard url.lastPathComponent != "cydia.list" else { return }
        }
        guard let rawList = try? String(contentsOf: url) else { return }

        let repoEntries = rawList.components(separatedBy: "\n")
        for repoEntry in repoEntries {
            let parts = repoEntry.components(separatedBy: " ")
            guard parts.count >= 3 else {
                continue
            }

            let type = parts[0]
            let uri = parts[1]
            let suite = parts[2]
            let components = (parts.count > 3) ? Array(parts[3...]) : nil

            parseRepoEntry(repoEntry, at: url, withTypes: [type], uris: [uri], suites: [suite], components: components)
        }
    }

    private func parseSourcesFile(at url: URL) {
        guard let rawSources = try? String(contentsOf: url) else {
            return
        }
        let repoEntries = rawSources.components(separatedBy: "\n\n")

        for repoEntry in repoEntries {
            guard let repoData = try? ControlFileParser.dictionary(controlFile: repoEntry, isReleaseFile: false).0,
                  let rawTypes = repoData["types"],
                  let rawUris = repoData["uris"],
                  let rawSuites = repoData["suites"],
                  let rawComponents = repoData["components"]
            else {
                continue
            }

            let types = rawTypes.components(separatedBy: " ")
            let uris = rawUris.components(separatedBy: " ")
            let suites = rawSuites.components(separatedBy: " ")

            let allComponents = rawComponents.components(separatedBy: " ")
            let components: [String]?
            if allComponents.count == 1 && allComponents[0] == "" {
                components = nil
            } else {
                components = allComponents
            }

            parseRepoEntry(repoEntry, at: url, withTypes: types, uris: uris, suites: suites, components: components)
        }
    }

    func writeListToFile() {
        repoListLock.wait()
        
        if isProcursus {
            var rawRepoList = ""
            var added: Set<String> = []
            for repo in repoList {
                guard URL(fileURLWithPath: repo.entryFile).lastPathComponent == "sileo.sources",
                      !added.contains(repo.rawEntry)
                else {
                    continue
                }
                rawRepoList += "\(repo.rawEntry)\n\n"
                added.insert(repo.rawEntry)
            }

            #if targetEnvironment(simulator) || TARGET_SANDBOX

            try? rawRepoList.write(to: sourcesURL, atomically: true, encoding: .utf8)

            #else

            var sileoList = ""

            if FileManager.default.fileExists(atPath: "\(CommandPath.lazyPrefix)/etc/apt/sources.list.d/procursus.sources") ||
               FileManager.default.fileExists(atPath: "\(CommandPath.lazyPrefix)/etc/apt/sources.list.d/chimera.sources") ||
               FileManager.default.fileExists(atPath: "\(CommandPath.lazyPrefix)/etc/apt/sources.list.d/electra.list") {
                sileoList = "\(CommandPath.lazyPrefix)/etc/apt/sources.list.d/sileo.sources"
            } else {
                sileoList = "\(CommandPath.lazyPrefix)/etc/apt/sileo.list.d/sileo.sources"
            }
            
            let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                try rawRepoList.write(to: tempPath, atomically: true, encoding: .utf8)
            } catch {
                return
            }
            
            #if targetEnvironment(macCatalyst)
            spawnAsRoot(args: [CommandPath.cp, "-f", "\(tempPath.path)", "\(sileoList)"])
            #else
            spawnAsRoot(args: [CommandPath.cp, "--reflink=never", "-f", "\(tempPath.path)", "\(sileoList)"])
            #endif
            spawnAsRoot(args: [CommandPath.chmod, "0644", "\(sileoList)"])

            #endif
        } else {
            // > but if you wanted to, just edit the cydia file too and update cydia's prefs
            let defaults = UserDefaults(suiteName: "com.saurik.Cydia")
            var sourcesDict = [String: Any]()
            var rawRepoList = ""
            var added: Set<String> = []
            
            for repo in repoList {
                let rawEntry = "deb \(repo.rawURL) \(repo.suite) \(repo.components.first ?? "")"
                if added.contains(rawEntry) { continue }
                rawRepoList += "\(rawEntry)\n"
                added.insert(rawRepoList)
                let dict: [String: Any] = [
                    "Distribution": repo.suite,
                    "Type": "deb",
                    "Sections": repo.components,
                    "URI": repo.rawURL
                ]
                sourcesDict["deb:\(repo.rawURL):\(repo.suite)"] = dict
            }
            defaults?.setValue(sourcesDict, forKey: "CydiaSources")
            defaults?.synchronize()
            
            let cydiaList = URL(fileURLWithPath: "/var/mobile/Library/Caches/com.saurik.Cydia/sources.list")
            try? rawRepoList.write(to: cydiaList, atomically: true, encoding: .utf8)
        }
        
        repoListLock.signal()
    }
}
