//
//  DependencyResolverAccelerator.swift
//  Sileo
//
//  Created by CoolStar on 1/19/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation

class DependencyResolverAccelerator {
    public static let shared = DependencyResolverAccelerator()
    private var partialRepoList: [URL: Set<Package>] = [:]
    private var packageList: Set<Package> = []
    private var preflightedRepos = false
    
    public func preflightInstalled() {
        if Thread.isMainThread {
            fatalError("Don't call things that will block the UI from the main thread")
        }
       
        partialRepoList = [:]
        try? getDependencies(packages: Array(PackageListManager.shared.installedPackages.values))
        preflightedRepos = true
    }
    
    private var depResolverPrefix: URL {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let listsURL = FileManager.default.documentDirectory.appendingPathComponent("sileolists")
        if !listsURL.dirExists {
            try? FileManager.default.createDirectory(at: listsURL, withIntermediateDirectories: true)
        }
        return listsURL
        #else
        return URL(fileURLWithPath: CommandPath.sileolists)
        #endif
    }
    
    public func getDependencies(packages: [Package]) throws {
        if Thread.isMainThread {
            fatalError("Don't call things that will block the UI from the main thread")
        }
        PackageListManager.shared.initWait()

        for package in packages {
            getDependenciesInternal2(package: package)
        }
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        #else
        spawnAsRoot(args: [CommandPath.rm, "-rf", CommandPath.sileolists])
        spawnAsRoot(args: [CommandPath.mkdir, "-p", CommandPath.sileolists])
        spawnAsRoot(args: [CommandPath.chown, "-R", CommandPath.group, CommandPath.sileolists])
        spawnAsRoot(args: [CommandPath.chmod, "-R", "0755", CommandPath.sileolists])
        #endif
        let resolverPrefix = depResolverPrefix
        for (sourcesFile, packages) in partialRepoList {
            if sourcesFile.lastPathComponent == "status" {
                continue
            }
            let newSourcesFile = resolverPrefix.appendingPathComponent(sourcesFile.lastPathComponent)
            
            var sourcesData = Data()
            for package in packages {
                guard let packageData = package.rawData else {
                    continue
                }
                var string = String(decoding: packageData, as: UTF8.self)
                if string.suffix(2) != "\n\n" {
                    if string.last == "\n" {
                        string += "\n"
                    } else {
                        string += "\n\n"
                    }
                }
                guard let data = string.data(using: .utf8) else { continue }
                sourcesData.append(data)
            }
            do {
                try sourcesData.write(to: newSourcesFile.aptUrl)
            } catch {
                throw error
            }
        }
    }
    
    private func getDependenciesInternal(package: Package) {
        for packageVersion in package.allVersions {
            getDependenciesInternal2(package: packageVersion)
        }
    }
   
    private func getDependenciesInternal2(package: Package) {
        guard let sourceFileURL = package.sourceFileURL?.aptUrl else {
            return
        }
        if partialRepoList[sourceFileURL] == nil {
            partialRepoList[sourceFileURL] = Set<Package>()
        }
        if partialRepoList[sourceFileURL]?.contains(package) ?? false {
            return
        }
        partialRepoList[sourceFileURL]?.insert(package)
        
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
