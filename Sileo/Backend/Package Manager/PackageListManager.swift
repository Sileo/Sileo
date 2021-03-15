//
//  PublicListManager.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//
import Foundation
import CoreSpotlight

final class PackageListManager {
    static let reloadNotification = Notification.Name("SileoPackageCacheReloaded")
    static let prefsNotification = Notification.Name("SileoPackagePrefsChanged")
    static let didUpdateNotification = Notification.Name("SileoDatabaseDidUpdateNotification")
    
    private(set) var installedPackages: [Package]?
    private(set) var allPackages: [Package]?
    
    private var databaseLock = DispatchSemaphore(value: 1)
    private var changesDatabaseLock = DispatchSemaphore(value: 1)
    private var databaseUpdateQueue = DispatchQueue(label: "org.coolstar.SileoStore.database-queue")
    
    private var isLoaded = false
    
    public static let shared = PackageListManager()
    
    public func waitForReady() {
        databaseLock.wait()
        databaseLock.signal()
        if !isLoaded {
            self.loadAllPackages()
        }
    }
    
    public func waitForChangesDatabaseReady() {
        self.waitForReady()
        changesDatabaseLock.wait()
        changesDatabaseLock.signal()
    }
    
    public func purgeCache() {
        databaseLock.wait()
        installedPackages = nil
        
        installedPackages = self.packagesList(loadIdentifier: "--installed", repoContext: nil)
        for repo in RepoManager.shared.repoList {
            repo.packages = nil
            repo.packagesProvides = nil
            repo.packagesDict = nil
            repo.isLoaded = false
        }
        allPackages = nil
        isLoaded = false
        
        let semaphore = DispatchSemaphore(value: 0)
        CSSearchableIndex.default().deleteAllSearchableItems { _ in
            semaphore.signal()
        }
        semaphore.wait()
        databaseLock.signal()
    }
    
    public func availableUpdates() -> [(Package, Package?)] {
        self.waitForReady()
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
        
        #if !targetEnvironment(simulator) && !TARGET_SANDBOX
        if self.installedPackage(identifier: "apt") == nil {
            if let newPackage = self.newestPackage(identifier: "apt") {
                updatesAvailable.append((newPackage, nil))
            }
        }
        #endif
        return updatesAvailable
    }
    
    private func checkHardcodedPolicy(_ package1: Package, package2: Package) -> Bool {
        let sourceRepo1 = package1.sourceRepo?.url?.host
        let sourceRepo2 = package2.sourceRepo?.url?.host
        if sourceRepo1 == "apt.procurs.us" && sourceRepo2 != "apt.procurs.us" {
            return true
        } else if sourceRepo1 != "apt.procurs.us" && sourceRepo2 == "apt.procurs.us" {
            return false
        }
        if sourceRepo1 == "repo.theodyssey.dev" && sourceRepo2 != "repo.theodyssey.dev" {
            return true
        } else if sourceRepo1 != "repo.theodyssey.dev" && sourceRepo2 == "repo.theodyssey.dev" {
            return false
        }
        if sourceRepo1 == "repo.chimera.sh" && sourceRepo2 != "repo.chimera.sh" {
            return true
        } else if sourceRepo1 != "repo.chimera.sh" && sourceRepo2 == "repo.chimera.sh" {
            return false
        }
        if sourceRepo1 == "repo.getsileo.app" && sourceRepo2 != "repo.getsileo.app" {
            return true
        } else if sourceRepo1 != "repo.getsileo.app" && sourceRepo2 == "repo.getsileo.app" {
            return false
        }
        return DpkgWrapper.isVersion(package1.version,
                                     greaterThan: package2.version)
    }
    
    private func loadAllPackages() {
        databaseLock.wait()
        
        defer { databaseLock.signal() }
        
        if isLoaded {
            return
        }
        
        var repos = RepoManager.shared.repoList
        let lock = DispatchSemaphore(value: 1)
        let updateGroup = DispatchGroup()
        
        for threadID in 0..<(ProcessInfo.processInfo.processorCount) {
            updateGroup.enter()
            let repoLoadQueue = DispatchQueue(label: "repo-queue-\(threadID)")
            repoLoadQueue.async {
                while true {
                    lock.wait()
                    guard !repos.isEmpty else {
                        lock.signal()
                        break
                    }
                    let repo = repos.removeFirst()
                    lock.signal()
                    
                    _ = self.packagesList(loadIdentifier: "", repoContext: repo)
                }
                updateGroup.leave()
            }
        }
        updateGroup.wait()
        
        var allPackagesTempDictionary: [String: Package] = [:]
        allPackages = []
        
        for repo in RepoManager.shared.repoList {
            for package in repo.packages ?? [] {
                let packageID = package.package
                if let otherPkg = allPackagesTempDictionary[packageID] {
                    if (checkHardcodedPolicy(package, package2: otherPkg)
                        && package.filename != nil) || otherPkg.filename == nil {
                        allPackagesTempDictionary[packageID] = package
                    }
                } else {
                    allPackagesTempDictionary[packageID] = package
                }
            }
        }
        
        for package in installedPackages ?? [] {
            let packageID = package.package
            if let otherPkg = allPackagesTempDictionary[packageID] {
                if (checkHardcodedPolicy(package, package2: otherPkg)
                    && package.filename != nil) || otherPkg.filename == nil {
                    allPackagesTempDictionary[packageID] = package
                }
            } else {
                allPackagesTempDictionary[packageID] = package
            }
        }
        
        for (_, val) in allPackagesTempDictionary {
            allPackages?.append(val)
        }
        
        databaseUpdateQueue.async {
            if let allPackages = self.allPackages {
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
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: PackageListManager.didUpdateNotification, object: nil)
                }
            }
        }
        
        isLoaded = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            DependencyResolverAccelerator.shared.preflightInstalled()
            DownloadManager.shared.removeAllItems()
            DownloadManager.shared.reloadData(recheckPackages: true)
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
        package.section = dictionary["section"]
        
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
        package.allVersionsInternal.list.append(package)
        return package
    }
    
    public var dpkgDir: URL {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        return Bundle.main.bundleURL
        #else
        return URL(fileURLWithPath: "/var/lib/dpkg")
        #endif
    }
    
    public func packagesList(loadIdentifier: String, repoContext: Repo?) -> [Package]? {
        try? packagesList(loadIdentifier: loadIdentifier, repoContext: repoContext, useCache: true,
                          overridePackagesFile: nil, sortPackages: false, lookupTable: [:])
    }
    
    public func packagesList(loadIdentifier: String, repoContext: Repo?, sortPackages: Bool, lookupTable: [String: [Package]]) -> [Package]? {
        try? packagesList(loadIdentifier: loadIdentifier, repoContext: repoContext, useCache: true,
                          overridePackagesFile: nil, sortPackages: sortPackages, lookupTable: lookupTable)
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    public func packagesList(loadIdentifier: String, repoContext: Repo?, useCache: Bool, overridePackagesFile: URL?, sortPackages: Bool, lookupTable: [String: [Package]]) throws -> [Package] {
        var packagesList: [Package]?
        var packagesFile: URL?
        if let repo = repoContext {
            packagesFile = RepoManager.shared.cacheFile(named: "Packages", for: repo)
            if useCache {
                packagesList = repoContext?.packages
            }
        } else {
            if loadIdentifier.hasPrefix("--installed") {
                packagesFile = dpkgDir.appendingPathComponent("status").resolvingSymlinksInPath()
                if useCache {
                    packagesList = installedPackages
                }
            } else if loadIdentifier.hasPrefix("--wishlist") {
                let wishlist = WishListManager.shared.wishlist
                let idents = wishlist.joined(separator: " ")
                
                packagesList = try self.packagesList(loadIdentifier: String(format: "idents:%@", idents),
                                                     repoContext: repoContext,
                                                     useCache: useCache,
                                                     overridePackagesFile: overridePackagesFile,
                                                     sortPackages: sortPackages,
                                                     lookupTable: [:])
            } else if useCache {
                if allPackages == nil {
                    self.waitForReady()
                }
                packagesList = allPackages
            }
        }
        if overridePackagesFile != nil {
            packagesFile = overridePackagesFile
        }
        
        let loadIdentifiers = loadIdentifier.components(separatedBy: ",")
        var categorySearch: Substring?
        var searchName: Substring?
        var authorEmail: Substring?
        var packageIdentifiers: [String]?
        
        for identifier in loadIdentifiers {
            if identifier.hasPrefix("category:") {
                let index = identifier.index(identifier.startIndex, offsetBy: 9)
                categorySearch = identifier[index...]
            }
            if identifier.hasPrefix("search:") {
                let index = identifier.index(identifier.startIndex, offsetBy: 7)
                searchName = identifier[index...]
                
                if useCache && !loadIdentifier.contains(",") {
                    let cacheKeys = lookupTable.keys.sorted { x, y -> Bool in
                        y.count < x.count
                    }
                    for key in cacheKeys {
                        if searchName?.hasPrefix(key) ?? false {
                            packagesList = lookupTable[key]
                            break
                        }
                    }
                }
            }
            if identifier.hasPrefix("author:") {
                let index = identifier.index(identifier.startIndex, offsetBy: 7)
                authorEmail = identifier[index...]
            }
            if identifier.hasPrefix("idents:") {
                let index = identifier.index(identifier.startIndex, offsetBy: 7)
                packageIdentifiers = identifier[index...].components(separatedBy: CharacterSet(charactersIn: " "))
            }
        }
        
        var tempDictionary = [:] as [String: Package]
        
        if let packagesFileSafe = packagesFile {
            if packagesList == nil {
                packagesList = []
                let rawPackagesData = try Data(contentsOf: packagesFileSafe)
                
                var index = 0
                var separator = "\n\n".data(using: .utf8)!
                
                guard let firstSeparator = rawPackagesData.range(of: "\n".data(using: .utf8)!, options: [], in: 0..<rawPackagesData.count) else {
                    return packagesList ?? []
                }
                if firstSeparator.lowerBound != 0 {
                    let subdata = rawPackagesData.subdata(in: firstSeparator.lowerBound-1..<firstSeparator.lowerBound)
                    let character = subdata.first
                    if character == 13 { // \r
                        //Found windows line endings
                        separator = "\r\n\r\n".data(using: .utf8)!
                    }
                }
                
                let isStatusFile = packagesFileSafe.absoluteString.hasSuffix("status")
                
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
                    
                    guard let package = self.package(packageEnum: rawPackageEnum) else {
                        continue
                    }
                    package.sourceFile = repoContext?.rawEntry
                    package.sourceFileURL = packagesFile
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
                        packagesList?.append(package)
                    } else {
                        if let otherPkg = tempDictionary[packageID] {
                            if DpkgWrapper.isVersion(package.version, greaterThan: otherPkg.version) {
                                tempDictionary[packageID] = package
                            }
                            otherPkg.allVersionsInternal.list.append(contentsOf: package.allVersionsInternal.list)
                            package.allVersionsInternal = otherPkg.allVersionsInternal
                        } else {
                            tempDictionary[packageID] = package
                        }
                    }
                }
            }
        }
        
        for (_, val) in tempDictionary {
            packagesList?.append(val)
        }
        
        var packageListFinal: [Package] = packagesList ?? []
        if categorySearch != nil {
            packageListFinal.removeAll { self.humanReadableCategory($0.section).lowercased() != categorySearch?.lowercased() }
        }
        if let searchQuery = searchName {
            packageListFinal.removeAll { !($0.name?.lowercased().contains(searchQuery.lowercased()) ?? true) }
        }
        if let searchEmail = authorEmail {
            packageListFinal.removeAll {
                guard let lowercaseAuthor = $0.author?.lowercased() else {
                    return true
                }
                return ControlFileParser.authorEmail(string: lowercaseAuthor) != searchEmail.lowercased()
            }
        }
        if let searchIdentifiers = packageIdentifiers {
            packageListFinal.removeAll {
                !searchIdentifiers.contains($0.package)
            }
        }
        
        if sortPackages {
            packageListFinal.sort { obj1, obj2 -> Bool in
                if let pkg1 = obj1.name {
                    if let pkg2 = obj2.name {
                        if let searchQuery = searchName {
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
        
        if useCache {
            if loadIdentifier.isEmpty {
                if repoContext != nil && repoContext?.packages == nil {
                    repoContext?.packages = packageListFinal
                    repoContext?.packagesProvides = packageListFinal.filter { $0.rawControl["provides"] != nil }
                    repoContext?.packagesDict = tempDictionary
                }
            } else if loadIdentifier == "--installed" {
                installedPackages = packageListFinal
            }
        }
        return packageListFinal
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
        }
        let lowerIdentifier = identifier.lowercased()
        for package in allPackages ?? [] where package.package == lowerIdentifier {
            return package
        }
        return nil
    }
    
    public func installedPackage(identifier: String) -> Package? {
        let lowerIdentifier = identifier.lowercased()
        for package in installedPackages ?? [] where package.package == lowerIdentifier {
            return package
        }
        return nil
    }
    
    public func package(url: URL) -> Package? {
        let canonicalPath = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
        let filePath = canonicalPath ?? url.path
        return newestPackage(identifier: filePath)
    }
    
    public func packages(identifiers: [String], sorted: Bool) -> [Package] {
        let loadIdentifier = "idents: ".appending(identifiers.joined(separator: " "))
        guard let rawPackages = self.packagesList(loadIdentifier: loadIdentifier, repoContext: nil) else {
            return []
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
    
    @objc public func markUpgradeAll(_ sender: Any) {
        let availableUpdates = self.availableUpdates()
        for packageTuple in availableUpdates {
            let package = packageTuple.0
            guard let installedPackage = packageTuple.1 else {
                continue
            }
            if installedPackage.wantInfo == .install || installedPackage.wantInfo == .unknown {
                DownloadManager.shared.add(package: package, queue: .upgrades)
            }
        }
        DownloadManager.shared.reloadData(recheckPackages: true)
    }
}
