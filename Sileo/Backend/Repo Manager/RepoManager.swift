//
//  RepoManager.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import SWCompression
import Alamofire

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
        spawnAsRoot(command: "rm -rf /var/tmp/\\(A\\ Document\\ Being\\ Saved\\ By\\ Sileo*")
        #endif
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let jailbreakRepoURL: String
        let jailbreakRepoSuites: String
        let jailbreakRepoComponents: [String]
        let jailbreakRepoRawEntry: String
        let jailbreakRepoEntryFile: String
        if kCFCoreFoundationVersionNumber >= 1600 {
            jailbreakRepoURL = "https://apt.procurs.us/"
            jailbreakRepoSuites = "iphoneos-arm64/1600"
            jailbreakRepoComponents = ["main"]
            jailbreakRepoRawEntry = """
            Types: deb
            URIs: https://apt.procurs.us/
            Suites: iphoneos-arm64/1600
            Components: main
            """
            jailbreakRepoEntryFile = "/etc/apt/sources.list.d/procursus.sources"
        } else {
            jailbreakRepoURL = "https://repo.chimera.sh/"
            jailbreakRepoSuites = "./"
            jailbreakRepoComponents = []
            jailbreakRepoRawEntry = """
            Types: deb
            URIs: https://repo.chimera.sh/
            Suites: ./
            Components:
            """
            jailbreakRepoEntryFile = "/etc/apt/sources.list.d/chimera.sources"
        }

        repoListLock.wait()
        let jailbreakRepo = Repo()
        jailbreakRepo.rawURL = jailbreakRepoURL
        jailbreakRepo.suite = jailbreakRepoSuites
        jailbreakRepo.components = jailbreakRepoComponents
        jailbreakRepo.rawEntry = jailbreakRepoRawEntry
        jailbreakRepo.entryFile = jailbreakRepoEntryFile
        repoList.append(jailbreakRepo)
        repoListLock.signal()

        if sourcesURL.exists {
            parseSourcesFile(at: sourcesURL)
        } else {
            addRepos(with: [
                "https://repo.chariz.com/",
                "https://repo.dynastic.co/",
                "https://repo.packix.com/",
                "https://repounclutter.coolstar.org/"
            ].compactMap(URL.init(string:)))

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
            bigBoss.entryFile = "/etc/apt/sources.list.d/sileo.sources"
            repoList.append(bigBoss)

            writeListToFile()
        }
        #else
        var sourcesDir: URL!
        if FileManager.default.fileExists(atPath: "/etc/apt/sources.list.d/procursus.sources") ||
            FileManager.default.fileExists(atPath: "/etc/apt/sources.list.d/chimera.sources") ||
            FileManager.default.fileExists(atPath: "/etc/apt/sources.list.d/electra.list") {
            sourcesDir = URL(string: "/etc/apt/sources.list.d") } else {
                sourcesDir = URL(string: "/etc/apt/sileo.list.d")
        }
        for file in sourcesDir.implicitContents {
            if file.pathExtension == "list" {
                parseListFile(at: file)
            } else {
                parseSourcesFile(at: file)
            }
        }
        #endif
    }

    func addRepos(with urls: [URL]) {
        for url in urls {
            guard !hasRepo(with: url),
                url.host?.localizedCaseInsensitiveContains("apt.bingner.com") == false,
                url.host?.localizedCaseInsensitiveContains("repo.chariz.io") == false else { continue }

            repoListLock.wait()
            let repo = Repo()
            repo.rawURL = url.absoluteString
            repo.suite = "./"
            repo.rawEntry = """
            Types: deb
            URIs: \(repo.repoURL)
            Suites: ./
            Components:
            """
            repo.entryFile = "/etc/apt/sources.list.d/sileo.sources"
            
            repoList.append(repo)
            repoListLock.signal()
        }
        writeListToFile()
    }

    func addRepo(with url: URL) {
        addRepos(with: [url])
    }

    func remove(_ repo: Repo) {
        repoListLock.wait()
        repoList.removeAll { $0 == repo }
        repoListLock.signal()
        writeListToFile()
    }

    func repo(with url: URL) -> Repo? {
        let urlStr = url.absoluteString
        return repoList.first { $0.repoURL == urlStr }
    }

    func repo(withSourceFile sourceFile: String) -> Repo? {
        repoList.first { $0.rawEntry == sourceFile }
    }

    func hasRepo(with url: URL) -> Bool {
        repo(with: url) != nil
    }

    private func parseRepoEntry(_ repoEntry: String, at url: URL, withTypes types: [String], uris: [String], suites: [String], components: [String]?) {
        // must have "deb" type
        guard types.contains("deb") else { return }

        for repoURL in uris {
            guard !repoURL.localizedCaseInsensitiveContains("apt.bingner.com") else {
                continue
            }
            guard !repoURL.localizedCaseInsensitiveContains("repo.chariz.io"),
                !hasRepo(with: URL(string: repoURL)!)
                else { continue }

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
        guard url.lastPathComponent != "cydia.list" else { return }
        guard let rawList = try? String(contentsOf: url) else { return }
        let repoEntries = rawList.components(separatedBy: "\n")
        for repoEntry in repoEntries {
            let parts = repoEntry.components(separatedBy: " ")
            guard parts.count >= 3 else { continue }

            let type = parts[0]
            let uri = parts[1]
            let suite = parts[2]

            let components: [String]?
            if parts.count > 3 {
                components = Array(parts[3...])
            } else {
                components = nil
            }

            parseRepoEntry(repoEntry, at: url, withTypes: [type], uris: [uri], suites: [suite], components: components)
        }
    }

    private func parseSourcesFile(at url: URL) {
        guard let rawSources = try? String(contentsOf: url) else { return }
        let repoEntries = rawSources.components(separatedBy: "\n\n")
        for repoEntry in repoEntries {
            guard let repoData = try? ControlFileParser.dictionary(controlFile: repoEntry, isReleaseFile: false).0,
                let rawTypes = repoData["types"],
                let rawUris = repoData["uris"],
                let rawSuites = repoData["suites"],
                let rawComponents = repoData["components"]
                else { continue }

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
        return URL(fileURLWithPath: "/var/lib/apt/lists")
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
        let prefix = cachePrefix(for: repo)
        if !repo.isFlat && name == "Packages" {
            return prefix
            .deletingLastPathComponent()
                .appendingPathComponent(prefix.lastPathComponent +
                    repo.components.joined(separator: "_") + "_"
                    + "binary-" + "iphoneos-arm" + "_"
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
                if let info = try? String(contentsOf: releaseFile),
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
                        let filename = i == 1 ? "CydiaIcon" : "CydiaIcon@\(i)x"

                        if let iconURL = URL(string: repo.repoURL)?
                            .appendingPathComponent(filename)
                            .appendingPathExtension("png"),
                            let iconData = try? Data(contentsOf: iconURL) {
                            DispatchQueue.main.async {
                                repo.repoIcon = UIImage(data: iconData, scale: CGFloat(i))
                            }
                            break
                        }
                    }
                    if repo.repoIcon == nil {
                        repo.repoIcon = UIImage(named: "Repo Icon")
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
        progress: ((CGFloat, Int64, Int64) -> Void)?,
        success: @escaping (URL) -> Void,
        failure: @escaping (Int) -> Void
    ) -> DownloadRequest? {
        guard let url = url else {
            failure(520)
            return nil
        }
        
        let request = URLManager.urlRequest(url)        
        let downloadTask = AF.download(request)
            .downloadProgress { progressData in
                progress?(CGFloat(progressData.fractionCompleted), progressData.completedUnitCount, progressData.totalUnitCount)
            }
            .response { response in
                guard let httpResponse = response.response else { failure(522); return }
                if httpResponse.statusCode == 200, response.error == nil,
                    let fileURL = response.fileURL {
                    success(fileURL)
                } else {
                    response.fileURL.map { try? FileManager.default.removeItem(at: $0) }
                    failure(httpResponse.statusCode)
                }
            }
        return downloadTask
    }

    func fetch(
        from url: URL,
        withExtensionsUntilSuccess extensions: [String],
        progress: ((CGFloat, Int64, Int64) -> Void)?,
        success: @escaping (URL, URL) -> Void,
        failure: @escaping (Int) -> Void
    ) {
        guard !extensions.isEmpty else { return failure(404) }
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
            failure: { status in
                let newExtensions = Array(extensions.dropFirst())
                guard !newExtensions.isEmpty else { return failure(status) }
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
            else { return true }
        return Date().timeIntervalSince(modifiedDate) > 3 * 3600
    }

    private func postProgressNotification(_ repo: Repo?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: RepoManager.progressNotification, object: repo)
        }
    }

    private func _update(
        force: Bool,
        forceReload: Bool,
        isBackground: Bool,
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

        var repos = repoList
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
                        progress: { progress, _, _ in
                            repo.releaseProgress = progress
                            self.postProgressNotification(repo)
                        },
                        success: { fileURL in
                            defer { semaphore.signal() }
                            guard let releaseContents = try? String(contentsOf: fileURL) else {
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
                        failure: { status in
                            defer { semaphore.signal() }

                            log("\(releaseURL) returned status \(status)", type: .error)
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
                    
                    let extensions = ["xz", "lzma", "bz2", "gz", ""]
                    packages.map { url in self.fetch(
                        from: url,
                        withExtensionsUntilSuccess: extensions,
                        progress: { progress, _, _ in
                            repo.packagesProgress = progress
                            self.postProgressNotification(repo)
                        },
                        success: { succeededURL, fileURL in
                            defer { semaphore.signal() }
                            
                            succeededExtension = succeededURL.pathExtension

                            // to calculate the package file name, subtract the base URL from it. Ensure there's no leading /
                            let repoURL = repo.repoURL
                            let substringOffset = repoURL.hasSuffix("/") ? 0 : 1

                            let fileName = succeededURL.absoluteString.dropFirst(repoURL.count + substringOffset)
                            optPackagesFile = (fileURL, String(fileName))

                            repo.packagesProgress = 1
                            self.postProgressNotification(repo)
                        },
                        failure: { status in
                            defer { semaphore.signal() }
                            log("\(url) returned status \(status)", type: .error)
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
                        progress: { progress, _, _ in
                            repo.releaseGPGProgress = progress
                            self.postProgressNotification(repo)
                        },
                        success: { fileURL in
                            defer { semaphore.signal() }
                            releaseGPGFileURL = fileURL
                            repo.releaseGPGProgress = 1
                            self.postProgressNotification(repo)
                        },
                        failure: { status in
                            defer { semaphore.signal() }
                            if FileManager.default.fileExists(atPath: releaseGPGFileDst.path) {
                                log("\(releaseGPGURL) returned status \(status)", type: .error)
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
                        let validAndTrusted = APTWrapper.verifySignature(key: releaseGPGFileURL.path, data: releaseFile.url.path, error: &error)
                        if !validAndTrusted || !error.isEmpty {
                            if FileManager.default.fileExists(atPath: releaseGPGFileDst.path) {
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

                    do {
                        let packagesData = try Data(contentsOf: packagesFile.url)
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
                    } catch {
                        log("Could not decompress packages from \(repo.repoURL) (\(succeededExtension)): \(error.localizedDescription)", type: .error)
                        isPackagesFileValid = false
                        errorsFound = true
                    }

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
                    
                    if FileManager.default.fileExists(atPath: releaseGPGFileDst.path) && !isReleaseGPGValid {
                        reposUpdated += 1
                        self.checkUpdatesInBackground(completion: nil)
                        continue
                    }

                    let releaseFileDst = self.cacheFile(named: "Release", for: repo)
                    copyFileAsRoot(from: releaseFile.url, to: releaseFileDst)

                    if let releaseGPGFileURL = releaseGPGFileURL {
                        if isReleaseGPGValid {
                            copyFileAsRoot(from: releaseGPGFileURL, to: releaseGPGFileDst)
                        } else {
                            deleteFileAsRoot(releaseGPGFileDst)
                        }
                    }

                    let packagesFileDst = self.cacheFile(named: "Packages", for: repo)
                    if !releaseFileContainsHashes || (releaseFileContainsHashes && isPackagesFileValid) {
                        copyFileAsRoot(from: packagesFile.url, to: packagesFileDst)
                    } else if releaseFileContainsHashes && !isPackagesFileValid {
                        deleteFileAsRoot(packagesFileDst)
                    }

                    try? FileManager.default.removeItem(at: releaseFile.url)
                    releaseGPGFileURL.map { try? FileManager.default.removeItem(at: $0) }
                    try? FileManager.default.removeItem(at: packagesFile.url)
                    
                    reposUpdated += 1
                    self.checkUpdatesInBackground(completion: nil)
                }

                updateGroup.leave()
            }
        }

        updateGroup.notify(queue: .main) {
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
                    completion(errorsFound, errorOutput)
                }
            }
        }
    }

    func update(force: Bool, forceReload: Bool, isBackground: Bool, completion: @escaping (Bool, NSAttributedString) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            PackageListManager.shared.waitForReady()
            DispatchQueue.main.async {
                self._update(force: force, forceReload: forceReload, isBackground: isBackground, completion: completion)
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
            return components.count >= 3
                && components[0] == refhash
                && components[1] == "\(packagesData.count)"
                && components[2] == fileName
        }
    }

    func writeListToFile() {
        repoListLock.wait()
        var rawRepoList = ""
        var added: Set<String> = []
        for repo in repoList {
            guard URL(fileURLWithPath: repo.entryFile).lastPathComponent == "sileo.sources",
                !added.contains(repo.rawEntry) else { continue }
            rawRepoList += "\(repo.rawEntry)\n\n"
            added.insert(repo.rawEntry)
        }
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        try? rawRepoList.write(to: sourcesURL, atomically: true, encoding: .utf8)
        #else
        var sileoList = ""
        if FileManager.default.fileExists(atPath: "/etc/apt/sources.list.d/procursus.sources") ||
            FileManager.default.fileExists(atPath: "/etc/apt/sources.list.d/chimera.sources") ||
            FileManager.default.fileExists(atPath: "/etc/apt/sources.list.d/electra.list") {
            sileoList = "/etc/apt/sources.list.d/sileo.sources" } else {
                sileoList = "/etc/apt/sileo.list.d/sileo.sources"
        }
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try rawRepoList.write(to: tempPath, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        spawnAsRoot(command: "cp -f '\(tempPath.path)' '\(sileoList)' && chmod 0644 '\(sileoList)'")
        #endif
        repoListLock.signal()
    }

}
