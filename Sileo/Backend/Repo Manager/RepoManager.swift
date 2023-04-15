//
//  RepoManager.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit
import Evander

// swiftlint:disable:next type_body_length
final class RepoManager {

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
        parseSourcesFile(at: sourcesURL)
        #else
        fixLists()
        let directory = URL(fileURLWithPath: CommandPath.sourcesListD)
        let alternative = URL(fileURLWithPath: CommandPath.alternativeSources)
        for item in (directory.implicitContents + alternative.implicitContents)  {
            if item.pathExtension == "list" {
                parseListFile(at: item)
            } else if item.pathExtension == "sources" {
                parseSourcesFile(at: item)
            }
        }
        #endif
        if !UserDefaults.standard.bool(forKey: "Sileo.DefaultRepo") {
            UserDefaults.standard.set(true, forKey: "Sileo.DefaultRepo")
            addRepos(with: [
                URL(string: "https://havoc.app")!,
                URL(string: "https://repo.chariz.com")!
            ])
        }
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
                let arch = DpkgWrapper.architecture
                let suite = arch.primary == .rootless ? "" : "iphoneos-arm64/"
                let jailbreakRepo = Repo()
                jailbreakRepo.rawURL = "https://apt.procurs.us/"
                jailbreakRepo.suite = "\(suite)\(UIDevice.current.cfMajorVersion)"
                jailbreakRepo.components = ["main"]
                jailbreakRepo.rawEntry = """
                Types: deb
                URIs: https://apt.procurs.us/
                Suites: \(suite)\(UIDevice.current.cfMajorVersion)
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
        if Jailbreak.bootstrap == .procursus {
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
            PaymentManager.shared.removeProviders(for: repo)
            DependencyResolverAccelerator.shared.removeRepo(repo: repo)
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
            guard !hasRepo(with: URL(string: repoURL)!)
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
        let arch = DpkgWrapper.architecture
            .primary.rawValue
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
                    @discardableResult func image(for url: URL, scale: CGFloat) -> Bool {
                        let cache = EvanderNetworking.imageCache(url, scale: scale)
                        if let image = cache.1 {
                            DispatchQueue.main.async {
                                repo.repoIcon = image
                            }
                            if !cache.0 {
                                return true
                            }
                        }
                        if let iconData = try? Data(contentsOf: url) {
                            DispatchQueue.main.async {
                                repo.repoIcon = UIImage(data: iconData, scale: scale)
                                EvanderNetworking.saveCache(url, data: iconData)
                            }
                            return true
                        }
                        return false
                    }
                    if repo.url?.host == "apt.thebigboss.org" {
                        let url = StoreURL("deprecatedicons/BigBoss@\(Int(UIScreen.main.scale))x.png")!
                        image(for: url, scale: UIScreen.main.scale)
                    } else {
                        let scale = Int(UIScreen.main.scale)
                        var shouldBreak = false
                        for i in (1...scale).reversed() {
                            guard !shouldBreak else { continue }
                            let filename = i == 1 ? CommandPath.RepoIcon : "\(CommandPath.RepoIcon)@\(i)x"
                            if let iconURL = URL(string: repo.repoURL)?
                                .appendingPathComponent(filename)
                                .appendingPathExtension("png") {
                                shouldBreak = image(for: iconURL, scale: CGFloat(scale))
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
        progress: ((DownloadProgress) -> Void)?,
        success: @escaping (URL) -> Void,
        failure: @escaping (Int, Error?) -> Void,
        waiting: ((String) -> Void)? = nil
    ) -> EvanderDownloader? {
        guard let url = url else {
            failure(520, nil)
            return nil
        }

        let request = URLManager.urlRequest(url)
        guard let task = EvanderDownloader(request: request) else { return nil }
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
        progress: ((DownloadProgress) -> Void)?,
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
        
        let errorOutput = NSMutableAttributedString()
        func log(_ message: String, type: LogType) {
            errorOutput.append(NSAttributedString(
                string: "\(type): \(message)\n",
                attributes: [.foregroundColor: type.color])
            )
        }

        
        var reposUpdated = 0
        let dpkgArchitectures = DpkgWrapper.architecture
        let updateGroup = DispatchGroup()

        var backgroundIdentifier: UIBackgroundTaskIdentifier?
        backgroundIdentifier = UIApplication.shared.beginBackgroundTask {
            backgroundIdentifier.map(UIApplication.shared.endBackgroundTask)
            backgroundIdentifier = nil
        }

        var errorsFound = false
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

                            guard let repoArchs = (releaseDict["architectures"]?.components(separatedBy: " ") ?? releaseDict["architecture"].map { [$0] }) else {
                                log("Didn't find architectures \(dpkgArchitectures) in \(releaseURL)", type: .error)
                                errorsFound = true
                                return
                            }
                            if repoArchs.contains(dpkgArchitectures.primary.rawValue) {
                                preferredArch = dpkgArchitectures.primary.rawValue
                            } else {
                                for arch in repoArchs {
                                    if dpkgArchitectures.foreign.contains(where: { $0.rawValue == arch } ) {
                                        preferredArch = arch
                                        break
                                    }
                                }
                            }
                            
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
                    #if !targetEnvironment(simulator) && !TARGET_SANDBOX
                    let extensions = ["zst", "xz", "lzma", "bz2", "gz", ""]
                    #else
                    let extensions = ["xz", "lzma", "bz2", "gz", ""]
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
                                EvanderDownloadDelegate.shared.terminate(url)
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
                        let jsonPath = EvanderNetworking._cacheDirectory.appendingPathComponent("RepoHashCache").appendingPathExtension("json")
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
                        guard var packagesFile = optPackagesFile else {
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
                        let (shouldSkip, hash) = self.ignorePackages(repo: repo, packagesURL: packagesFile.url, type: succeededExtension, destinationPath: packagesFileDst, hashtype: hashToSave)
                        skipPackages = shouldSkip

                        func loadPackageData() {
                            if !skipPackages {
                                do {
                                    #if !targetEnvironment(simulator) && !TARGET_SANDBOX
                                    if succeededExtension == "zst" {
                                        let ret = ZSTD.decompress(path: packagesFile.url)
                                        switch ret {
                                        case .success(let url):
                                            packagesFile.url = url
                                        case .failure(let error):
                                            throw error
                                        }
                                        if let hash = hash {
                                            self.ignorePackage(repo: repo.repoURL, type: succeededExtension, hash: hash, hashtype: hashToSave)
                                        }
                                        return
                                    }

                                    if succeededExtension == "xz" || succeededExtension == "lzma" {
                                        let ret = XZ.decompress(path: packagesFile.url, type: succeededExtension == "xz" ? .xz : .lzma)
                                        switch ret {
                                        case .success(let url):
                                            packagesFile.url = url
                                        case .failure(let error):
                                            throw error
                                        }
                                        if let hash = hash {
                                            self.ignorePackage(repo: repo.repoURL, type: succeededExtension, hash: hash, hashtype: hashToSave)
                                        }
                                        return
                                    }
                                    #endif
                                    if succeededExtension == "bz2" {
                                        let ret = BZIP.decompress(path: packagesFile.url)
                                        switch ret {
                                        case .success(let url):
                                            packagesFile.url = url
                                        case .failure(let error):
                                            throw error
                                        }
                                    } else if succeededExtension == "gz" {
                                        let ret = GZIP.decompress(path: packagesFile.url)
                                        switch ret {
                                        case .success(let url):
                                            packagesFile.url = url
                                        case .failure(let error):
                                            throw error
                                        }
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
            
            if reposUpdated > 0 {
                DownloadManager.aptQueue.async {
                    DatabaseManager.shared.saveQueue()
                    DownloadManager.shared.repoRefresh()
                    DependencyResolverAccelerator.shared.preflightInstalled()
                    CanisterResolver.shared.queueCache()
                }
            }
            
            // This method can be safely called on a non-main thread.
            backgroundIdentifier.map(UIApplication.shared.endBackgroundTask)
            
            DispatchQueue.main.async {
                if reposUpdated > 0 {
                    NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                    NotificationCenter.default.post(name: NewsViewController.reloadNotification, object: nil)
                }
                completion(errorsFound, errorOutput)
            }
        }
    }

    private func ignorePackage(repo: String, type: String, hash: String, hashtype: RepoHashType) {
        guard let repo = URL(string: repo) else { return }
        let repoPath = repo.appendingPathComponent("Packages").appendingPathExtension(type)
        let jsonPath = EvanderNetworking._cacheDirectory.appendingPathComponent("RepoHashCache").appendingPathExtension("json")
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

    private func ignorePackages(repo: Repo, packagesURL: URL, type: String, destinationPath: URL, hashtype: RepoHashType) -> (Bool, String?) {
        guard !repo.packageDict.isEmpty,
              repo.packagesExist,
              let repo = URL(string: repo.repoURL),
              let hash = packagesURL.hash(ofType: hashtype.hashType) else { return (false, nil) }
        if !FileManager.default.fileExists(atPath: destinationPath.path) {
            return (false, hash)
        }
        let repoPath = repo.appendingPathComponent("Packages").appendingPathExtension(type)
        let jsonPath = EvanderNetworking._cacheDirectory.appendingPathComponent("RepoHashCache").appendingPathExtension("json")
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
        guard let refhash = url.hash(ofType: hashType.hashType) else { return false }

        let hashEntries = hashKey.components(separatedBy: "\n")

        return hashEntries.contains {
            var components = $0.components(separatedBy: " ")
            components.removeAll { $0.isEmpty }

            return components.count >= 3 &&
                   components[0] == refhash &&
                   components[2] == fileName
        }
    }
    
    public func parseListFile(at url: URL, isImporting: Bool = false) {
        // if we're importing, then it doesn't matter if the file is a cydia.list
        // otherwise, don't parse the file
        if Jailbreak.bootstrap == .procursus, !isImporting {
            guard url.lastPathComponent != "cydia.list" else {
                return
            }
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

    public func parsePlainTextFile(at url: URL) {
        guard let rawSources = try? String(contentsOf: url) else {
            return
        }
        let urlsString = rawSources.components(separatedBy: "\n").filter { URL(string: $0) != nil }

        parseRepoEntry(rawSources, at: url, withTypes: ["deb"], uris: urlsString, suites: ["./"], components: [])
    }
    
    public func parseSourcesFile(at url: URL) {
        guard let rawSources = try? String(contentsOf: url) else {
            NSLog("[Sileo] \(#function): couldn't get rawSources. we are out of here!")
            return
        }
        let repoEntries = rawSources.components(separatedBy: "\n\n")
        for repoEntry in repoEntries where !repoEntry.isEmpty {
            guard let repoData = try? ControlFileParser.dictionary(controlFile: repoEntry, isReleaseFile: false).0,
                  let rawTypes = repoData["types"],
                  let rawUris = repoData["uris"],
                  let rawSuites = repoData["suites"],
                  let rawComponents = repoData["components"]
            else {
                print("\(#function): Couldn't parse repo data for Entry \(repoEntry)")
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
        
        if Jailbreak.bootstrap != .elucubratus || Jailbreak.bootstrap != .unc0ver {
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
            do {
                try rawRepoList.write(to: sourcesURL, atomically: true, encoding: .utf8)
            } catch {
                print("Couldn't save with \(error)")
            }
            
            #else

            let sileoList = "\(CommandPath.prefix)/etc/apt/sources.list.d/sileo.sources"
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
