//
//  CanisterResolver.swift
//  Sileo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation

final class CanisterResolver {
    
    static let RepoRefresh = Notification.Name("SileoRepoDidFinishUpdating")
    public static let shared = CanisterResolver()
    public var packages = [ProvisionalPackage]()
    private var cachedQueue = [Package]()
    
    let filteredRepos = [
        "apt.elucubratus.com",
        "test.apt.bingner.com",
        "apt.bingner.com",
        "apt.procurs.us",
        "apt.saurik.com",
        "repo.theodyssey.dev"
    ]
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(CanisterResolver.queueCache),
                                               name: CanisterResolver.RepoRefresh,
                                               object: nil)
    }
    
    public func fetch(_ query: String, fetch: @escaping () -> Void) {
        if query.count <= 3 { return fetch() }
        let url = "https://api.canister.me/v1/community/packages/search?query=\(query)&searchFields=packageId,name,author,maintainer&responseFields=packageId,name,description,icon,repositoryURI,author,latestVersion,nativeDepiction,depiction"
        AmyNetworkResolver.dict(url: url) { success, dict in
            guard success,
                  let dict = dict,
                  dict["status"] as? String == "Successful",
                  let data = dict["data"] as? [[String: Any]] else { return fetch() }
            for entry in data {
                var package = ProvisionalPackage()
                package.name = entry["name"] as? String
                package.repo = entry["repositoryURI"] as? String
                if self.filteredRepos.contains(where: { (package.repo?.contains($0) ?? false) }) { continue }
                package.identifier = entry["packageId"] as? String
                package.icon = entry["icon"] as? String
                package.description = entry["description"] as? String
                package.depiction = entry["nativeDepiction"] as? String
                package.legacyDepiction = entry["depiction"] as? String
                if var author = entry["author"] as? String,
                   let range = author.range(of: "<") {
                    author.removeSubrange(range.lowerBound..<author.endIndex)
                    if author.last == " " { author = String(author.dropLast()) }
                    package.author = author
                } else {
                    package.author = entry["author"] as? String
                }
                package.version = entry["latestVersion"] as? String
                if !self.packages.contains(where: { $0.identifier == package.identifier }) && !self.filteredRepos.contains(package.repo ?? "") {
                    self.packages.append(package)
                }
            }
            
            return fetch()
        }
    }
    
    class private func piracy(_ url: URL, response: @escaping (_ safe: [URL], _ piracy: [URL]) -> Void) {
        let url2 = "https://api.canister.me/v1/community/repositories/check?query=\(url.absoluteString)"
        AmyNetworkResolver.dict(url: url2) { success, dict in
            guard success,
                  let dict = dict,
                  (dict["status"] as? String) == "Successful",
                  let data = dict["data"] as? [String: String],
                  let repoURI = data["repositoryURI"],
                  let url3 = URL(string: repoURI) else {
                return response([url], [URL]())
            }
            let safe = data["status"] == "safe"
            if !safe {
                return response([URL](), [url3])
            }
            return response([url3], [URL]())
        }
    }
    
    class public func piracy(_ urls: [URL], response: @escaping (_ safe: [URL], _ piracy: [URL]) -> Void) {
        if urls.count == 1 {
            CanisterResolver.piracy(urls[0]) { safe, piracy in
                response(safe, piracy)
            }
            return
        }
        var url = "https://api.canister.me/v1/community/repositories/check?queries="
        for (index, url2) in urls.enumerated() {
            let suffix = (index == urls.count - 1) ? "" : ","
            url += (url2.absoluteString  + suffix)
        }
        AmyNetworkResolver.dict(url: url) { success, dict in
            guard success,
                  let dict = dict,
                  (dict["status"] as? String) == "Successful",
                  let data = dict["data"] as? [[String: String]] else {
                return response(urls, [URL]())
            }
            var safe = [URL]()
            var piracy = [URL]()
            for repo in data {
                guard let repoURI = repo["repositoryURI"],
                      let url3 = URL(string: repoURI) else {
                    continue
                }
                if repo["status"] == "safe" {
                    safe.append(url3)
                } else {
                    piracy.append(url3)
                }
            }
            return response(safe, piracy)
        }
    }
    
    public func queuePackage(_ package: Package) {
        cachedQueue.removeAll { $0.packageID == package.packageID }
        cachedQueue.append(package)
    }
    
    @objc private func queueCache() {
        let plm = PackageListManager.shared
        var buffer = 0
        var refreshLists = false
        for (index, package) in cachedQueue.enumerated() {
            if let pkg = plm.package(identifier: package.packageID, version: package.version) ?? plm.newestPackage(identifier: package.packageID) {
                let queueFound = DownloadManager.shared.find(package: pkg)
                if queueFound == .none {
                    DownloadManager.shared.add(package: pkg, queue: .installations)
                }
                cachedQueue.remove(at: index - buffer)
                buffer += 1
                self.packages.removeAll(where: { $0.identifier == package.packageID })
                refreshLists = true
            }
        }
        if refreshLists {
            NotificationCenter.default.post(name: CanisterResolver.refreshList, object: nil)
        }
    }
    
    public class func package(_ provisional: ProvisionalPackage) -> Package? {
        guard let identifier = provisional.identifier,
              let version = provisional.version else { return nil }
        let package = Package(package: identifier, version: version)
        package.name = provisional.name
        package.source = provisional.repo
        package.icon = provisional.icon
        package.packageDescription = provisional.description
        package.author = provisional.author
        package.depiction = provisional.depiction
        package.legacyDepiction = provisional.legacyDepiction
        package.isProvisional = true
        return package
    }
    
    static let refreshList = Notification.Name("Canister.RefreshList")
}

struct ProvisionalPackage {
    var name: String?
    var repo: String?
    var identifier: String?
    var icon: String?
    var description: String?
    var author: String?
    var version: String?
    var legacyDepiction: String?
    var depiction: String?
}
