//
//  DownloadManager.swift
//  Sileo
//
//  Created by CoolStar on 8/2/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander

public enum DownloadManagerQueue: Int {
    case upgrades
    case installations
    case uninstallations
    case installdeps
    case uninstalldeps
    case none
}

final class DownloadManager {
    static let reloadNotification = Notification.Name("SileoDownloadManagerReloaded")
    static let lockStateChangeNotification = Notification.Name("SileoDownloadManagerLockStateChanged")
    static let aptQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "Sileo.AptQueue", qos: .userInitiated)
        queue.setSpecific(key: DownloadManager.queueKey, value: DownloadManager.queueContext)
        return queue
    }()
    public static let queueKey = DispatchSpecificKey<Int>()
    public static let queueContext = 50
    
    enum Error: LocalizedError {
        case hashMismatch(packageHash: String, refHash: String)
        case untrustedPackage(packageID: String)
        case debugNotAllowed
        
        public var errorDescription: String? {
            switch self {
            case let .hashMismatch(packageHash, refHash):
                return String(format: String(localizationKey: "Download_Hash_Mismatch", type: .error), packageHash, refHash)
            case let .untrustedPackage(packageID):
                return String(format: String(localizationKey: "Untrusted_Package", type: .error), packageID)
            case .debugNotAllowed:
                return "Packages cannot be added to the queue during install"
            }
        }
    }
    
    enum PackageHashType: String, CaseIterable {
        case sha256
        case sha512
        
        var hashType: HashType {
            switch self {
            case .sha256: return .sha256
            case .sha512: return .sha512
            }
        }
    }
    
    static let shared = DownloadManager()
    
    public var lockedForInstallation = false {
        didSet {
            NotificationCenter.default.post(name: DownloadManager.lockStateChangeNotification, object: nil)
        }
    }
    public var totalProgress = CGFloat(0)
    
    var upgrades: SafeContiguousArray<DownloadPackage> = SafeContiguousArray<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var installations: SafeContiguousArray<DownloadPackage> = SafeContiguousArray<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var uninstallations: SafeContiguousArray<DownloadPackage> = SafeContiguousArray<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var installdeps: SafeContiguousArray<DownloadPackage> = SafeContiguousArray<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var uninstalldeps: SafeContiguousArray<DownloadPackage> = SafeContiguousArray<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var errors: SafeContiguousArray<APTBrokenPackage> = SafeContiguousArray<APTBrokenPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    
    private var currentDownloads = 0
    public var queueStarted = false
    var downloads: [String: Download] = [:]
    var cachedFiles: [URL] = []
        
    var repoDownloadOverrideProviders: [String: Set<AnyHashable>] = [:]
    
    var viewController: DownloadsTableViewController
    
    init() {
        viewController = DownloadsTableViewController(nibName: "DownloadsTableViewController", bundle: nil)
    }
    
    public func installingPackages() -> Int {
        upgrades.count + installations.count + installdeps.count
    }
    
    public func uninstallingPackages() -> Int {
        uninstallations.count + uninstalldeps.count
    }
    
    public func operationCount() -> Int {
        upgrades.count + installations.count + uninstallations.count + installdeps.count + uninstalldeps.count
    }
        
    public func downloadingPackages() -> Int {
        var downloadsCount = 0
        for keyValue in downloads where keyValue.value.progress < 1 {
            downloadsCount += 1
        }
        return downloadsCount
    }
    
    public func readyPackages() -> Int {
        var readyCount = 0
        for keyValue in downloads {
            let download = keyValue.value
            if download.progress == 1 && download.success == true {
                readyCount += 1
            }
        }
        return readyCount
    }
    
    public func verifyComplete() -> Bool {
        let allRawDownloads = upgrades.raw + installations.raw + installdeps.raw
        for dlPackage in allRawDownloads {
            guard let download = downloads[dlPackage.package.packageID],
                  download.success else { return false }
        }
        return true
    }
    
    func startPackageDownload(download: Download) {
        let package = download.package
        var filename = package.filename ?? ""
        
        var packageRepo: Repo?
        for repo in RepoManager.shared.repoList where repo.rawEntry == package.sourceFile {
            packageRepo = repo
        }
        
        if package.package.contains("/") {
            filename = URL(fileURLWithPath: package.package).absoluteString
        } else if !filename.hasPrefix("https://") && !filename.hasPrefix("http://") {
            filename = URL(string: packageRepo?.rawURL ?? "")?.appendingPathComponent(filename).absoluteString ?? ""
        }
        
        // If it's a local file we can verify it immediately
        if self.verify(download: download) {
            download.progress = 1
            download.success = true
            download.completed = true
            Self.aptQueue.async { [self] in
                if self.verifyComplete() {
                    self.viewController.reloadControlsOnly()
                } else {
                    startMoreDownloads()
                }
            }
            return
        }
        
        download.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
            download.backgroundTask = nil
        })
        
        // See if theres an overriding web URL for downloading the package from
        currentDownloads += 1
        self.overrideDownloadURL(package: package, repo: packageRepo) { errorMessage, url in
            if url == nil && errorMessage != nil {
                self.currentDownloads -= 1
                download.failureReason = errorMessage
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: download.package)
                    TabBarController.singleton?.updatePopup()
                }
                return
            }
            let downloadURL = url ?? URL(string: filename)
            download.started = true
            download.failureReason = nil
            download.task = RepoManager.shared.queue(from: downloadURL, progress: { progress in
                download.message = nil
                download.progress = CGFloat(progress.fractionCompleted)
                download.totalBytesWritten = progress.total
                download.totalBytesExpectedToWrite = progress.expected
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: package)
                }
            }, success: { fileURL in
                self.currentDownloads -= 1
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes?[FileAttributeKey.size] as? Int
                let fileSizeStr = String(format: "%ld", fileSize ?? 0)
                download.message = nil
                if let backgroundTaskIdentifier = download.backgroundTask {
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
                download.backgroundTask = nil
                download.message = nil
                if !package.package.contains("/") && (fileSizeStr != package.size) {
                    download.failureReason = String(format: String(localizationKey: "Download_Size_Mismatch", type: .error),
                                                    package.size ?? "nil", fileSizeStr)
                    download.success = false
                    download.progress = 0
                } else {
                    do {
                        download.success = try self.verify(download: download, fileURL: fileURL)
                    } catch let error {
                        download.success = false
                        download.failureReason = error.localizedDescription
                    }
                    if download.success {
                        download.progress = 1
                    } else {
                        download.progress = 0
                    }
                    
                    #if TARGET_SANDBOX || targetEnvironment(simulator)
                    try? FileManager.default.removeItem(at: fileURL)
                    #endif
                    
                    Self.aptQueue.async { [self] in
                        if self.verifyComplete() {
                            DispatchQueue.main.async {
                                self.viewController.reloadDownload(package: download.package)
                                TabBarController.singleton?.updatePopup()
                                self.viewController.reloadControlsOnly()
                            }
                            
                        } else {
                            startMoreDownloads()
                        }
                    }
                    return
                }
                self.startMoreDownloads()
            }, failure: { statusCode, error in
                self.currentDownloads -= 1
                download.failureReason = error?.localizedDescription ?? String(format: String(localizationKey: "Download_Failing_Status_Code", type: .error), statusCode)
                download.message = nil
                if let backgroundTaskIdentifier = download.backgroundTask {
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
                download.backgroundTask = nil
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: download.package)
                    self.viewController.reloadControlsOnly()
                    TabBarController.singleton?.updatePopup()
                }
                self.startMoreDownloads()
            }, waiting: { message in
                download.message = message
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: package)
                }
            })
            download.task?.resume()
            
            self.viewController.reloadDownload(package: package)
        }
    }
    
    func startMoreDownloads() {
        DownloadManager.aptQueue.async { [self] in
            // We don't want more than one download at a time
            guard currentDownloads <= 3 else { return }
            // Get a list of downloads that need to take place
            let allRawDownloads = upgrades.raw + installations.raw + installdeps.raw
            for dlPackage in allRawDownloads {
                // Get the download object, we don't want to create multiple
                let download: Download
                let package = dlPackage.package
                if let tmp = downloads[package.packageID] {
                    download = tmp
                } else {
                    download = Download(package: package)
                    downloads[package.packageID] = download
                }
                
                // Means download has already started / completed
                if download.queued { continue }
                download.queued = true
                startPackageDownload(download: download)
                
                guard currentDownloads <= 3 else { break }
            }
        }
    }
 
    public func download(package: String) -> Download? {
        downloads[package]
    }
    
    private func aptEncoded(string: String, isArch: Bool) -> String {
        var encodedString = string.replacingOccurrences(of: "_", with: "%5f")
        encodedString = encodedString.replacingOccurrences(of: ":", with: "%3a")
        if isArch {
            encodedString = encodedString.replacingOccurrences(of: ".", with: "%2e")
        }
        return encodedString
    }
    
    private func verify(download: Download) -> Bool {
        let package = download.package
        
        let packageID = aptEncoded(string: package.packageID, isArch: false)
        let version = aptEncoded(string: package.version, isArch: false)
        let architecture = aptEncoded(string: package.architecture ?? "", isArch: true)
        
        let destFileName = "\(CommandPath.lazyPrefix)/var/cache/apt/archives/\(packageID)_\(version)_\(architecture).deb"
        let destURL = URL(fileURLWithPath: destFileName)
        
        if !FileManager.default.fileExists(atPath: destFileName) {
            if package.package.contains("/") {
                hardLinkAsRoot(from: URL(fileURLWithPath: package.package), to: URL(fileURLWithPath: destFileName))
                DownloadManager.shared.cachedFiles.append(URL(fileURLWithPath: package.package))
                return FileManager.default.fileExists(atPath: destFileName)
            }
            return false
        }
        
        let packageControl = package.rawControl
        
        if !package.package.contains("/") {
            let supportedHashTypes = PackageHashType.allCases.compactMap { type in packageControl[type.rawValue].map { (type, $0) } }
            let packageContainsHashes = !supportedHashTypes.isEmpty
            
            guard packageContainsHashes,
            let packageData = try? Data(contentsOf: destURL) else {
                return false
            }
            
            let packageIsValid = supportedHashTypes.allSatisfy {
                let hash = packageControl[$1]
                let refhash = packageData.hash(ofType: $0.hashType)
                
                return hash == refhash
            }
            guard packageIsValid else {
                return false
            }
        }
        
        return true
    }
    
    private func verify(download: Download, fileURL: URL) throws -> Bool {
        let package = download.package
        let packageControl = package.rawControl
        
        if !package.package.contains("/") {
            let supportedHashTypes = PackageHashType.allCases.compactMap { type in packageControl[type.rawValue].map { (type, $0) } }
            let packageContainsHashes = !supportedHashTypes.isEmpty
            
            guard packageContainsHashes else {
                throw Error.untrustedPackage(packageID: package.package)
            }
            
            let packageData = try Data(contentsOf: fileURL)
            
            var badHash = ""
            var badRefHash = ""
            
            let packageIsValid = supportedHashTypes.allSatisfy {
                let hash = $1
                let refhash = packageData.hash(ofType: $0.hashType)
                
                if hash != refhash {
                    badHash = hash
                    badRefHash = refhash
                    return false
                } else {
                    return true
                }
            }
            guard packageIsValid else {
                throw Error.hashMismatch(packageHash: badHash, refHash: badRefHash)
            }
        }
        
        #if !TARGET_SANDBOX && !targetEnvironment(simulator)
        let packageID = aptEncoded(string: package.packageID, isArch: false)
        let version = aptEncoded(string: package.version, isArch: false)
        let architecture = aptEncoded(string: package.architecture ?? "", isArch: true)
        
        let destFileName = "\(CommandPath.lazyPrefix)/var/cache/apt/archives/\(packageID)_\(version)_\(architecture).deb"
        let destURL = URL(fileURLWithPath: destFileName)
        
        hardLinkAsRoot(from: fileURL, to: destURL)
        #endif
        DownloadManager.shared.cachedFiles.append(fileURL)
        return true
    }
    
    private func recheckTotalOps() throws {
        if Thread.isMainThread {
            fatalError("This cannot be called from the main thread!")
        }
        
        // Clear any current depends
        installdeps.removeAll()
        uninstalldeps.removeAll()
        errors.removeAll()
        
        // Get a total of depends to be installed and break if empty
        let installationsAndUpgrades = self.installations.raw + self.upgrades.raw
        guard !(installationsAndUpgrades.isEmpty && uninstallations.isEmpty) else {
            return
        }
        let all = (installationsAndUpgrades + uninstallations.raw).map { $0.package }
        do {
            // Run the dep accelerator for any packages that have not already been cared about
            try DependencyResolverAccelerator.shared.getDependencies(packages: all)
        } catch {
            throw error
        }
        #if TARGET_SANDBOX || targetEnvironment(simulator)
        return
        #endif
        let aptOutput: APTOutput
        do {
            // Get the full list of packages to be installed and removed from apt
            aptOutput = try APTWrapper.operationList(installList: installationsAndUpgrades, removeList: uninstallations.raw)
        } catch {
            throw error
        }
        
        // Get every package to be uninstalled
        var uninstallIdentifiers = [String]()
        for operation in aptOutput.operations where operation.type == .remove {
            uninstallIdentifiers.append(operation.packageID)
        }
        
        var uninstallations = uninstallations.raw
        let rawUninstalls = PackageListManager.shared.packages(identifiers: uninstallIdentifiers, sorted: false, packages: Array(PackageListManager.shared.installedPackages.values))
        guard rawUninstalls.count == uninstallIdentifiers.count else {
            throw APTParserErrors.blankJsonOutput(error: "Uninstall Identifiers Mismatch")
        }
        var uninstallDeps: [DownloadPackage] = rawUninstalls.compactMap { DownloadPackage(package: $0) }
        
        // Get the list of packages to be installed, including depends
        var installIdentifiers = [String]()
        var installDepOperation = [String: [(String, String)]]()
        for operation in aptOutput.operations where operation.type == .install {
            installIdentifiers.append(operation.packageID)
            guard let release = operation.release?.split(separator: " "),
                  let host = release.first else { continue }
            if var hostArray = installDepOperation[String(host)] {
                hostArray.append((operation.packageID, operation.version))
                installDepOperation[String(host)] = hostArray
            } else {
                installDepOperation[String(host)] = [(operation.packageID, operation.version)]
            }
        }
        let installIndentifiersReference = installIdentifiers
        var rawInstalls = ContiguousArray<Package>()
        for (host, packages) in installDepOperation {
            if let repo = RepoManager.shared.repoList.first(where: { $0.url?.host == host }) {
                for package in packages {
                    if let repoPackage = repo.packageDict[package.0] {
                        if repoPackage.version == package.1 {
                            rawInstalls.append(repoPackage)
                            installIdentifiers.removeAll { $0 == package.0 }
                        } else if let version = repoPackage.getVersion(package.1) {
                            rawInstalls.append(version)
                            installIdentifiers.removeAll { $0 == package.0 }
                        }
                    }
                }
            } else if host == "local-deb" {
                let localPackages = PackageListManager.shared.localPackages
                for package in packages {
                    if let localPackage = localPackages[package.0] {
                        if localPackage.version == package.1 {
                            rawInstalls.append(localPackage)
                            installIdentifiers.removeAll { $0 == package.0 }
                        }
                    }
                }
            }
        }
        rawInstalls += PackageListManager.shared.packages(identifiers: installIdentifiers, sorted: false)
        guard rawInstalls.count == installIndentifiersReference.count else {
            throw APTParserErrors.blankJsonOutput(error: "Install Identifier Mismatch for Identifiers:\n \(installIdentifiers.map { "\($0)\n" })")
        }
        var installDeps = rawInstalls.compactMap { DownloadPackage(package: $0) }
        var installations = installations.raw
        var upgrades = upgrades.raw

        if aptOutput.conflicts.isEmpty {
            installations.removeAll { uninstallDeps.contains($0) }
            uninstallations.removeAll { installDeps.contains($0) }
            
            installations.removeAll { !installDeps.contains($0) }
            upgrades.removeAll { !installDeps.contains($0) }
            uninstallations.removeAll { !uninstallDeps.contains($0) }
            uninstallDeps.removeAll { uninstallations.contains($0) }
            installDeps.removeAll { installations.contains($0) }
            installDeps.removeAll { upgrades.contains($0) }
        }
  
        self.upgrades.setTo(upgrades)
        self.installations.setTo(installations)
        self.uninstallations.setTo(uninstallations)
        self.uninstalldeps.setTo(uninstallDeps)
        self.installdeps.setTo(installDeps)
        self.errors.setTo(aptOutput.conflicts)
    }
    
    private func checkInstalled() {
        let installedPackages = PackageListManager.shared.installedPackages.values
        for package in installedPackages {
            guard let newestPackage = PackageListManager.shared.newestPackage(identifier: package.package, repoContext: nil) else {
                continue
            }
            let downloadPackage = DownloadPackage(package: newestPackage)
            if package.eFlag == .reinstreq {
                if !installations.contains(downloadPackage) && !uninstallations.contains(downloadPackage) {
                    installations.append(downloadPackage)
                }
            } else if package.eFlag == .ok {
                if package.wantInfo == .deinstall || package.wantInfo == .purge || package.status == .halfconfigured {
                    if !installations.contains(downloadPackage) && !uninstallations.contains(downloadPackage) {
                        uninstallations.append(downloadPackage)
                    }
                }
            }
        }
    }
    
    public func cancelDownloads() {
        for download in downloads.values {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
        downloads.removeAll()
        currentDownloads = 0
    }
    
    public func removeAllItems() {
        upgrades.removeAll()
        installdeps.removeAll()
        installations.removeAll()
        uninstalldeps.removeAll()
        uninstallations.removeAll()
        errors.removeAll()
        for download in downloads.values {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
        downloads.removeAll()
        currentDownloads = 0
        self.checkInstalled()
    }
    
    public func reloadData(recheckPackages: Bool) {
        reloadData(recheckPackages: recheckPackages, completion: nil)
    }
    
    public func reloadData(recheckPackages: Bool, completion: (() -> Void)?) {
        DownloadManager.aptQueue.async { [self] in
            if recheckPackages {
                do {
                    try self.recheckTotalOps()
                } catch {
                    removeAllItems()
                    viewController.cancelDownload(nil)
                    TabBarController.singleton?.displayError(error.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                self.viewController.reloadData()
                TabBarController.singleton?.updatePopup(completion: completion)
                NotificationCenter.default.post(name: DownloadManager.reloadNotification, object: nil)
                completion?()
            }
        }
    }
    
    public func find(package: Package) -> DownloadManagerQueue {
        let downloadPackage = DownloadPackage(package: package)
        if installations.contains(downloadPackage) {
            return .installations
        } else if uninstallations.contains(downloadPackage) {
            return .uninstallations
        } else if upgrades.contains(downloadPackage) {
            return .upgrades
        } else if installdeps.contains(downloadPackage) {
            return .installdeps
        } else if uninstalldeps.contains(downloadPackage) {
            return .uninstalldeps
        }
        return .none
    }
    
    public func remove(package: String) {
        installations.removeAll { $0.package.package == package }
        upgrades.removeAll { $0.package.package == package }
        installdeps.removeAll { $0.package.package == package }
        uninstallations.removeAll { $0.package.package == package }
        uninstalldeps.removeAll { $0.package.package == package }
    }
    
    public func add(package: Package, queue: DownloadManagerQueue, approved: Bool = false) {
        let downloadPackage = DownloadPackage(package: package)
        let found = find(package: package)
        remove(downloadPackage: downloadPackage, queue: found)
    
        let package = downloadPackage.package.package
        switch queue {
        case .none:
            return
        case .installations:
            if !installations.map({ $0.package.package }).contains(package) {
                installations.append(downloadPackage)
            }
        case .uninstallations:
            if !uninstallations.map({ $0.package.package }).contains(package) {
                if approved == false && isEssential(downloadPackage.package) {
                    let message = String(format: String(localizationKey: "Essential_Warning"),
                                         "\n\(downloadPackage.package.name ?? downloadPackage.package.packageID)")
                    let alert = UIAlertController(title: String(localizationKey: "Warning"),
                                                  message: message,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .default, handler: { _ in
                        alert.dismiss(animated: true)
                    }))
                    alert.addAction(UIAlertAction(title: String(localizationKey: "Dangerous_Repo.Last_Chance.Continue"), style: .destructive, handler: { _ in
                        self.add(package: downloadPackage.package, queue: .uninstallations, approved: true)
                        self.reloadData(recheckPackages: true)
                    }))
                    TabBarController.singleton?.present(alert, animated: true)
                    return
                }
                uninstallations.append(downloadPackage)
            }
        case .upgrades:
            if !upgrades.map({ $0.package.package }).contains(package) {
                upgrades.append(downloadPackage)
            }
        case .installdeps:
            if !installdeps.map({ $0.package.package }).contains(package) {
                installdeps.append(downloadPackage)
            }
        case .uninstalldeps:
            if !uninstalldeps.map({ $0.package.package }).contains(package) {
                uninstalldeps.append(downloadPackage)
            }
        }
    }
  
    public func remove(package: Package, queue: DownloadManagerQueue) {
        let downloadPackage = DownloadPackage(package: package)
        remove(downloadPackage: downloadPackage, queue: queue)
    }
    
    public func remove(downloadPackage: DownloadPackage, queue: DownloadManagerQueue) {
        switch queue {
        case .none:
            return
        case .installations:
            installations.removeAll { $0 == downloadPackage }
        case .uninstallations:
            uninstallations.removeAll { $0 == downloadPackage }
        case .upgrades:
            upgrades.removeAll { $0 == downloadPackage }
        case .installdeps:
            installdeps.removeAll { $0 == downloadPackage }
        case .uninstalldeps:
            uninstalldeps.removeAll { $0 == downloadPackage }
        }
    }

    public func register(downloadOverrideProvider: DownloadOverrideProviding, repo: Repo) {
        if repoDownloadOverrideProviders[repo.repoURL] == nil {
            repoDownloadOverrideProviders[repo.repoURL] = Set()
        }
        repoDownloadOverrideProviders[repo.repoURL]?.insert(downloadOverrideProvider.hashableObject)
    }
    
    public func deregister(downloadOverrideProvider: DownloadOverrideProviding, repo: Repo) {
        repoDownloadOverrideProviders[repo.repoURL]?.remove(downloadOverrideProvider.hashableObject)
    }
    
    public func deregister(downloadOverrideProvider: DownloadOverrideProviding) {
        for keyVal in repoDownloadOverrideProviders {
            repoDownloadOverrideProviders[keyVal.key]?.remove(downloadOverrideProvider.hashableObject)
        }
    }
    
    private func overrideDownloadURL(package: Package, repo: Repo?, completionHandler: @escaping (String?, URL?) -> Void) {
        guard let repo = repo,
              let providers = repoDownloadOverrideProviders[repo.repoURL],
              !providers.isEmpty else {
            return completionHandler(nil, nil)
        }

        // The number of providers checked so far
        var checked = 0
        let total = providers.count
        for obj in providers {
            guard let downloadProvider = obj as? DownloadOverrideProviding else {
                continue
            }
            var willProvideURL = false
            willProvideURL = downloadProvider.downloadURL(for: package, from: repo, completionHandler: { errorMessage, url in
                // Ensure that this provider didn't say no and then try to call the completion handler
                if willProvideURL {
                    completionHandler(errorMessage, url)
                }
            })
            checked += 1
            if willProvideURL {
                break
            } else if checked >= total {
                // No providers offered an override URL for this download
                completionHandler(nil, nil)
            }
        }
    }
    
    public func repoRefresh() {
        if lockedForInstallation { return }
        let plm = PackageListManager.shared
        var reloadNeeded = false
        if operationCount() != 0 {
            reloadNeeded = true
            let savedUpgrades: [(String, String)] = upgrades.map({
                let pkg = $0.package
                return (pkg.packageID, pkg.version)
            })
            let savedInstalls: [(String, String)] = installations.map({
                let pkg = $0.package
                return (pkg.packageID, pkg.version)
            })
            
            upgrades.removeAll()
            installations.removeAll()
            installdeps.removeAll()
            uninstalldeps.removeAll()
            
            for tuple in savedUpgrades {
                let id = tuple.0
                let version = tuple.1
                
                if let pkg = plm.package(identifier: id, version: version) ?? plm.newestPackage(identifier: id, repoContext: nil) {
                    if find(package: pkg) == .none {
                        add(package: pkg, queue: .upgrades)
                    }
                }
            }
            
            for tuple in savedInstalls {
                let id = tuple.0
                let version = tuple.1
                
                if let pkg = plm.package(identifier: id, version: version) ?? plm.newestPackage(identifier: id, repoContext: nil) {
                    if find(package: pkg) == .none {
                        add(package: pkg, queue: .installations)
                    }
                }
            }
        }
        
        // Check for essential
        var allowedHosts = [String]()
        #if targetEnvironment(macCatalyst)
        allowedHosts = ["apt.procurs.us"]
        #else
        if RepoManager.shared.isMobileProcursus {
            allowedHosts = ["apt.procurs.us"]
        } else {
            allowedHosts = [
                "apt.bingner.com",
                "test.apt.bingner.com",
                "apt.elucubratus.com"
            ]
        }
        #endif
        let installedPackages = plm.installedPackages
        for repo in allowedHosts {
            if let repo = RepoManager.shared.repoList.first(where: { $0.url?.host == repo }) {
                for package in repo.packageArray where package.essential == "yes" &&
                                                            installedPackages[package.packageID] == nil &&
                                                            find(package: package) == .none {
                    reloadNeeded = true
                    add(package: package, queue: .installdeps)
                }
            }
        }
        // Don't bother to reloadData if there's nothing to reload, it's a waste of resources
        if reloadNeeded {
            reloadData(recheckPackages: true)
        }
    }
    
    public func isEssential(_ package: Package) -> Bool {
        // Check for essential
        var allowedHosts = [String]()
        #if targetEnvironment(macCatalyst)
        allowedHosts = ["apt.procurs.us"]
        #else
        if RepoManager.shared.isMobileProcursus {
            allowedHosts = ["apt.procurs.us"]
        } else {
            allowedHosts = [
                "apt.bingner.com",
                "test.apt.bingner.com",
                "apt.elucubratus.com"
            ]
        }
        #endif
        guard let sourceRepo = package.sourceRepo,
              allowedHosts.contains(sourceRepo.url?.host ?? "") else { return false }
        return package.essential == "yes"
    }
}
