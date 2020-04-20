//
//  DependencyResolverAccelerator.swift
//  Sileo
//
//  Created by CoolStar on 1/19/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class DependencyResolverAccelerator {
    public static let shared = DependencyResolverAccelerator()
    private var dependencyLock = DispatchSemaphore(value: 1)
    private var partialRepoList: [URL: Set<Package>] = [:]
    
    private var depResolverPrefix: URL {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        let listsURL = FileManager.default.documentDirectory.appendingPathComponent("sileolists")
        if !listsURL.dirExists {
            try? FileManager.default.createDirectory(at: listsURL, withIntermediateDirectories: true)
        }
        return listsURL
        #else
        return URL(fileURLWithPath: "/var/lib/apt/sileolists")
        #endif
    }
    
    public func getDependencies(install: [DownloadPackage], remove: [DownloadPackage]) {
        dependencyLock.wait()
        PackageListManager.shared.waitForReady()
        partialRepoList = [:]
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        #else
        spawnAsRoot(command: "mkdir -p /var/lib/apt/sileolists && chown -R mobile:mobile /var/lib/apt/sileolists && chmod -R 0755 /var/lib/apt/sileolists")
        #endif
        
        guard let filePaths = try? FileManager.default.contentsOfDirectory(at: depResolverPrefix, includingPropertiesForKeys: nil, options: []) else {
            return
        }
        for filePath in filePaths {
            try? FileManager.default.removeItem(at: filePath)
        }
        
        for package in install {
            getDependenciesInternal2(package: package.package)
        }
        
        for package in remove {
            getDependenciesInternal2(package: package.package)
        }
        
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
                sourcesData.append(packageData)
            }
            try? sourcesData.write(to: newSourcesFile)
        }
        
        partialRepoList.removeAll()
        dependencyLock.signal()
    }
    
    private func getDependenciesInternal(package: Package) {
        for packageVersion in package.allVersions {
            getDependenciesInternal2(package: packageVersion)
        }
    }
    
    private func getDependenciesInternal2(package: Package) {
        guard let sourceFileURL = package.sourceFileURL else {
            return
        }
        if partialRepoList[sourceFileURL] == nil {
            partialRepoList[sourceFileURL] = Set<Package>()
        }
        if partialRepoList[sourceFileURL]?.contains(package) ?? false {
            return
        }
        
        partialRepoList[sourceFileURL]?.insert(package)
        
        let packageKeys = ["depends", "pre-depends", "conflicts", "replaces"]
        
        for packageKey in packageKeys {
            if let packagesData = package.rawControl[packageKey] {
                let packageIds = parseDependsString(depends: packagesData)
                for packageId in packageIds {
                    for repo in RepoManager.shared.repoList {
                        if let depPackage = repo.packagesDict?[packageId] {
                            getDependenciesInternal(package: depPackage)
                        }
                        
                        for depPackage in repo.packagesProvides ?? [] {
                            if depPackage.rawControl["provides"]?.contains(packageId) ?? false {
                                getDependenciesInternal(package: depPackage)
                            }
                        }
                    }
                    
                    for depPackage in PackageListManager.shared.installedPackages ?? [] {
                        if depPackage.packageID == packageId ||
                            depPackage.rawControl["provides"]?.contains(packageId) ?? false {
                            getDependenciesInternal(package: depPackage)
                        }
                        
                        for key in packageKeys {
                            if depPackage.rawControl[key]?.contains(packageId) ?? false {
                                getDependenciesInternal(package: depPackage)
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
