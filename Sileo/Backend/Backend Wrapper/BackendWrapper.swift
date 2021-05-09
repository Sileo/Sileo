import Foundation

@objc class BackendWrapper: NSObject {
    @objc enum BackendWrapperAction: NSInteger {
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
                    } else {
                        pkgToReinstall = packageMan.newestPackage(identifier: identifier)
                    }
                }
            } else {
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
    
    @objc class func manipulateQueue(addOrRemove: ObjCBool, identifiers: NSArray, action: BackendWrapperAction, newestOrInstalled: ObjCBool) {
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
                } else {
                    downloadMan.add(package: pkg, queue: action2)
                }
            }
        }
    }
    
    @objc class func queuedPackageIdentifiers(action: BackendWrapperAction) -> NSArray? {
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
    
    @objc class func confirmQueue() {
        DownloadManager.shared.startUnqueuedDownloads()
        self.reloadQueue(recheckPackages: false, completion: nil)
    }
    
    @objc class func clearQueue() {
        DownloadManager.shared.cancelUnqueuedDownloads()
        self.dismissQueueController(completion: nil)
        self.reloadQueue(recheckPackages: true, completion: nil)
    }
    
    @objc class func presentQueueBar(completion: (() -> Void)?) {
        TabBarController.singleton?.presentPopup(completion: completion)
    }
    
    @objc class func dismissQueueBar(completion: (() -> Void)?) {
        TabBarController.singleton?.dismissPopup(completion: completion)
    }
    
    @objc class func presentQueueController(completion: (() -> Void)?) {
        TabBarController.singleton?.presentPopupController(completion: completion)
    }
    
    @objc class func dismissQueueController(completion: (() -> Void)?) {
        TabBarController.singleton?.dismissPopupController(completion: completion)
    }
    
    @objc class func queueControllerCurrentState() -> LNPopupPresentationState {
        return TabBarController.singleton?.popupPresentationState ?? LNPopupPresentationState.hidden
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
        self.addRepos(URLs: URLs, singleCompletion: nil, allCompletion: completion)
    }
    
    @objc class func addRepos(URLs: NSArray, singleCompletion: ((ObjCBool, NSAttributedString) -> Void)?, allCompletion: ((ObjCBool, NSAttributedString) -> Void)?) {
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
            self.refreshRepos(forceUpdate: false, forceReload: false,
                              useRefreshControl: false, useErrorScreen: true,
                              singleCompletion: singleCompletion, allCompletion: allCompletion)
            self.sourcesViewController()?.reloadData()
        }
    }
    
    @objc class func removeRepos(URLs: NSArray, completion: ((ObjCBool, NSAttributedString) -> Void)?) {
        self.removeRepos(URLs: URLs, singleCompletion: nil, allCompletion: completion)
    }
    
    @objc class func removeRepos(URLs: NSArray, singleCompletion: ((ObjCBool, NSAttributedString) -> Void)?, allCompletion: ((ObjCBool, NSAttributedString) -> Void)?) {
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
            self.refreshRepos(forceUpdate: false, forceReload: true,
                              useRefreshControl: false, useErrorScreen: true,
                              singleCompletion: singleCompletion, allCompletion: allCompletion)
            self.sourcesViewController()?.reloadData()
        }
    }
    
    @objc class func refreshRepos(completion: ((ObjCBool, NSAttributedString) -> Void)?) {
        self.refreshRepos(forceUpdate: true, forceReload: true,
                          useRefreshControl: true, useErrorScreen: true,
                          singleCompletion: nil, allCompletion: completion)
    }
    
    @objc class func refreshRepos(singleCompletion: ((ObjCBool, NSAttributedString) -> Void)?, allCompletion: ((ObjCBool, NSAttributedString) -> Void)?) {
        self.refreshRepos(forceUpdate: true, forceReload: true,
                          useRefreshControl: true, useErrorScreen: true,
                          singleCompletion: singleCompletion, allCompletion: allCompletion)
    }
    
    @objc class func refreshRepos(forceUpdate: ObjCBool, forceReload: ObjCBool,
                                  useRefreshControl: ObjCBool, useErrorScreen: ObjCBool,
                                  singleCompletion: ((ObjCBool, NSAttributedString) -> Void)?, allCompletion: ((ObjCBool, NSAttributedString) -> Void)?) {
        guard let sourcesVC = self.sourcesViewController() else {
            return
        }
        let repos = RepoManager.shared.repoList
        
        sourcesVC.refreshSources(forceUpdate: forceUpdate.boolValue, forceReload: forceReload.boolValue, isBackground: false,
                                 useRefreshControl: useRefreshControl.boolValue, useErrorScreen: useErrorScreen.boolValue,
                                 completion: { didFindErrors, errorOutput in
            let didFindErrors2 = ObjCBool(didFindErrors)
            
            if let singleCompletion = singleCompletion {
                singleCompletion(didFindErrors2, errorOutput)
            }
            
            if let allCompletion = allCompletion {
                var didFinishRefreshingAll = true
                for repo in repos where !repo.isLoaded || repo.startedRefresh || repo.totalProgress != 0 {
                    didFinishRefreshingAll = false
                }
                
                if didFinishRefreshingAll {
                    allCompletion(didFindErrors2, errorOutput)
                }
            }
        })
    }
    
    // Every method below this comment has been thoroughly tested, so the next step is to test everything above
    
    @objc class func presentSourcesErrorsViewController(errorOutput: NSAttributedString, completion: (() -> Void)?) {
        let theVC = self.sourcesViewController()
        theVC?.showRefreshErrorViewController(errorOutput: errorOutput, completion: completion)
    }
    
    @objc class func dismissSourcesErrorsViewController(completion: (() -> Void)?) {
        let theVC = self.sourcesErrorsViewController()
        theVC?.dismiss(animated: true, completion: completion)
    }
    
    @objc class func addedRepoURLs(sortedByName: ObjCBool) -> NSArray? {
        let sorted = sortedByName.boolValue
        let set = CharacterSet(charactersIn: "/")
        
        var repos = RepoManager.shared.repoList
        if sorted {
            repos = repos.sorted(by: { $0.displayName.caseInsensitiveCompare($1.displayName) == .orderedAscending })
        }
        let urls = repos.map({ $0.rawURL.trimmingCharacters(in: set) })
        
        return urls as NSArray
    }
    
    @objc class func repoIsAdded(URL url: NSString) -> ObjCBool {
        let set = CharacterSet(charactersIn: "/")
        let normalized = url.trimmingCharacters(in: set)
        
        let repo = RepoManager.shared.repoList.first { $0.rawURL.trimmingCharacters(in: set) == normalized }
        let isAdded = repo != nil
        
        return ObjCBool(isAdded)
    }
    
    @objc class func repoNameForAddedRepo(URL url: NSString) -> NSString? {
        let set = CharacterSet(charactersIn: "/")
        let normalized = url.trimmingCharacters(in: set)
        
        let repo = RepoManager.shared.repoList.first { $0.rawURL.trimmingCharacters(in: set) == normalized }
        let name = repo?.displayName
        
        return name as NSString?
    }
    
    @objc class func packageIdentifiersInRepo(URL url: NSString) -> NSArray? {
        let set = CharacterSet(charactersIn: "/")
        let normalized = url.trimmingCharacters(in: set)
        
        let repo = RepoManager.shared.repoList.first(where: { $0.rawURL.trimmingCharacters(in: set) == normalized })
        let dict = repo?.packagesDict
        let identifiers = dict?.keys.map({ $0 })
        
        return identifiers as NSArray?
    }
    
    @objc class func repoForPackage(identifier: NSString, newestOrInstalled: ObjCBool) -> NSString? {
        /*
         Bug:
         
         If `identifier` is a package identifier that's currently installed and `newestOrInstalled` is `YES`,
         then this method currently returns `nil` when it should actually return the package's repo URL.
         
         I have no idea why it does this and it needs to be fixed in the future
         */
        
        let ident = identifier as String
        let mode = newestOrInstalled.boolValue
        
        let packageMan = PackageListManager.shared
        let pkg = mode ? packageMan.installedPackage(identifier: ident) : packageMan.newestPackage(identifier: ident)
        let repo = pkg?.sourceRepo
        let url = repo?.rawURL
        let normalizedURL = url?.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return normalizedURL as NSString?
    }
    
    @objc class func tabBarController() -> TabBarController? {
        return TabBarController.singleton
    }
    
    @objc class func featuredViewController() -> FeaturedViewController? {
        if let tabBarController = TabBarController.singleton,
           let tabBarVCs = tabBarController.viewControllers,
           let navVC = tabBarVCs[0] as? SileoNavigationController,
           let theVC = navVC.viewControllers[0] as? FeaturedViewController {
            return theVC
        }
        return nil
    }
    
    @objc class func newsViewController() -> NewsViewController? {
        if let tabBarController = TabBarController.singleton,
           let tabBarVCs = tabBarController.viewControllers,
           let navVC = tabBarVCs[1] as? SileoNavigationController,
           let theVC = navVC.viewControllers[0] as? NewsViewController {
            return theVC
        }
        return nil
    }
    
    @objc class func sourcesViewController() -> SourcesViewController? {
        if let tabBarController = TabBarController.singleton,
           let tabBarVCs = tabBarController.viewControllers,
           let splitVC = tabBarVCs[2] as? UISplitViewController,
           let navVC = splitVC.viewControllers[0] as? SileoNavigationController,
           let theVC = navVC.viewControllers[0] as? SourcesViewController {
            return theVC
        }
        return nil
    }
    
    @objc class func packageListViewController() -> PackageListViewController? {
        if let tabBarController = TabBarController.singleton,
           let tabBarVCs = tabBarController.viewControllers,
           let navVC = tabBarVCs[3] as? SileoNavigationController,
           let theVC = navVC.viewControllers[0] as? PackageListViewController {
            return theVC
        }
        return nil
    }
    
    @objc class func searchViewController() -> PackageListViewController? {
        if let tabBarController = TabBarController.singleton,
           let tabBarVCs = tabBarController.viewControllers,
           let navVC = tabBarVCs[4] as? SileoNavigationController,
           let theVC = navVC.viewControllers[0] as? PackageListViewController {
            return theVC
        }
        return nil
    }
    
    @objc class func sourcesErrorsViewController() -> SourcesErrorsViewController? {
        if let tabBarController = TabBarController.singleton,
           let navVC = tabBarController.presentedViewController as? UINavigationController,
           let theVC = navVC.viewControllers[0] as? SourcesErrorsViewController {
            return theVC
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
    
    @objc class func rawAddedRepo(URL url: NSString) -> UnsafeRawPointer? {
        guard let urlObject = URL(string: url as String),
              let repo = RepoManager.shared.repo(with: urlObject)
        else {
            return nil
        }
        return UnsafeRawPointer(Unmanaged.passUnretained(repo).toOpaque())
    }
}
