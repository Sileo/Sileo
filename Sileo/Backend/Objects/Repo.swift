//
//  Repo.swift
//  Sileo
//
//  Created by CoolStar on 7/21/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

final class Repo: Equatable {
    var isSecure: Bool = false
    var isLoaded: Bool = false
    var isIconLoaded: Bool = false
    
    var repoName: String = ""
    var repoDescription: String = ""
    var rawEntry: String = ""
    var rawURL: String = ""
    var suite: String = ""
    var components: [String] = []
    var entryFile: String = ""
    var repoIcon: UIImage?
    var startedRefresh: Bool = false
    var releaseProgress = CGFloat(0)
    var releaseGPGProgress = CGFloat(0)
    var packagesProgress = CGFloat(0)
    
    var packages: [Package]?
    var packagesProvides: [Package]?
    var packagesDict: [String: Package]?
    
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
    
    var isFlat: Bool {
        suite.hasSuffix("/") || components.isEmpty
    }
}

func == (lhs: Repo, rhs: Repo) -> Bool {
    lhs.rawURL == rhs.rawURL && lhs.suite == rhs.suite
}
