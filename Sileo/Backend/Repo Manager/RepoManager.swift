//
//  RepoManager.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import SWCompression

final class RepoManager {
    static let progressNotification = Notification.Name("SileoRepoManagerProgress")
    
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
            var normalizedStr = url.absoluteString.lowercased()
            if normalizedStr.last != "/" {
                normalizedStr.append("/")
            }
            guard let normalizedURL = URL(string: normalizedStr) else {
                continue
            }
            
            guard !hasRepo(with: normalizedURL),
                  normalizedURL.host?.localizedCaseInsensitiveContains("apt.bingner.com") == false,
                  normalizedURL.host?.localizedCaseInsensitiveContains("repo.chariz.io") == false
            else {
                continue
            }
            
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
    
    @discardableResult func addRepo(with url: URL) -> [Repo] {
        addRepos(with: [url])
    }
    
    func remove(repos: [Repo]) {
        repoListLock.wait()
        repoList.removeAll { repos.contains($0) }
        repoListLock.signal()
        writeListToFile()
    }
    
    func remove(repo: Repo) {
        remove(repos: [repo])
    }
    
    func repo(with url: URL) -> Repo? {
        var normalizedStr = url.absoluteString
        if normalizedStr.last != "/" {
            normalizedStr.append("/")
        }
        return repoList.first(where: {
            var repoNormalizedStr = $0.rawURL.lowercased()
            if repoNormalizedStr.last != "/" {
                repoNormalizedStr.append("/")
            }
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
            guard !repoURL.localizedCaseInsensitiveContains("apt.bingner.com"),
                  !repoURL.localizedCaseInsensitiveContains("repo.chariz.io"),
                  !hasRepo(with: URL(string: repoURL)!)
            else {
                continue
            }
            
            let repos = suites.map { (suite: String) -> Repo in
                let repo = Repo()
                repo.rawEntry = repoEntry
                repo.rawURL = repoURL
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

    private func parseListFile(at url: URL) {
        guard url.lastPathComponent != "cydia.list",
              let rawList = try? String(contentsOf: url)
        else {
            return
        }
        
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
        let arch = DpkgWrapper.getArchitectures().first ?? ""
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
    
    private func _checkUpdatesInBackground(_ repos: [Repo], completion: (() -> Void)?) {
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
        
        metadataUpdateGroup.notify(queue: .main) {
            completion?()
        }
    }
    
    func checkUpdatesInBackground(completion: (() -> Void)?) {
        _checkUpdatesInBackground(repoList, completion: completion)
    }
    
    @discardableResult
    func queue(
        from url: URL?,
        progress: ((AmyDownloadParser.Progress) -> Void)?,
        success: @escaping (URL) -> Void,
        failure: @escaping (Int, Error?) -> Void,
        waiting: ((String) -> Void)? = nil
    ) -> AmyDownloadParser? {
        guard let url = url else {
            failure(520, nil)
            return nil
        }
        
        let request = URLManager.urlRequest(url)
        let task = AmyDownloadParser(request: request)
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
        progress: ((AmyDownloadParser.Progress) -> Void)?,
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
        PackageListManager.shared.waitForReady()
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
    
    private func _update (
        force: Bool,
        forceReload: Bool,
        isBackground: Bool,
        repos: [Repo],
        completion: @escaping (Bool, NSAttributedString) -> Void
    ) {
        var reposUpdated = 0
        let dpkgArchitectures = DpkgWrapper.getArchitectures()
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
                    
                    if !force && !self.repoRequiresUpdate(repo) {
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
                    #if targetEnvironment(simulator) || TARGET_SANDBOX
                    let extensions = ["xz", "lzma", "bz2", "gz", ""]
                    #else
                    var extensions = ["xz", "lzma", "bz2", "gz", ""]
                    if ZSTD.available && UserDefaults.standard.optionalBool("ExperimentalDecompression", fallback: true) {
                        extensions.insert("zst", at: 0)
                    }
                    #endif
                    packages.map { url in self.fetch(
                        from: url,
                        withExtensionsUntilSuccess: extensions,
                        progress: { progress in
                            repo.packagesProgress = CGFloat(progress.fractionCompleted)
                            self.postProgressNotification(repo)
                        },
                        success: { succeededURL, fileURL in
                            defer {
                                semaphore.signal()
                            }
                            
                            succeededExtension = succeededURL.pathExtension
                            
                            // to calculate the package file name, subtract the base URL from it. Ensure there's no leading /
                            let repoURL = repo.repoURL
                            let substringOffset = repoURL.hasSuffix("/") ? 0 : 1
                            
                            let fileName = succeededURL.absoluteString.dropFirst(repoURL.count + substringOffset)
                            optPackagesFile = (fileURL, String(fileName))
                            
                            repo.packagesProgress = 1
                            self.postProgressNotification(repo)
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
                    
                    if packages != nil {
                        let timeout = refreshTimeout - Date().timeIntervalSince(startTime)
                        _ = semaphore.wait(timeout: .now() + timeout) // Packages
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
                        self.checkUpdatesInBackground(completion: nil)
                        continue
                    }
                    guard let packagesFile = optPackagesFile else {
                        log("Could not find packages file for \(repo.repoURL)", type: .error)
                        errorsFound = true
                        reposUpdated += 1
                        self.checkUpdatesInBackground(completion: nil)
                        continue
                    }
                    
                    var isReleaseGPGValid = false
                    if let releaseGPGFileURL = releaseGPGFileURL {
                        var error: String = ""
                        let validAndTrusted = APTWrapper.verifySignature(key: releaseGPGFileURL.aptPath, data: releaseFile.url.aptPath, error: &error)
                        if !validAndTrusted || !error.isEmpty {
                            if FileManager.default.fileExists(atPath: releaseGPGFileDst.aptPath) {
                                log("Invalid GPG signature at \(releaseGPGURL)", type: .error)
                                errorsFound = true
                            }
                        } else {
                            isReleaseGPGValid = true
                        }
                    }
                    
                    let supportedHashTypes = RepoHashType.allCases.compactMap { type in releaseFile.dict[type.rawValue].map { (type, $0) } }
                    let releaseFileContainsHashes = !supportedHashTypes.isEmpty
                    var isPackagesFileValid = supportedHashTypes.allSatisfy {
                        self.isHashValid(hashKey: $1, hashType: $0, url: packagesFile.url, fileName: packagesFile.name)
                    }
                    
                    if releaseFileContainsHashes && !isPackagesFileValid {
                        log("Hash for \(packagesFile.name) from \(repo.repoURL) is invalid!", type: .error)
                        errorsFound = true
                    }
                    
                    let packagesFileDst = self.cacheFile(named: "Packages", for: repo)
                    var skipPackages = false
                    if let packagesData = try? Data(contentsOf: packagesFile.url) {
                        let (shouldSkip, hash) = self.ignorePackages(repo: repo, data: packagesData, type: succeededExtension, path: packagesFileDst)
                        skipPackages = shouldSkip
                        
                        func loadPackageData() {
                            if !skipPackages {
                                do {
                                    #if !targetEnvironment(simulator) || !TARGET_SANDBOX
                                    if succeededExtension == "zst" {
                                        let (error, data) = ZSTD.decompress(path: packagesFile.url.path)
                                        if let data = data {
                                            try data.write(to: packagesFile.url, options: .atomic)
                                        } else {
                                            throw error ?? "Unknown Error"
                                        }
                                        return
                                    }
                                    #endif
                                    if succeededExtension == "xz" {
                                        try XZArchive.unarchive(archive: packagesData).write(to: packagesFile.url, options: .atomic)
                                    } else if succeededExtension == "lzma" {
                                        try LZMA.decompress(data: packagesData).write(to: packagesFile.url, options: .atomic)
                                    } else if succeededExtension == "bz2" {
                                        try BZip2.decompress(data: packagesData).write(to: packagesFile.url, options: .atomic)
                                    } else if succeededExtension == "gz" {
                                        try GzipArchive.unarchive(archive: packagesData).write(to: packagesFile.url, options: .atomic)
                                    } else {
                                        try packagesData.write(to: packagesFile.url, options: .atomic)
                                    }
                                    if let hash = hash {
                                        self.ignorePackage(repo: repo.repoURL, type: succeededExtension, hash: hash)
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
                        do {
                            _ = try PackageListManager.shared.packagesList(loadIdentifier: "",
                                                                           repoContext: repo,
                                                                           useCache: false,
                                                                           overridePackagesFile: packagesFile.url,
                                                                           sortPackages: false,
                                                                           lookupTable: [:])
                        } catch {
                            log("Error parsing Packages from \(repo.repoURL): \(error.localizedDescription)", type: .error)
                            try? FileManager.default.removeItem(at: packagesFile.url)
                            isPackagesFileValid = false
                            errorsFound = true
                        }
                    }
                    
                    if FileManager.default.fileExists(atPath: releaseGPGFileDst.aptPath) && !isReleaseGPGValid {
                        reposUpdated += 1
                        self.checkUpdatesInBackground(completion: nil)
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
                    
                    if !releaseFileContainsHashes || (releaseFileContainsHashes && isPackagesFileValid) {
                        if !skipPackages {
                            moveFileAsRoot(from: packagesFile.url, to: packagesFileDst)
                        }
                    } else if releaseFileContainsHashes && !isPackagesFileValid {
                        deleteFileAsRoot(packagesFileDst)
                    }
                    
                    try? FileManager.default.removeItem(at: releaseFile.url.aptUrl)
                    releaseGPGFileURL.map { try? FileManager.default.removeItem(at: $0) }
                    try? FileManager.default.removeItem(at: packagesFile.url.aptUrl)
                    
                    reposUpdated += 1
                    self.checkUpdatesInBackground(completion: nil)
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
            
            DispatchQueue.global().async {
                if forceReload {
                    reposUpdated = 1
                }
                
                if reposUpdated > 0 {
                    PackageListManager.shared.purgeCache()
                    PackageListManager.shared.waitForReady()
                }
                
                DispatchQueue.main.async {
                    if reposUpdated > 0 {
                        NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                    }
                    backgroundIdentifier.map(UIApplication.shared.endBackgroundTask)
                    NotificationCenter.default.post(name: CanisterResolver.RepoRefresh, object: nil)
                    completion(errorsFound, errorOutput)
                }
            }
        }
    }
    
    private func ignorePackage(repo: String, type: String, hash: String) {
        guard let repo = URL(string: repo) else { return }
        let repoPath = repo.appendingPathComponent("Packages").appendingPathExtension(type)
        let jsonPath = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("RepoCache").appendingPathExtension("json")
        let cachedData = try? Data(contentsOf: jsonPath)
        var dict = (try? JSONSerialization.jsonObject(with: cachedData ?? Data(), options: .mutableContainers) as? [String: String]) ?? [String: String]()
        dict[repoPath.absoluteString] = hash
        if let jsonData = try? JSONEncoder().encode(dict) {
            try? jsonData.write(to: jsonPath)
        }
    }
    
    private func ignorePackages(repo: Repo, data: Data?, type: String, path: URL) -> (Bool, String?) {
        guard let data = data,
              !(repo.packages?.isEmpty ?? true),
              let repo = URL(string: repo.repoURL) else { return (false, nil) }
        let hash = data.hash(ofType: .sha256)
        if !FileManager.default.fileExists(atPath: path.path) {
            return (false, hash)
        }
        let repoPath = repo.appendingPathComponent("Packages").appendingPathExtension(type)
        let jsonPath = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("RepoCache").appendingPathExtension("json")
        let cachedData = try? Data(contentsOf: jsonPath)
        let dict = (try? JSONSerialization.jsonObject(with: cachedData ?? Data(), options: .mutableContainers) as? [String: String]) ?? [String: String]()
        return ((dict[repoPath.absoluteString]) == hash, hash)
    }
    
    func update(force: Bool, forceReload: Bool, isBackground: Bool, repos: [Repo] = RepoManager.shared.repoList, completion: @escaping (Bool, NSAttributedString) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            PackageListManager.shared.waitForReady()
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
    
    func writeListToFile() {
        repoListLock.wait()
        
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
        
        spawnAsRoot(args: [CommandPath.cp, "-f", "\(tempPath.path)", "\(sileoList)"])
        spawnAsRoot(args: [CommandPath.chmod, "0644", "\(sileoList)"])
        
        #endif
        
        repoListLock.signal()
    }
}
