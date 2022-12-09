//
//  DependencyResolverAccelerator.swift
//  Sileo
//
//  Created by CoolStar on 1/19/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class DependencyResolverAccelerator {
    public static let shared = DependencyResolverAccelerator()
    private var preflightedRepos = false
    
    struct PreflightedPackage: Hashable {
        let version: String
        let bundleID: String
        let data: Data
        
        init(package: Package) {
            self.version = package.version
            self.bundleID = package.packageID
            self.data = package.rawData ?? Data()
        }
        
        static func ==(lhs: PreflightedPackage, rhs: PreflightedPackage) -> Bool {
            lhs.version == rhs.version && lhs.bundleID == rhs.bundleID
        }
        
        static func ==(lhs: PreflightedPackage, rhs: Package) -> Bool {
            lhs.bundleID == rhs.packageID && lhs.version == rhs.version
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleID)
            hasher.combine(version)
        }
    }
    
    private var preflightedPackages: [URL: Set<PreflightedPackage>] = [:]
    private var toBePreflighted: [URL: Set<PreflightedPackage>] = [:]
    
    public func preflightInstalled() {
        if Thread.isMainThread {
            fatalError("Don't call things that will block the UI from the main thread")
        }
       
        try? getDependencies(packages: Array(PackageListManager.shared.installedPackages.values))
        preflightedRepos = true
    }
    
    private var depResolverPrefix: URL = {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let listsURL = FileManager.default.documentDirectory.appendingPathComponent("sileolists")
        if !listsURL.dirExists {
            try? FileManager.default.createDirectory(at: listsURL, withIntermediateDirectories: true)
        }
        return listsURL
        #else
        return URL(fileURLWithPath: CommandPath.sileolists)
        #endif
    }()
    
    init() {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        try? FileManager.default.removeItem(atPath: CommandPath.sileolists)
        #else
        spawnAsRoot(args: [CommandPath.rm, "-rf", CommandPath.sileolists])
        spawnAsRoot(args: [CommandPath.mkdir, "-p", CommandPath.sileolists])
        spawnAsRoot(args: [CommandPath.chown, "-R", CommandPath.group, CommandPath.sileolists])
        spawnAsRoot(args: [CommandPath.chmod, "-R", "0755", CommandPath.sileolists])
        #endif
    }
    
    public func removeRepo(repo: Repo) {
        let url = RepoManager.shared.cacheFile(named: "Packages", for: repo)
        let newSourcesFile = depResolverPrefix.appendingPathComponent(url.lastPathComponent)
        toBePreflighted.removeValue(forKey: url)
        preflightedPackages.removeValue(forKey: url)
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        try? FileManager.default.removeItem(at: newSourcesFile)
        #else
        spawnAsRoot(args: [CommandPath.rm, "-rf", newSourcesFile.aptPath])
        #endif
    }
    
    public func getDependencies(packages: [Package]) throws {
        if Thread.isMainThread {
            fatalError("Don't call things that will block the UI from the main thread")
        }
        PackageListManager.shared.initWait()

        for package in packages {
            getDependenciesInternal(package: package)
        }
        
        let resolverPrefix = depResolverPrefix
        for (sourcesFile, packages) in toBePreflighted {
            if sourcesFile.lastPathComponent == "status" || sourcesFile.scheme == "local" {
                continue
            }
            let newSourcesFile = resolverPrefix.appendingPathComponent(sourcesFile.lastPathComponent)
            
            var sourcesData = Data()
            for package in packages {
                var bytes = [UInt8](package.data)
                if bytes.suffix(2) != [10, 10] { // \n\n
                    if bytes.last == 10 {
                        bytes.append(10)
                    } else {
                        bytes.append(contentsOf: [10, 10])
                    }
                }
                sourcesData.append(Data(bytes))
            }
            do {
                try sourcesData.append(to: newSourcesFile.aptUrl)
            } catch {
                throw error
            }
            
            toBePreflighted.removeValue(forKey: sourcesFile)
            let preflighted = preflightedPackages[sourcesFile] ?? Set<PreflightedPackage>()
            preflightedPackages[sourcesFile] = preflighted.union(packages)
        }
    }
    
    private func getDependenciesInternal(package: Package) {
        let url = package.sourceFileURL?.aptUrl ?? URL(string: "local://")!
        if preflightedPackages[url]?.contains(where: { $0 == package }) ?? false {
            NSLog("[Sileo] Booping on \(package.package)")
            return
        }
        for packageVersion in package.allVersions {
            getDependenciesInternal2(package: packageVersion, sourceFileURL: url)
        }
    }
   
    private func getDependenciesInternal2(package: Package, sourceFileURL: URL) {

        if toBePreflighted[sourceFileURL]?.contains(where: { $0 == package }) ?? false {
            return
        } else if toBePreflighted[sourceFileURL] == nil {
            toBePreflighted[sourceFileURL] = Set<PreflightedPackage>()
        }
        toBePreflighted[sourceFileURL]?.insert(PreflightedPackage(package: package))
  
        // Depends, Pre-Depends, Recommends, Suggests, Breaks, Conflicts, Provides, Replaces, Enhance
        let packageKeys = ["depends", "pre-depends", "conflicts", "replaces", "recommends", "provides", "breaks"]
        
        for packageKey in packageKeys {
            if let packagesData = package.rawControl[packageKey] {
                let packageIds = parseDependsString(depends: packagesData)
                for repo in RepoManager.shared.repoList {
                    for packageID in packageIds {
                        if let depPackage = repo.packageDict[packageID] {
                            getDependenciesInternal(package: depPackage)
                        }
                    }
                    
                    for depPackage in repo.packagesProvides {
                        for packageId in packageIds {
                            if depPackage.rawControl["provides"]?.contains(packageId) ?? false {
                                getDependenciesInternal(package: depPackage)
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func parseDependsString(depends: String) -> [String] {
        let parts = depends.components(separatedBy: CharacterSet(charactersIn: ",|"))
        var packageIds: [String] = []
        for part in parts {
            let newPart = part.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression).replacingOccurrences(of: " ", with: "")
            packageIds.append(newPart)
        }
        return packageIds
    }
}
