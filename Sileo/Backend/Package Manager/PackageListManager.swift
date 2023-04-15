//
//  PublicListManager.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit


final class PackageListManager {
    
    static let reloadNotification = Notification.Name("SileoPackageCacheReloaded")
    static let installChange = Notification.Name("SileoInstallChanged")
    static let stateChange = Notification.Name("SileoStateChanged")
    static let prefsNotification = Notification.Name("SileoPackagePrefsChanged")
    
    private(set) var installedPackages: [String: Package] {
        didSet {
            NotificationCenter.default.post(name: RepoManager.progressNotification, object: installedPackages.count)
        }
    }
    
    public var localPackages = [String: Package]()
    
    private let initSemphaore = DispatchSemaphore(value: 0)
    public var isLoaded = false
    
    public var allPackagesArray: [Package] {
        var packages = [Package]()
        var installedPackages = installedPackages
        for repo in RepoManager.shared.repoList {
            let repoPackageArray = repo.packageArray
            packages += repo.packageArray
            for package in repoPackageArray where installedPackages[package.packageID] != nil {
                installedPackages.removeValue(forKey: package.packageID)
            }
        }
        return packages + Array(installedPackages.values)
    }

    private let databaseUpdateQueue = DispatchQueue(label: "org.coolstar.SileoStore.database-queue")
    private let packageListQueue = DispatchQueue(label: "sileo.package-list-queue")
    private let operationQueue = OperationQueue()

    public static let shared = PackageListManager()
    
    init() {
        self.installedPackages = PackageListManager.readPackages(installed: true)
        operationQueue.maxConcurrentOperationCount = (ProcessInfo.processInfo.processorCount * 2)
        
        packageListQueue.async { [self] in
            let repoMan = RepoManager.shared
            let repoList = repoMan.repoList
            
            let operations: [BlockOperation] = repoList.map { repo in
                return BlockOperation {
                    repo.packageDict = PackageListManager.readPackages(repoContext: repo)
                }
            }
            self.operationQueue.addOperations(operations, waitUntilFinished: true)
            repoMan.update(repoList)
            
            DispatchQueue.main.async {
                self.isLoaded = true
                while true {
                    if self.initSemphaore.signal() == 0 {
                        break
                    }
                }
                DownloadManager.aptQueue.async {
                    DependencyResolverAccelerator.shared.preflightInstalled()
                }
                NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                NotificationCenter.default.post(name: NewsViewController.reloadNotification, object: nil)
                if UserDefaults.standard.bool(forKey: "AutoRefreshSources", fallback: true) {
                    // Start a background repo refresh here instead because it doesn't like it in the Source View Controller
                    if let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
                       let sourcesSVC = tabBarController.viewControllers?[2] as? UISplitViewController,
                       let sourcesNavNV = sourcesSVC.viewControllers[0] as? SileoNavigationController,
                       let sourcesVC = sourcesNavNV.viewControllers[0] as? SourcesViewController {
                        sourcesVC.refreshSources(forceUpdate: false, forceReload: false, isBackground: true, useRefreshControl: false, useErrorScreen: false, completion: nil)
                    }
                }
            }
        }
    }
    
    public func initWait() {
        if Thread.isMainThread {
            fatalError("\(Thread.current.threadName) cannot be used to hold backend")
        }
        if isLoaded { return }
        initSemphaore.wait()
    }
    
    public func repoInstallChange() {
        for repo in RepoManager.shared.repoList {
            repo.reloadInstalled()
        }
    }
    
    public func installChange() {
        installedPackages = PackageListManager.readPackages(installed: true)
        repoInstallChange()
    }

    public func availableUpdates() -> [(Package, Package?)] {
        var updatesAvailable: [(Package, Package?)] = []
        for package in installedPackages.values {
            guard let latestPackage = self.newestPackage(identifier: package.packageID, repoContext: nil) else {
                continue
            }
            if latestPackage.version != package.version {
                if DpkgWrapper.isVersion(latestPackage.version, greaterThan: package.version) {
                    updatesAvailable.append((latestPackage, package))
                }
            }
        }
        return updatesAvailable
    }

    public class func humanReadableCategory(_ rawCategory: String?) -> String {
        let category = rawCategory ?? ""
        if category.isEmpty {
            return String(localizationKey: "No_Category", type: .categories)
        }
        return String(localizationKey: category, type: .categories)
    }
    
    class func package(packageEnum: ([String: String], PackageTags)) -> Package? {
        let dictionary = packageEnum.0
        guard let packageID = dictionary["package"] else {
            return nil
        }
        guard let packageVersion = dictionary["version"] else {
            return nil
        }
        
        let package = Package(package: packageID, version: packageVersion)
        package.name = dictionary["name"]
        if package.name == nil {
            package.name = package.package
        }
        package.icon = URL(string: dictionary["icon"])
        package.architecture = dictionary["architecture"]
        package.maintainer = Maintainer(string: dictionary["maintainer"])
        if package.maintainer != nil {
            if dictionary["author"] != nil {
                package.author = Maintainer(string: dictionary["author"])
            } else {
                package.author = package.maintainer
            }
        }
        package.rawSection = dictionary["section"]?.lowercased()
        package.section = humanReadableCategory(dictionary["section"])
        
        package.packageDescription = dictionary["description"]
        package.legacyDepiction = URL(string: dictionary["depiction"])
        package.depiction = URL(string: dictionary["sileodepiction"])
        package.nativeDepiction = URL(string: dictionary["native-depiction"])
        
        if let installedSize = dictionary["installed-size"] {
            package.installedSize = Int(installedSize)
        }

        package.tags = packageEnum.1
        if package.tags.contains(.commercial) {
            package.commercial = true
        }
        
        package.filename = dictionary["filename"]
        package.essential = dictionary["essential"]
        package.size = dictionary["size"]
        
        package.rawControl = dictionary
        return package
    }

    public class func readPackages(repoContext: Repo? = nil, packagesFile: URL? = nil, installed: Bool = false) -> [String: Package] {
        let archs = DpkgWrapper.architecture
        var tmpPackagesFile: URL?
        var toWrite: URL?
        var dict = [String: Package]()
        if installed {
            tmpPackagesFile = CommandPath.dpkgDir.appendingPathComponent("status").resolvingSymlinksInPath()
            toWrite = tmpPackagesFile
        } else if let override = packagesFile {
            tmpPackagesFile = override
            if let repo = repoContext {
                toWrite = RepoManager.shared.cacheFile(named: "Packages", for: repo)
            } else {
                toWrite = override
            }
        } else if let repo = repoContext {
            tmpPackagesFile = RepoManager.shared.cacheFile(named: "Packages", for: repo)
            toWrite = RepoManager.shared.cacheFile(named: "Packages", for: repo)
        }
        guard let packagesFile = tmpPackagesFile,
              let rawPackagesData = try? Data(contentsOf: packagesFile.aptUrl) else { return dict }

        var index = 0
        var separator = "\n\n".data(using: .utf8)!
        
        guard let firstSeparator = rawPackagesData.range(of: "\n".data(using: .utf8)!, options: [], in: 0..<rawPackagesData.count) else {
            return dict
        }
        if firstSeparator.lowerBound != 0 {
            let subdata = rawPackagesData.subdata(in: firstSeparator.lowerBound-1..<firstSeparator.lowerBound)
            let character = subdata.first
            if character == 13 { // 13 means carriage return (\r, Windows line ending)
                separator = "\r\n\r\n".data(using: .utf8)!
            }
        }
        
        var savedCount = 0
        let isStatusFile = packagesFile.absoluteString.hasSuffix("status")
        while index < rawPackagesData.count {
            let newIndex: Int
            if let range = rawPackagesData.range(of: separator, options: [], in: index..<rawPackagesData.count) {
                newIndex = range.lowerBound + separator.count
            } else {
                newIndex = rawPackagesData.count
            }
            
            let subRange = index..<newIndex
            let packageData = rawPackagesData.subdata(in: subRange)
            
            index = newIndex
            
            guard let rawPackageEnum = try? ControlFileParser.dictionary(controlData: packageData, isReleaseFile: false) else {
                continue
            }
            let rawPackage = rawPackageEnum.0
            guard let packageID = rawPackage["package"] else {
                continue
            }
            
            guard !packageID.isEmpty, !packageID.hasPrefix("gsc."), !packageID.hasPrefix("cy+"), packageID != "firmware" else {
                continue
            }
            
            guard let package = self.package(packageEnum: rawPackageEnum) else {
                continue
            }
            guard archs.valid(arch: package.architecture) else {
                continue
            }
            package.sourceFile = repoContext?.rawEntry
            package.sourceFileURL = toWrite
            savedCount += packageData.count
            package.rawData = packageData
            
            if isStatusFile {
                var wantInfo: pkgwant = .install
                var eFlag: pkgeflag = .ok
                var pkgStatus: pkgstatus = .installed
            
                let statusValid = DpkgWrapper.getValues(statusField: package.rawControl["status"],
                                                        wantInfo: &wantInfo,
                                                        eFlag: &eFlag,
                                                        pkgStatus: &pkgStatus)
                if !statusValid {
                    continue
                }
            
                package.wantInfo = wantInfo
                package.eFlag = eFlag
                package.status = pkgStatus
            
                if package.eFlag == .ok {
                    if package.status == .notinstalled || package.status == .configfiles {
                        continue
                    }
                }
                let packageInstallPath = CommandPath.dpkgDir.appendingPathComponent("info/\(packageID).list")
                let attr = try? FileManager.default.attributesOfItem(atPath: packageInstallPath.path)
                package.installDate = attr?[FileAttributeKey.modificationDate] as? Date
                dict[package.packageID] = package
            } else {
                if let otherPkg = dict[packageID] {
                    if DpkgWrapper.isVersion(package.version, greaterThan: otherPkg.version) {
                        package.addOld(from: otherPkg)
                        dict[packageID] = package
                    } else {
                        otherPkg.addOld(from: package)
                    }
                } else {
                    dict[packageID] = package
                }
            }
        }

        return dict
    }
    
    public func packageList(identifier: String = "", search: String? = nil, sortPackages sort: Bool = false, repoContext: Repo? = nil, lookupTable: [String: [Package]]? = nil, packagePrepend: [Package]? = nil) -> [Package] {
        var packageList = [Package]()
        if identifier == "--installed" {
            packageList = Array(installedPackages.values)
        } else if identifier == "--wishlist" {
            packageList = packages(identifiers: WishListManager.shared.wishlist, sorted: sort)
        } else if let prepend = packagePrepend {
            packageList = prepend
        } else {
            if var search = search?.lowercased(),
               let lookupTable = lookupTable {
                var isFound = false
                while !search.isEmpty && !isFound {
                    if let packages = lookupTable[search] {
                        packageList = packages
                        isFound = true
                    } else {
                        search.removeLast()
                    }
                }
                if !isFound {
                    packageList = repoContext?.packageArray ?? allPackagesArray
                }
            } else {
                packageList = repoContext?.packageArray ?? allPackagesArray
            }
        }
        if identifier.hasPrefix("category:") {
            let index = identifier.index(identifier.startIndex, offsetBy: 9)
            let category = PackageListManager.humanReadableCategory(String(identifier[index...]))
            packageList = packageList.filter({ $0.section == category })
        } else if identifier.hasPrefix("author:") {
            let index = identifier.index(identifier.startIndex, offsetBy: 7)
            let authorEmail = String(identifier[index...])
            packageList = packageList.filter {
                guard let authorEmail = $0.author?.email else {
                    return false
                }
                return authorEmail == authorEmail
            }
        }
        if let searchQuery = search,
           !searchQuery.isEmpty {
            let lowercased = searchQuery.lowercased()
            packageList.removeAll { package in
                // check if the user search term is in the package ID, description or in the author / maintainer name
                for field in [package.package, package.name, package.author?.name, package.maintainer?.name] {
                    if field?.localizedStandardContains(lowercased) ?? false { return false }
                }
                
                return true
            }
        }
        // Remove Any Duplicates
        var temp = [String: Package]()
        for package in packageList {
            if let existing = temp[package.packageID] {
                if DpkgWrapper.isVersion(package.version, greaterThan: existing.version) {
                    temp[package.packageID] = package
                }
            } else {
                temp[package.packageID] = package
            }
        }
        packageList = Array(temp.values)
        if sort {
            packageList = sortPackages(packages: packageList, search: search)
        }
        return packageList
    }
    
    public func sortPackages(packages: [Package], search: String?) -> [Package] {
        var tmp = packages
        tmp.sort { obj1, obj2 -> Bool in
            if let pkg1 = obj1.name?.lowercased() {
                if let pkg2 = obj2.name?.lowercased() {
                    if let searchQuery = search?.lowercased(),
                       !searchQuery.isEmpty {
                        if pkg1.hasPrefix(searchQuery) && !pkg2.hasPrefix(searchQuery) {
                            return true
                        } else if !pkg1.hasPrefix(searchQuery) && pkg2.hasPrefix(searchQuery) {
                            return false
                        }
                        
                        let diff1 = pkg1.count - searchQuery.count
                        let diff2 = pkg2.count - searchQuery.count
                        
                        if diff1 < diff2 {
                            return true
                        } else if diff1 > diff2 {
                            return false
                        }
                        return pkg1.compare(pkg2) != .orderedDescending
                    } else {
                        return pkg1.compare(pkg2) != .orderedDescending
                    }
                } else {
                    return true
                }
            }
            return false
        }
        return tmp
    }
    
    public func newestPackage(identifier: String, repoContext: Repo?, packages: [Package]? = nil) -> Package? {
        if identifier.contains("/") {
            let url = URL(fileURLWithPath: identifier)
            guard let rawPackageControl = try? DpkgWrapper.rawFields(packageURL: url) else {
                return nil
            }
            guard let rawPackage = try? ControlFileParser.dictionary(controlFile: rawPackageControl, isReleaseFile: true) else {
                return nil
            }
            guard let package = PackageListManager.package(packageEnum: rawPackage) else {
                return nil
            }
            package.package = identifier
            package.packageFileURL = url
            return package
        } else if let repoContext = repoContext {
            return repoContext.packageDict[identifier.lowercased()]
        } else {
            var newestPackage: Package?
            if var packages = packages {
                packages = packages.filter { $0.packageID == identifier }
                for package in packages {
                    if let old = newestPackage {
                        if DpkgWrapper.isVersion(package.version, greaterThan: old.version) {
                            newestPackage = package
                        }
                    } else {
                        newestPackage = package
                    }
                }
                return newestPackage
            }
            for repo in RepoManager.shared.repoList {
                if let package = repo.packageDict[identifier] {
                    if let old = newestPackage {
                        if DpkgWrapper.isVersion(package.version, greaterThan: old.version) {
                            newestPackage = package
                        }
                    } else {
                        newestPackage = package
                    }
                }
            }
            return newestPackage
        }
    }
    
    public func installedPackage(identifier: String) -> Package? {
        installedPackages[identifier.lowercased()]
    }
    
    public func package(url: URL) -> Package? {
        let canonicalPath = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
        let filePath = canonicalPath ?? url.path
        let package = newestPackage(identifier: filePath, repoContext: nil)
        if let package = package {
            localPackages[package.packageID] = package
        }
        return package
    }
    
    public func packages(identifiers: [String], sorted: Bool, repoContext: Repo? = nil, packages: [Package]? = nil) -> [Package] {
        if identifiers.isEmpty { return [] }
        var rawPackages = [Package]()
        if let packages = (repoContext?.packageArray ?? packages) {
            for identifier in identifiers {
                rawPackages += packages.filter { $0.packageID == identifier }
                if let package = localPackages[identifier] {
                    rawPackages.append(package)
                }
            }
            
            if sorted {
                return Array(Set(rawPackages.sorted(by: { pkg1, pkg2 -> Bool in
                    guard let package1 = pkg1.name else {
                        return false
                    }
                    guard let package2 = pkg2.name else {
                        return false
                    }
                    return package1.compare(package2) != .orderedDescending
                })))
            } else {
                return Array(Set(rawPackages))
            }
        }
        
        return identifiers.compactMap { newestPackage(identifier: $0, repoContext: nil) }
    }
    
    public func package(identifier: String, version: String, packages: [Package]? = nil) -> Package? {
        if let packages = packages {
            return packages.first(where: { $0.packageID == identifier && $0.version == version })
        }
        for repo in RepoManager.shared.repoList {
            if let package = repo.packageDict[identifier],
               let version = package.getVersion(version) {
                return version
            }
        }
        if let package = localPackages[identifier],
           let version = package.getVersion(version) {
            return version
        }
        return nil
    }

    public func upgradeAll() {
        self.upgradeAll(completion: nil)
    }
    
    public func upgradeAll(completion: (() -> Void)?) {
        let packagePairs = self.availableUpdates()
        let updatesNotIgnored = packagePairs.filter({ $0.1?.wantInfo != .hold })
        if updatesNotIgnored.isEmpty {
            completion?()
            return
        }

        let downloadMan = DownloadManager.shared
        var upgrades = Set<Package>()
        
        for packagePair in updatesNotIgnored {
            let newestPkg = packagePair.0
            
            if let installedPkg = packagePair.1, installedPkg == newestPkg {
                continue
            }
            upgrades.insert(newestPkg)
        }
        
        downloadMan.upgradeAll(packages: upgrades) {
            downloadMan.reloadData(recheckPackages: true) {
                completion?()
                if UserDefaults.standard.bool(forKey: "UpgradeAllAutoQueue", fallback: true) {
                    TabBarController.singleton?.presentPopupController()
                }
            }
        }
    }
}
