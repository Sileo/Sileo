//
//  DownloadManager.swift
//  Sileo
//
//  Created by CoolStar on 8/2/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

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
    
    enum Error: LocalizedError {
        case hashMismatch(packageHash: String, refHash: String)
        case untrustedPackage(packageID: String)
        
        public var errorDescription: String? {
            switch self {
            case let .hashMismatch(packageHash, refHash):
                return String(format: String(localizationKey: "Download_Hash_Mismatch", type: .error), packageHash, refHash)
            case let .untrustedPackage(packageID):
                return String(format: String(localizationKey: "Untrusted_Package", type: .error), packageID)
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
    
    var upgrades: [DownloadPackage] = []
    var installations: [DownloadPackage] = []
    var uninstallations: [DownloadPackage] = []
    var installdeps: [DownloadPackage] = []
    var uninstalldeps: [DownloadPackage] = []
    var errors: [[String: Any]] = []
    
    var queued: [String: Download] = [:]
    var queuedRemovals: [String] = []
    var confirmedRemovals: [String] = []
    var downloads: [String: Download] = [:]
    
    private var queueLockCount = 0
    private var queueLock = DispatchSemaphore(value: 1)
    
    var repoDownloadOverrideProviders: [String: Set<AnyHashable>] = [:]
    
    var viewController: DownloadsTableViewController
    
    init() {
        viewController = DownloadsTableViewController(nibName: "DownloadsTableViewController", bundle: nil)
    }
    
    public func downloadingPackages() -> Int {
        var downloadsCount = 0
        for keyValue in downloads where keyValue.value.progress < 1 {
            downloadsCount += 1
        }
        return downloadsCount
    }
    
    public func queuedPackages() -> Int {
        queued.count + queuedRemovals.count
    }
    
    public func installingPackages() -> Int {
        upgrades.count + installations.count + installdeps.count
    }
    
    public func readyPackages() -> Int {
        var readyCount = 0
        for keyValue in downloads {
            let download = keyValue.value
            if download.progress == 1 && download.success == true {
                readyCount += 1
            }
        }
        readyCount += confirmedRemovals.count
        return readyCount
    }
    
    public func uninstallingPackages() -> Int {
        uninstallations.count + uninstalldeps.count
    }
    
    private func addDownloadItemsIfNotPresent() {
        self.lockQueue()
        defer { self.unlockQueue() }
        
        let allRawDownloads = upgrades + installations + installdeps
        var allPackageIDs: [String] = []
        
        for dlPackage in allRawDownloads {
            let packageID = dlPackage.package.package
            allPackageIDs.append(packageID)
            
            if queued[packageID] == nil && downloads[packageID] == nil {
                let download = Download(package: dlPackage.package)
                queued[packageID] = download
            }
        }
        
        for keyValue in queued {
            let packageID = keyValue.key
            if !allPackageIDs.contains(packageID) {
                queued.removeValue(forKey: packageID)
            }
        }
        
        for keyValue in downloads {
            let packageID = keyValue.key
            let download = keyValue.value
            if !allPackageIDs.contains(packageID) {
                if download.progress > 0 || download.progress < 1 {
                    download.task?.cancel()
                }
                downloads.removeValue(forKey: packageID)
            }
        }
        
        let allRawRemovals = uninstallations + uninstalldeps
        
        allPackageIDs.removeAll()
        
        for dlPackage in allRawRemovals {
            let packageID = dlPackage.package.package
            allPackageIDs.append(packageID)
            
            if !queuedRemovals.contains(packageID) && !confirmedRemovals.contains(packageID) {
                queuedRemovals.append(packageID)
            }
        }
        
        queuedRemovals.removeAll { !allPackageIDs.contains($0) }
        confirmedRemovals.removeAll { !allPackageIDs.contains($0) }
    }
    
    public func cancelUnqueuedDownloads() {
        self.lockQueue()
        defer {
            self.addBrokenPackages()
            self.unlockQueue()
        }
        
        for keyVal in queued {
            self.remove(package: keyVal.key)
        }
        queued.removeAll()
        
        for package in queuedRemovals {
            self.remove(package: package)
        }
        queuedRemovals.removeAll()
    }
    
    public func startUnqueuedDownloads() {
        self.lockQueue()
        defer {
            self.unlockQueue()
            self.startMoreDownloads()
        }
        
        let allRawDownloads = upgrades + installations + installdeps
        
        for dlPackage in allRawDownloads {
            let package = dlPackage.package
            queued.removeValue(forKey: package.package)
            
            if downloads[package.package] == nil {
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
                
                let download = Download(package: package)
                download.failureReason = ""
                if self.verify(download: download) {
                    download.progress = 1
                    download.success = true
                    download.queued = false
                    download.completed = true
                } else {                    
                    self.overrideDownloadURL(package: package, repo: packageRepo) { errorMessage, url in
                        if url == nil && errorMessage != nil {
                            download.failureReason = errorMessage
                            download.success = false
                            download.progress = 0
                            download.queued = false
                            download.completed = true
                            // this hurts :(
                            DispatchQueue.main.async {
                                self.viewController.reloadDownload(package: download.package)
                                TabBarController.singleton?.updatePopup()
                            }
                            return
                        }
                        
                        let downloadURL = url ?? URL(string: filename)
                        download.task = RepoManager.shared.queue(from: downloadURL,
                                                                 progress: { progress, completedUnitCount, totalUnitCount in
                                                                    download.progress = progress
                                                                    download.totalBytesWritten = completedUnitCount
                                                                    download.totalBytesExpectedToWrite = totalUnitCount
                                                                    DispatchQueue.main.async {
                                                                        self.viewController.reloadDownload(package: package)
                                                                    }
                        }, success: { fileURL in
                            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                            let fileSize = attributes?[FileAttributeKey.size] as? Int
                            let fileSizeStr = String(format: "%ld", fileSize ?? 0)
                            download.completed = true
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
                                
                                DispatchQueue.main.async {
                                    self.viewController.reloadDownload(package: download.package)
                                    self.viewController.reloadControlsOnly()
                                    TabBarController.singleton?.updatePopup()
                                }
                            }
                            if let backgroundTaskIdentifier = download.backgroundTask {
                                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                            }
                            download.backgroundTask = nil
                            self.startMoreDownloads()
                        }, failure: { statusCode in
                            download.success = false
                            download.completed = true
                            download.failureReason = String(format: String(localizationKey: "Download_Failing_Status_Code", type: .error), statusCode)
                            DispatchQueue.main.async {
                                self.viewController.reloadDownload(package: download.package)
                                self.viewController.reloadControlsOnly()
                                TabBarController.singleton?.updatePopup()
                            }
                            if let backgroundTaskIdentifier = download.backgroundTask {
                                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                            }
                            download.backgroundTask = nil
                            self.startMoreDownloads()
                        })
                    }
                }
                
                downloads[package.package] = download
            }
        }
        
        for package in queuedRemovals {
            if !confirmedRemovals.contains(package) {
                confirmedRemovals.append(package)
            }
        }
        queuedRemovals.removeAll()
    }
    
    func startMoreDownloads() {
        var downloadCount: [String: Int] = [:]
        
        self.lockQueue()
        defer { self.unlockQueue() }
        
        let allRawDownloads = upgrades + installations + installdeps
        
        for dlPackage in allRawDownloads {
            let package = dlPackage.package
            if let download = downloads[package.package],
               let host = download.task?.request?.url?.host {
                let hostCount = downloadCount[host] ?? 0
                if download.queued && !download.completed {
                    if hostCount < 2 {
                        download.queued = false
                        download.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                            download.task?.cancel()
                            if let backgroundTaskIdentifier = download.backgroundTask {
                                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                            }
                            download.backgroundTask = nil
                        })
                        
                        download.task?.resume()
                        downloadCount[host] = hostCount + 1
                    }
                } else if !download.queued && !download.completed {
                    downloadCount[host] = hostCount + 1
                }
            }
        }
    }
    
    public func download(package: String) -> Download? {
        if let download = downloads[package] {
            return download
        }
        return queued[package]
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
        
        let destFileName = "/var/cache/apt/archives/\(packageID)_\(version)_\(architecture).deb"
        let destURL = URL(fileURLWithPath: destFileName)
        
        if !FileManager.default.fileExists(atPath: destFileName) {
            if package.package.contains("/") {
                cloneFileAsRoot(from: URL(fileURLWithPath: package.package), to: URL(fileURLWithPath: destFileName))
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
        
        let destFileName = "/var/cache/apt/archives/\(packageID)_\(version)_\(architecture).deb"
        let destURL = URL(fileURLWithPath: destFileName)
        
        moveFileAsRoot(from: fileURL, to: destURL)
        #endif
        return true
    }
    
    private func recheckTotalOps() {
        self.lockQueue()
        
        defer {
            self.unlockQueue()
            self.addDownloadItemsIfNotPresent()
        }
        
        installdeps.removeAll()
        uninstalldeps.removeAll()
        errors.removeAll()
        
        let installationsAndUpgrades = self.installations + self.upgrades
        
        DependencyResolverAccelerator.shared.getDependencies(install: installationsAndUpgrades, remove: uninstallations)
       
        #if !TARGET_SANDBOX && !targetEnvironment(simulator)
        let depOperations = APTWrapper.packageOperations(installs: installationsAndUpgrades, removals: uninstallations)
        
        var installIdentifiers: [String] = []
        if let installOperations = depOperations["Inst"] as? [[String: String]] {
            for installEntry in installOperations {
                if let packageID = installEntry["package"] {
                    installIdentifiers.append(packageID)
                }
            }
        }
        
        for package in installations where package.package.package.contains("/") {
            installIdentifiers.removeAll { $0 == package.package.packageID }
        }
        
        let rawInstalls = PackageListManager.shared.packages(identifiers: installIdentifiers, sorted: true)
        var installDeps: [DownloadPackage] = rawInstalls.compactMap { DownloadPackage(package: $0) }
        
        if depOperations["Err"]?.isEmpty ?? true {
            var installationstemp = installations
            installationstemp.removeAll { installDeps.contains($0) }
            
            for package in installations where package.package.package.contains("/") {
                installationstemp.removeAll { $0 == package }
            }
            
            installations.removeAll { installationstemp.contains($0) }
            
            var upgradestemp = upgrades
            upgradestemp.removeAll { installDeps.contains($0) }
            for package in installations where package.package.package.contains("/") {
                upgradestemp.removeAll { $0 == package }
            }
            
            upgrades.removeAll { upgradestemp.contains($0) }
        }
        
        installDeps.removeAll { installationsAndUpgrades.contains($0) }
        
        var uninstallIdentifiers: [String] = []
        if let removeOperations = depOperations["Remv"] as? [[String: String]] {
            for uninstallEntry in removeOperations {
                if let packageID = uninstallEntry["package"] {
                    uninstallIdentifiers.append(packageID)
                }
            }
        }
        
        let rawUninstalls = PackageListManager.shared.packages(identifiers: uninstallIdentifiers, sorted: true)
        var uninstallDeps: [DownloadPackage] = rawUninstalls.compactMap { DownloadPackage(package: $0) }
        
        if depOperations["Err"]?.isEmpty ?? true {
            var uninstalltemp = uninstallations
            uninstalltemp.removeAll { uninstallDeps.contains($0) }
            uninstallations.removeAll { uninstalltemp.contains($0) }
        }
        
        uninstallDeps.removeAll { uninstallations.contains($0) }
        
        installdeps.append(contentsOf: installDeps)
        uninstalldeps.append(contentsOf: uninstallDeps)
        
        if let errorsList = depOperations["Err"] {
            errors.append(contentsOf: errorsList)
        }
        #endif
    }
    
    private func addBrokenPackages() {
        self.lockQueue()
        defer { self.unlockQueue() }
        
        guard let statusPackages = PackageListManager.shared.packagesList(loadIdentifier: "--installed", repoContext: nil) else {
            return
        }
        for package in statusPackages {
            guard let newestPackage = PackageListManager.shared.newestPackage(identifier: package.package) else {
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
    
    public func removeAllItems() {
        self.lockQueue()
        defer { self.unlockQueue() }
        
        upgrades.removeAll()
        installdeps.removeAll()
        installations.removeAll()
        uninstalldeps.removeAll()
        uninstallations.removeAll()
        queuedRemovals.removeAll()
        confirmedRemovals.removeAll()
        errors.removeAll()
        
        self.addBrokenPackages()
        
        self.addDownloadItemsIfNotPresent()
    }
    
    public func reloadData(recheckPackages: Bool) {
        DispatchQueue.global(qos: .default).async {
            if !self.lockedForInstallation && recheckPackages {
                self.recheckTotalOps()
            }
            
            self.queueLock.wait()
            self.queueLock.signal()
            
            DispatchQueue.main.async {
                self.queueLock.wait()
                
                if self.queueLockCount == 0 {
                    self.viewController.reloadData()
                    TabBarController.singleton?.updatePopup()
                    
                    NotificationCenter.default.post(name: DownloadManager.reloadNotification, object: nil)
                }
                
                self.queueLock.signal()
            }
        }
    }
    
    public func remove(package: String) {
        self.lockQueue()
        defer { self.unlockQueue() }
        
        installations.removeAll { $0.package.package == package }
        upgrades.removeAll { $0.package.package == package }
        installdeps.removeAll { $0.package.package == package }
        uninstallations.removeAll { $0.package.package == package }
        uninstalldeps.removeAll { $0.package.package == package }
    }
    
    public func find(package: Package) -> DownloadManagerQueue {
        let downloadPackage = DownloadPackage(package: package)
        if installations.contains(downloadPackage) {
            return .installations
        }
        if uninstallations.contains(downloadPackage) {
            return .uninstallations
        }
        if upgrades.contains(downloadPackage) {
            return .upgrades
        }
        if installdeps.contains(downloadPackage) {
            return .installdeps
        }
        if uninstalldeps.contains(downloadPackage) {
            return .uninstalldeps
        }
        return .none
    }
    
    public func add(package: Package, queue: DownloadManagerQueue) {
        self.lockQueue()
        defer { self.unlockQueue() }
        
        let downloadPackage = DownloadPackage(package: package)
        switch queue {
        case .none:
            return
        case .installations:
            if !installations.contains(downloadPackage) {
                installations.append(downloadPackage)
            }
        case .uninstallations:
            if !uninstallations.contains(downloadPackage) {
                uninstallations.append(downloadPackage)
            }
        case .upgrades:
            if !upgrades.contains(downloadPackage) {
                upgrades.append(downloadPackage)
            }
        case .installdeps:
            if !installdeps.contains(downloadPackage) {
                installdeps.append(downloadPackage)
            }
        case .uninstalldeps:
            if !uninstalldeps.contains(downloadPackage) {
                uninstalldeps.append(downloadPackage)
            }
        }
    }
    
    public func remove(package: Package, queue: DownloadManagerQueue) {
        let downloadPackage = DownloadPackage(package: package)
        remove(downloadPackage: downloadPackage, queue: queue)
    }
    
    public func remove(downloadPackage: DownloadPackage, queue: DownloadManagerQueue) {
        self.lockQueue()
        defer { self.unlockQueue() }
        
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
    
    private func lockQueue() {
        queueLock.wait()
        queueLockCount += 1
        queueLock.signal()
    }
    
    private func unlockQueue() {
        queueLock.wait()
        queueLockCount -= 1
        queueLock.signal()
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
        guard let repo = repo else {
            return completionHandler(nil, nil)
        }
        guard let providers = repoDownloadOverrideProviders[repo.repoURL],
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
}
