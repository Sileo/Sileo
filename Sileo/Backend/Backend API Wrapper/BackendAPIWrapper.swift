import Foundation

class BackendAPIWrapper: NSObject {
    @objc enum BackendAPIWrapperAction: NSInteger {
        case upgrade
        case install
        case uninstall
        case installDependency
        case uninstallDependency
        case none
    }
    
    @objc class func installPackages(identifiers: NSArray) {
        guard let identifiers2 = identifiers as? [String] else {
            return
        }
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        
        for identifier in identifiers2 {
            if let newestPkg = packageMan.newestPackage(identifier: identifier) {
                if let installedPkg = packageMan.installedPackage(identifier: identifier), installedPkg.version == newestPkg.version {
                    continue
                }
                downloadMan.add(package: newestPkg, queue: .installations)
            }
        }
    }
    
    @objc class func installPackages(identifiersAndVersions: NSDictionary) {
        guard let identifiersAndVersions2 = identifiersAndVersions as? [String: String] else {
            return
        }
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        let allPkgs = packageMan.allPackages ?? []
        
        for (identifier, version) in identifiersAndVersions2 {
            if let installedPkg = packageMan.installedPackage(identifier: identifier), installedPkg.version == version {
                continue
            }
            
            if let pkg = allPkgs.first(where: { $0.packageID == identifier && $0.version == version }) {
                downloadMan.add(package: pkg, queue: .installations)
            }
        }
    }
    
    @objc class func installPackages(filePaths: NSArray, skipIfExists: ObjCBool) {
        guard let filePaths2 = filePaths as? [String] else {
            return
        }
        let skipIfExists2 = skipIfExists.boolValue
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        
        for filePath in filePaths2 {
            let url = URL(fileURLWithPath: filePath)
            guard let pkgToInstall = packageMan.package(url: url) else {
                continue
            }
            
            if skipIfExists2 {
                if let installedPkg = packageMan.installedPackage(identifier: pkgToInstall.packageID), installedPkg.version == pkgToInstall.version {
                    continue
                }
            }
            
            downloadMan.add(package: pkgToInstall, queue: .installations)
        }
    }
    
    @objc class func upgradePackages(identifiers: NSArray) {
        guard let identifiers2 = identifiers as? [String] else {
            return
        }
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        
        for identifier in identifiers2 {
            if let newestPkg = packageMan.newestPackage(identifier: identifier) {
                if let installedPkg = packageMan.installedPackage(identifier: identifier), installedPkg == newestPkg {
                    continue
                }
                downloadMan.add(package: newestPkg, queue: .upgrades)
            }
        }
    }
    
    @objc class func reinstallPackages(identifiers: NSArray, attemptInstalledVersions: ObjCBool, skipIfAttemptFailed: ObjCBool) {
        guard let identifiers2 = identifiers as? [String] else {
            return
        }
        let attemptInstalledVersions2 = attemptInstalledVersions.boolValue
        let skipIfAttemptFailed2 = skipIfAttemptFailed.boolValue
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        let allPkgs = packageMan.allPackages ?? []
        
        for identifier in identifiers2 {
            guard let installedPkg = packageMan.installedPackage(identifier: identifier) else {
                continue
            }
            
            var pkgToReinstall: Package?
            if attemptInstalledVersions2 {
                let installedVersion = installedPkg.version
                pkgToReinstall = allPkgs.first(where: { $0.packageID == identifier && $0.version == installedVersion })
                
                if pkgToReinstall == nil {
                    if skipIfAttemptFailed2 {
                        continue
                    }
                    else {
                        pkgToReinstall = packageMan.newestPackage(identifier: identifier)
                    }
                }
            }
            else {
                pkgToReinstall = packageMan.newestPackage(identifier: identifier)
            }
            
            if let pkgToReinstall = pkgToReinstall {
                downloadMan.add(package: pkgToReinstall, queue: .installations)
            }
        }
    }
    
    @objc class func uninstallPackages(identifiers: NSArray) {
        guard let identifiers2 = identifiers as? [String] else {
            return
        }
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        
        for identifier in identifiers2 {
            if let pkg = packageMan.installedPackage(identifier: identifier) {
                downloadMan.add(package: pkg, queue: .uninstallations)
            }
        }
    }
    
    @objc class func upgradeAllPackages(completion: (() -> Void)?) {
        PackageListManager.shared.upgradeAll(completion: completion)
    }
    
    @objc class func manipulateQueue(addOrRemove: ObjCBool, identifiers: NSArray, action: BackendAPIWrapperAction, newestOrInstalled: ObjCBool) {
        let addOrRemove2 = addOrRemove.boolValue
        guard let identifiers2 = identifiers as? [String], let action2 = DownloadManagerQueue(rawValue: action.rawValue) else {
            return
        }
        let newestOrInstalled2 = newestOrInstalled.boolValue
        
        let packageMan = PackageListManager.shared
        let downloadMan = DownloadManager.shared
        
        for identifier in identifiers2 {
            let pkg = newestOrInstalled2 ? packageMan.installedPackage(identifier: identifier) : packageMan.newestPackage(identifier: identifier)
            if let pkg = pkg {
                if addOrRemove2 {
                    downloadMan.remove(package: pkg, queue: action2)
                }
                else {
                    downloadMan.add(package: pkg, queue: action2)
                }
            }
        }
    }
    
    @objc class func queuedPackageIdentifiers(action: BackendAPIWrapperAction) -> NSArray? {
        guard let action2 = DownloadManagerQueue(rawValue: action.rawValue) else {
            return nil
        }
        let downloadMan = DownloadManager.shared
        
        var pkgs: [DownloadPackage]
        switch action2 {
            case .upgrades:        pkgs = downloadMan.upgrades
            case .installations:   pkgs = downloadMan.installations
            case .uninstallations: pkgs = downloadMan.uninstallations
            case .installdeps:     pkgs = downloadMan.installdeps
            case .uninstalldeps:   pkgs = downloadMan.uninstalldeps
            default: return nil
        }
        
        let packageIdentifiers = NSMutableArray()
        for pkg in pkgs {
            packageIdentifiers.add(pkg.package.packageID as NSString)
        }
        return packageIdentifiers
    }
    
    @objc class func queueErrors() -> NSArray? {
        return DownloadManager.shared.errors as NSArray
    }
    
    @objc class func reloadQueue(completion: (() -> Void)?) {
        self.reloadQueue(recheckPackages: true, completion: completion)
    }
    
    @objc class func reloadQueue(recheckPackages: ObjCBool, completion: (() -> Void)?) {
        DownloadManager.shared.reloadData(recheckPackages: recheckPackages.boolValue, completion: completion)
    }
    
    @objc class func emptyQueue() {
        DownloadManager.shared.removeAllItems()
    }
    
    @objc class func presentQueueBar() {
        TabBarController.singleton?.presentPopup()
    }
    
    @objc class func dismissQueueBar() {
        TabBarController.singleton?.dismissPopup()
    }
    
    @objc class func presentQueueController() {
        TabBarController.singleton?.presentPopupController()
    }
    
    @objc class func dismissQueueController() {
        TabBarController.singleton?.dismissPopupController()
    }
    
    @objc class func availablePackageIdentifiers() -> NSArray? {
        guard let packages = PackageListManager.shared.allPackages else {
            return nil
        }
        let packageIdentifiers = NSMutableArray()
        for package in packages {
            packageIdentifiers.add(package.packageID as NSString)
        }
        return packageIdentifiers
    }
    
    @objc class func installedPackageIdentifiers() -> NSArray? {
        guard let packages = PackageListManager.shared.installedPackages else {
            return nil
        }
        let packageIdentifiers = NSMutableArray()
        for package in packages {
            packageIdentifiers.add(package.packageID as NSString)
        }
        return packageIdentifiers
    }
    
    @objc class func upgradablePackageIdentifiers() -> NSArray? {
        let packagePairs = PackageListManager.shared.availableUpdates()
        let packageIdentifiers = NSMutableArray()
        for packagePair in packagePairs {
            packageIdentifiers.add(packagePair.0.packageID as NSString)
        }
        return packageIdentifiers
    }
    
    @objc class func packageIsAvailable(identifier: NSString, version: NSString?) -> ObjCBool {
        guard let pkg = PackageListManager.shared.newestPackage(identifier: identifier as String) else {
            return false
        }
        if let version = version as String? {
            let contains = pkg.allVersions.contains(where: { $0.version == version })
            return ObjCBool(contains)
        }
        return true
    }
    
    @objc class func packageIsInstalled(identifier: NSString, version: NSString?) -> ObjCBool {
        guard let pkg = PackageListManager.shared.installedPackage(identifier: identifier as String) else {
            return false
        }
        if let version = version as String? {
            let contains = pkg.allVersions.contains(where: { $0.version == version })
            return ObjCBool(contains)
        }
        return true
    }
    
    @objc class func packageIsUpgradable(identifier: NSString, version: NSString?) -> ObjCBool {
        let identifier2 = identifier as String
        let packageTuple = PackageListManager.shared.availableUpdates()
        let contains = packageTuple.contains(where: { $0.0.packageID == identifier2 })
        return ObjCBool(contains)
    }
    
    @objc class func versionsForPackageIdentifier(identifier: NSString) -> NSArray? {
        guard let foundPackage = PackageListManager.shared.newestPackage(identifier: identifier as String) else {
            return nil
        }
        let versions = NSMutableArray()
        for pkg in foundPackage.allVersions {
            versions.add(pkg.version as NSString)
        }
        return versions
    }
    
    @objc class func latestVersionForPackageIdentifier(identifier: NSString) -> NSString? {
        let pkg = PackageListManager.shared.newestPackage(identifier: identifier as String)
        return pkg?.name as NSString?
    }
    
    @objc class func installedVersionForPackageIdentifier(identifier: NSString) -> NSString? {
        let pkg = PackageListManager.shared.installedPackage(identifier: identifier as String)
        return pkg?.name as NSString?
    }
    
    @objc class func packageNameForPackageIdentifier(identifier: NSString) -> NSString? {
        let pkg = PackageListManager.shared.newestPackage(identifier: identifier as String)
        return pkg?.name as NSString?
    }
    
    @objc class func addRepos(URLs: NSArray, completion: ((ObjCBool, NSAttributedString) -> Void)?) {
        guard let URLs2 = URLs as? [String] else {
            return
        }
        let set = CharacterSet(charactersIn: "/")
        let repoMan = RepoManager.shared
        
        let existingURLs = repoMan.repoList.map({ $0.rawURL.trimmingCharacters(in: set) })
        let toAdd: [URL] = URLs2.compactMap({
            let url = $0.trimmingCharacters(in: set)
            return existingURLs.contains(url) ? nil : URL(string: url)
        })
        
        if !toAdd.isEmpty {
            repoMan.addRepos(with: toAdd)
            self.refreshRepos(forceUpdate: false, forceReload: false, isBackground: false, completion: completion)
            self.sourcesViewController()?.reloadData()
        }
    }
    
    @objc class func removeRepos(URLs: NSArray, completion: ((ObjCBool, NSAttributedString) -> Void)?) {
        guard let URLs2 = URLs as? [String] else {
            return
        }
        let set = CharacterSet(charactersIn: "/")
        let URLs3 = URLs2.map({ $0.trimmingCharacters(in: set) })
        let repoMan = RepoManager.shared
        
        let toRemove: [Repo] = repoMan.repoList.compactMap({
            let url = $0.rawURL.trimmingCharacters(in: set)
            return URLs3.contains(url) ? $0 : nil
        })
        
        if !toRemove.isEmpty {
            repoMan.remove(repos: toRemove)
            self.refreshRepos(forceUpdate: false, forceReload: true, isBackground: false, completion: completion)
            self.sourcesViewController()?.reloadData()
        }
    }
    
    @objc class func refreshRepos(completion: ((ObjCBool, NSAttributedString) -> Void)?) {
        self.refreshRepos(forceUpdate: true, forceReload: true, isBackground: false, completion: completion)
    }
    
    @objc class func refreshRepos(forceUpdate: ObjCBool, forceReload: ObjCBool, isBackground: ObjCBool, completion: ((ObjCBool, NSAttributedString) -> Void)?) {
        let completionTrampoline = { (didFindErrors: Bool, errorOutput: NSAttributedString) in
            if let completion = completion {
                let didFindErrors2 = ObjCBool(didFindErrors)
                completion(didFindErrors2, errorOutput)
            }
        }
        RepoManager.shared.update(force: forceUpdate.boolValue, forceReload: forceReload.boolValue, isBackground: isBackground.boolValue, completion: completionTrampoline)
    }
    
    @objc class func addedRepoURLs() -> NSArray? {
        let set = CharacterSet(charactersIn: "/")
        let urls = RepoManager.shared.repoList.map({ $0.rawURL.trimmingCharacters(in: set) })
        return urls as NSArray
    }
    
    @objc class func repoIsAdded(URL url: NSString) -> ObjCBool {
        let set = CharacterSet(charactersIn: "/")
        let url2 = url.trimmingCharacters(in: set)
        let repo = RepoManager.shared.repoList.first { $0.rawURL.trimmingCharacters(in: set) == url2 }
        return ObjCBool(repo != nil)
    }
    
    @objc class func repoNameForAddedRepo(URL url: NSString) -> NSString? {
        let set = CharacterSet(charactersIn: "/")
        let url2 = url.trimmingCharacters(in: set)
        let repo = RepoManager.shared.repoList.first { $0.rawURL.trimmingCharacters(in: set) == url2 }
        return repo?.displayName as NSString?
    }
    
    @objc class func packageIdentifiersInRepo(URL url: NSString) -> NSArray? {
        let existingSources = RepoManager.shared.repoList
        let set = CharacterSet(charactersIn: "/")
        let normalizedSpecified = url.trimmingCharacters(in: set)
        let normalizedExisting = existingSources.first { $0.rawURL.trimmingCharacters(in: set) == normalizedSpecified }
        
        if let repo = normalizedExisting, let dict = repo.packagesDict {
            let keys = dict.keys.map({ $0 })
            return keys as NSArray
        }
        return nil
    }
    
    @objc class func repoForPackage(identifier: NSString, newestOrInstalled: ObjCBool) -> NSString? {
        let identifier2 = identifier as String
        let newestOrInstalled2 = newestOrInstalled.boolValue
        let packageMan = PackageListManager.shared
        
        let pkg = newestOrInstalled2 ? packageMan.installedPackage(identifier: identifier2) : packageMan.newestPackage(identifier: identifier2)
        if let repo = pkg?.sourceRepo {
            let url = repo.rawURL
            let normalized = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return normalized as NSString
        }
        return nil
    }
    
    @objc class func sourcesViewController() -> SourcesViewController? {
        if let tabBarController = TabBarController.singleton,
           let tabBarVCs = tabBarController.viewControllers,
           let splitVC = tabBarVCs[2] as? UISplitViewController,
           let navVC = splitVC.viewControllers[0] as? SileoNavigationController,
           let sourcesVC = navVC.viewControllers[0] as? SourcesViewController {
            return sourcesVC
        }
        return nil
    }
    
    @objc class func rawSharedPackageListManager() -> UnsafeRawPointer {
        let man = PackageListManager.shared
        return UnsafeRawPointer(Unmanaged.passUnretained(man).toOpaque())
    }
    
    @objc class func rawSharedDownloadManager() -> UnsafeRawPointer {
        let man = DownloadManager.shared
        return UnsafeRawPointer(Unmanaged.passUnretained(man).toOpaque())
    }
    
    @objc class func rawSharedRepoManager() -> UnsafeRawPointer {
        let man = RepoManager.shared
        return UnsafeRawPointer(Unmanaged.passUnretained(man).toOpaque())
    }
    
    @objc class func rawNewestPackage(identifier: NSString) -> UnsafeRawPointer? {
        guard let pkg = PackageListManager.shared.newestPackage(identifier: identifier as String) else {
            return nil
        }
        return UnsafeRawPointer(Unmanaged.passUnretained(pkg).toOpaque())
    }
    
    @objc class func rawInstalledPackage(identifier: NSString) -> UnsafeRawPointer? {
        guard let pkg = PackageListManager.shared.installedPackage(identifier: identifier as String) else {
            return nil
        }
        return UnsafeRawPointer(Unmanaged.passUnretained(pkg).toOpaque())
    }
    
    @objc class func rawRepo(URL url: NSString) -> UnsafeRawPointer? {
        guard let urlObject = URL(string: url as String), let repo = RepoManager.shared.repo(with: urlObject) else {
            return nil
        }
        return UnsafeRawPointer(Unmanaged.passUnretained(repo).toOpaque())
    }
}
