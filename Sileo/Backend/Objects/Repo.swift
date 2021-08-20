//
//  Repo.swift
//  Sileo
//
//  Created by CoolStar on 7/21/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation

final class Repo: Equatable {
    var isSecure: Bool = false
    var isLoaded: Bool = false
    var isIconLoaded: Bool = false
    
    private var repoNameTmp: Bool = false
    var repoName: String = "" {
        willSet(set) {
            if repoName.isEmpty && !set.isEmpty {
                repoNameTmp = true
            }
        }
        didSet {
            if !repoNameTmp { return }
            repoNameTmp = false
            func reloadData() {
                guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController,
                    let sourcesSVC = tabBarController.viewControllers?[2] as? UISplitViewController,
                    let sourcesNavNV = sourcesSVC.viewControllers[0] as? SileoNavigationController,
                    let sourcesVC = sourcesNavNV.viewControllers[0] as? SourcesViewController else {
                    return
                }
                sourcesVC.reloadData()
            }
            if Thread.isMainThread {
                reloadData()
            } else {
                DispatchQueue.main.async {
                    reloadData()
                }
            }
        }
    }
    
    var packagesExist: Bool {
        FileManager.default.fileExists(atPath: RepoManager.shared.cacheFile(named: "Packages", for: self).aptPath)
    }
    
    var repoDescription: String = ""
    var rawEntry: String = ""
    var rawURL: String = ""
    var suite: String = ""
    var components: [String] = []
    var entryFile: String = ""
    var repoIcon: UIImage? {
        didSet {
            guard repoIcon != nil else { return }
            NotificationCenter.default.post(name: SourcesTableViewCell.repoImageUpdate, object: rawURL)
        }
    }
    var startedRefresh: Bool = false
    var releaseProgress = CGFloat(0)
    var releaseGPGProgress = CGFloat(0)
    var packagesProgress = CGFloat(0)

    var packageDict: [String: Package] = [:] {
        didSet {
            reloadInstalled()
            packagesProvides = Array(packageDict.values).filter { $0.rawControl["provides"] != nil }
        }
    }
    var packageArray: [Package] {
        Array(packageDict.values)
    }
    var packagesProvides = [Package]()
    var installed: [Package]?
    
    public func reloadInstalled() {
        if packageDict.isEmpty { installed = nil }
        let installed = Array(PackageListManager.shared.installedPackages.values)
        self.installed = installed.filter { installed -> Bool in
            guard let package = packageDict[installed.packageID] else { return false }
            if package.version == installed.version { return true }
            return DpkgWrapper.isVersion(package.version, greaterThan: installed.version)
        }
        NotificationCenter.default.post(name: RepoManager.progressNotification, object: self)
    }
    
    var releaseDict: [String: String]? {
        let releaseFile = RepoManager.shared.cacheFile(named: "Release", for: self)
        if let info = try? String(contentsOf: releaseFile),
           let release = try? ControlFileParser.dictionary(controlFile: info, isReleaseFile: true).0 {
            return release
        }
        return nil
    }
    
    var totalProgress: CGFloat {
        let startProgress: CGFloat = startedRefresh ? 0.1 : 0.0
        return (((releaseProgress + packagesProgress + releaseGPGProgress)/3.0) * 0.9) + startProgress
    }
    
    var displayName: String {
        if !repoName.isEmpty {
            return repoName
        }
        return NSLocalizedString("Untitled_Repo", comment: "")
    }
    
    var url: URL? {
        guard let rawURL = URL(string: rawURL) else {
            return nil
        }
        if isFlat {
            return suite == "./" ? rawURL : rawURL.appendingPathComponent(suite)
        } else {
            return rawURL.appendingPathComponent("dists").appendingPathComponent(suite)
        }
    }
    
    var repoURL: String {
        url?.absoluteString ?? ""
    }
    
    var displayURL: String {
        rawURL
    }
    
    var primaryComponentURL: URL? {
        if isFlat {
            return self.url
        } else {
            if components.isEmpty {
                return nil
            }
            return self.url?.appendingPathComponent(components[0])
        }
    }
    
    var isFlat: Bool {
        suite.hasSuffix("/") || components.isEmpty
    }
    
    func packagesURL(arch: String?) -> URL? {
        guard var packagesDir = primaryComponentURL else {
            return nil
        }
        if !isFlat,
            let arch = arch {
            packagesDir = packagesDir.appendingPathComponent("binary-".appending(arch))
        }
        return packagesDir.appendingPathComponent("Packages")
    }
}

func == (lhs: Repo, rhs: Repo) -> Bool {
    lhs.rawURL == rhs.rawURL && lhs.suite == rhs.suite
}
