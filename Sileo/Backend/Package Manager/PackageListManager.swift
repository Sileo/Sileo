//
//  PublicListManager.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import CoreSpotlight

final class PackageListManager {
    static let reloadNotification = Notification.Name("SileoPackageCacheReloaded")
    static let prefsNotification = Notification.Name("SileoPackagePrefsChanged")
    static let didUpdateNotification = Notification.Name("SileoDatabaseDidUpdateNotification")
    
    private(set) var installedPackages: [Package]? {
        didSet {
            NotificationCenter.default.post(name: RepoManager.progressNotification, object: installedPackages?.count ?? 0)
        }
    }
    
    private let initSemphaore = DispatchSemaphore(value: 0)
    private var isLoaded = false
    
    public var allPackages: [Package] {
        var packages = installedPackages ?? []
        for repo in RepoManager.shared.repoList {
            packages += repo.packages ?? []
        }
        return packages
    }

    private var databaseUpdateQueue = DispatchQueue(label: "org.coolstar.SileoStore.database-queue")
    public static let shared = PackageListManager()
    
    init() {
        NSLog("[Sileo] App Has Launched")
        DispatchQueue.global(qos: .userInitiated).async {
            self.installedPackages = self.readPackages(installed: true)
            let repoMan = RepoManager.shared
            for repo in repoMan.repoList {
                repo.packages = self.readPackages(repoContext: repo)
                repoMan.update(repo)
                NSLog("[Sileo] \(repo.url!) has been loaded into memory")
            }
            DispatchQueue.main.async {
                self.isLoaded = true
                self.initSemphaore.signal()
                NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                #if targetEnvironment(simulator)
                if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                    return
                }
                #endif
                if UserDefaults.standard.optionalBool("AutoRefreshSources", fallback: true) {
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
        if isLoaded { return }
        initSemphaore.wait()
    }
    
    public func installChange() {
        installedPackages = self.readPackages(installed: true)
        for repo in RepoManager.shared.repoList {
            repo.reloadInstalled()
        }
        DependencyResolverAccelerator.shared.preflightInstalled()
    }

    public func availableUpdates() -> [(Package, Package?)] {
        var updatesAvailable: [(Package, Package?)] = []
        for package in installedPackages ?? [] {
            guard let latestPackage = self.newestPackage(identifier: package.packageID) else {
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
    
    private func loadAllPackages(_ completion: (() -> Void)? = nil) {
        databaseUpdateQueue.async {
            /*
            let allPackages = self.allPackages
            self.changesDatabaseLock.wait()
            
            let newGuids = DatabaseManager.shared.serializePackages(allPackages)
            let oldGuidsFile = DatabaseManager.shared.knownPackages()
            
            if !oldGuidsFile.isEmpty {
                let addedPackages = newGuids.filter({ !oldGuidsFile.contains($0) })
                for changedPackage in addedPackages {
                    if let packageID = changedPackage["package"],
                        let package = allPackagesTempDictionary[packageID] {
                        let stub = PackageStub(from: package)
                        stub.save()
                    }
                }
                
                let removedPackages = oldGuidsFile.filter({ !newGuids.contains($0) })
                for removedPackage in removedPackages {
                    if let packageID = removedPackage["package"] {
                        if allPackagesTempDictionary[packageID] == nil {
                            PackageStub.delete(packageName: packageID)
                        }
                    }
                }
            }
            DatabaseManager.shared.savePackages(newGuids)
            allPackagesTempDictionary.removeAll()
            self.changesDatabaseLock.signal()
            */
                        
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: PackageListManager.didUpdateNotification, object: nil)
                completion?()
            }
        }
    }
    
    public func humanReadableCategory(_ rawCategory: String?) -> String {
        let category = rawCategory ?? ""
        if category.isEmpty {
            return String(localizationKey: "No_Category", type: .categories)
        }
        return String(localizationKey: category, type: .categories)
    }
    
    func package(packageEnum: ([String: String], PackageTags)) -> Package? {
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
        package.icon = dictionary["icon"]
        package.architecture = dictionary["architecture"]
        package.maintainer = dictionary["maintainer"]
        if package.maintainer != nil {
            if dictionary["author"] != nil {
                package.author = dictionary["author"]
            } else {
                package.author = dictionary["maintainer"]
            }
        }
        package.section = humanReadableCategory(dictionary["section"])
        
        package.packageDescription = dictionary["description"]
        package.legacyDepiction = dictionary["depiction"]
        package.depiction = dictionary["sileodepiction"]
        
        package.tags = packageEnum.1
        if package.tags.contains(.commercial) {
            package.commercial = true
        }
        
        package.filename = dictionary["filename"]
        package.size = dictionary["size"]
        
        package.rawControl = dictionary
        return package
    }

    public func readPackages(repoContext: Repo? = nil, packagesFile: URL? = nil, installed: Bool = false) -> [Package]? {
        var tmpPackagesFile: URL?
        if installed {
            tmpPackagesFile = CommandPath.dpkgDir.appendingPathComponent("status").resolvingSymlinksInPath()
        } else if let override = packagesFile {
            tmpPackagesFile = override
        } else if let repo = repoContext {
            tmpPackagesFile = RepoManager.shared.cacheFile(named: "Packages", for: repo)
        }
        guard let packagesFile = tmpPackagesFile,
              let rawPackagesData = try? Data(contentsOf: packagesFile.aptUrl) else { return nil }
        var packagesList = Set<Package>()
        
        var index = 0
        var separator = "\n\n".data(using: .utf8)!
        
        guard let firstSeparator = rawPackagesData.range(of: "\n".data(using: .utf8)!, options: [], in: 0..<rawPackagesData.count) else {
            return Array(packagesList)
        }
        if firstSeparator.lowerBound != 0 {
            let subdata = rawPackagesData.subdata(in: firstSeparator.lowerBound-1..<firstSeparator.lowerBound)
            let character = subdata.first
            if character == 13 { // 13 means carriage return (\r, Windows line ending)
                separator = "\r\n\r\n".data(using: .utf8)!
            }
        }
        
        let isStatusFile = packagesFile.absoluteString.hasSuffix("status")
        var packageDict = [:] as [String: Package]
        while index < rawPackagesData.count {
            let range = rawPackagesData.range(of: separator, options: [], in: index..<rawPackagesData.count)
            var newIndex = 0
            if range == nil {
                newIndex = rawPackagesData.count
            } else {
                newIndex = range!.lowerBound + separator.count
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
            if packageID.isEmpty {
                continue
            }
            if packageID.hasPrefix("gsc.") {
                continue
            }
            if packageID.hasPrefix("cy+") {
                continue
            }
            if packageID == "firmware" {
                continue
            }
            
            guard let package = self.package(packageEnum: rawPackageEnum) else {
                continue
            }
            package.sourceFile = repoContext?.rawEntry
            package.sourceFileURL = packagesFile.aptUrl
            package.rawData = packageData
            package.addOld([package])
            
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
                packagesList.insert(package)
            } else {
                if let otherPkg = packageDict[packageID] {
                    if DpkgWrapper.isVersion(package.version, greaterThan: otherPkg.version) {
                        packageDict[packageID] = package
                    }
                    otherPkg.addOld(package.allVersions)
                    package.allVersionsInternal = otherPkg.allVersionsInternal
                } else {
                    packageDict[packageID] = package
                }
            }
        }
        for (_, val) in packageDict {
            packagesList.insert(val)
        }
        return Array(packagesList)
    }
    
    public func packageList(identifier: String = "", search: String? = nil, sortPackages: Bool = false, repoContext: Repo? = nil) -> [Package] {
        if identifier == "--installed" {
            return installedPackages ?? []
        } else if identifier == "--wishlist" {
            return packages(identifiers: WishListManager.shared.wishlist, sorted: sortPackages)
        }
        var packages = repoContext?.packages ?? allPackages
        if identifier.hasPrefix("category:") {
            let index = identifier.index(identifier.startIndex, offsetBy: 9)
            let category = humanReadableCategory(String(identifier[index...]))
            packages = packages.filter({ $0.section == category })
        } else if identifier.hasPrefix("author:") {
            let index = identifier.index(identifier.startIndex, offsetBy: 7)
            let authorEmail = String(identifier[index...]).lowercased()
            packages = packages.filter {
                guard let lowercaseAuthor = $0.author?.lowercased() else {
                    return true
                }
                return ControlFileParser.authorEmail(string: lowercaseAuthor) == authorEmail.lowercased()
            }
        }
        if let searchQuery = search {
            let search = searchQuery.lowercased()
            packages.removeAll { package in
                var shouldRemove = true
                if package.package.lowercased().contains(search) { shouldRemove = false }
                if let name = package.name?.lowercased() {
                    if !name.isEmpty {
                        if name.contains(search) { shouldRemove = false }
                    }
                }
                if let description = package.packageDescription?.lowercased() {
                    if !description.isEmpty {
                        if description.contains(search) { shouldRemove = false }
                    }
                }
                if let author = package.author?.lowercased() {
                    if !author.isEmpty {
                        if author.contains(search) { shouldRemove = false }
                    }
                }
                if let maintainer = package.maintainer?.lowercased() {
                    if !maintainer.isEmpty {
                        if maintainer.contains(search) { shouldRemove = false }
                    }
                }
                return shouldRemove
            }
        }
        if sortPackages {
            packages.sort { obj1, obj2 -> Bool in
                if let pkg1 = obj1.name?.lowercased() {
                    if let pkg2 = obj2.name?.lowercased() {
                        if let searchQuery = search?.lowercased() {
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
        }
        return packages
    }
    
    public func newestPackage(identifier: String) -> Package? {
        if identifier.contains("/") {
            let url = URL(fileURLWithPath: identifier)
            guard let rawPackageControl = try? DpkgWrapper.rawFields(packageURL: url) else {
                return nil
            }
            guard let rawPackage = try? ControlFileParser.dictionary(controlFile: rawPackageControl, isReleaseFile: true) else {
                return nil
            }
            guard let package = self.package(packageEnum: rawPackage) else {
                return nil
            }
            package.package = identifier
            package.packageFileURL = url
            return package
        } else {
            let allPackages = allPackages
            let lowerIdentifier = identifier.lowercased()
            return allPackages.first(where: { $0.packageID == lowerIdentifier })
        }
    }
    
    public func installedPackage(identifier: String) -> Package? {
        guard let installedPackages = installedPackages else {
            return nil
        }
        
        let lowerIdentifier = identifier.lowercased()
        return installedPackages.first(where: { $0.packageID == lowerIdentifier })
    }
    
    public func package(url: URL) -> Package? {
        let canonicalPath = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
        let filePath = canonicalPath ?? url.path
        return newestPackage(identifier: filePath)
    }
    
    public func packages(identifiers: [String], sorted: Bool, repoContext: Repo? = nil) -> [Package] {
        if identifiers.isEmpty { return [] }
        let packages = (repoContext?.packages ?? allPackages)
        var rawPackages = [Package]()
        for identifier in identifiers {
            rawPackages += packages.filter { $0.packageID == identifier }
        }
        if sorted {
            return rawPackages.sorted(by: { pkg1, pkg2 -> Bool in
                guard let package1 = pkg1.name else {
                    return false
                }
                guard let package2 = pkg2.name else {
                    return false
                }
                return package1.compare(package2) != .orderedDescending
            })
        } else {
            var packagesMap: [String: Package] = [:]
            for package in rawPackages {
                packagesMap[package.package] = package
            }
            
            var packages: [Package] = []
            for identifier in identifiers {
                guard let package = packagesMap[identifier] else {
                    continue
                }
                packages.append(package)
            }
            return packages
        }
    }
    
    public func package(identifier: String, version: String) -> Package? {
        let allPackages = allPackages
        return allPackages.first(where: { $0.packageID == identifier && $0.version == version })
    }
    
    public func package(identifiersAndVersions: [(String, String)]) -> [Package]? {
        let allPackages = allPackages
        
        let filtered = allPackages.filter({
            let pkg = $0
            return identifiersAndVersions.contains(where: { $0.0 == pkg.packageID && $0.1 == pkg.version })
        })
        
        return filtered.isEmpty ? nil : filtered
    }
    
    public func upgradeAll() {
        self.upgradeAll(completion: nil)
    }
    
    public func upgradeAll(completion: (() -> Void)?) {
        let packagePairs = self.availableUpdates()
        let updatesNotIgnored = packagePairs.filter({ $0.1?.wantInfo != .hold })
        let downloadMan = DownloadManager.shared
        
        for packagePair in updatesNotIgnored {
            let newestPkg = packagePair.0
            
            if let installedPkg = packagePair.1, installedPkg == newestPkg {
                continue
            }
            
            downloadMan.add(package: newestPkg, queue: .upgrades)
        }
        
        downloadMan.reloadData(recheckPackages: true, completion: completion)
    }
}
