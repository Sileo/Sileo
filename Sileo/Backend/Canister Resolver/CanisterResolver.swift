//
//  CanisterResolver.swift
//  Sileo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
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
        let url = "https://api.canister.me/v1/community/packages/search?query=\(query)&fields=identifier,name,description,icon,repository,author,version,depiction.native,depiction.web,&search_fields=identifier,name,author,maintainer"
        AmyNetworkResolver.request(url: url, method: "GET") { success, dict in
            guard success,
                  let dict = dict,
                  dict["message"] as? String == "Successful",
                  let data = dict["data"] as? [[String: Any]] else { return fetch() }
            for entry in data {
                var package = ProvisionalPackage()
                package.name = entry["name"] as? String
                package.repo = entry["repository"] as? String
                if self.filteredRepos.contains(where: { (package.repo?.contains($0) ?? false) }) { continue }
                package.identifier = entry["identifier"] as? String
                package.icon = entry["icon"] as? String
                package.description = entry["description"] as? String
                package.depiction = entry["sileo_depiction"] as? String
                package.legacyDepiction = entry["depiction"] as? String
                if var author = entry["author"] as? String,
                   let range = author.range(of: "<") {
                    author.removeSubrange(range.lowerBound..<author.endIndex)
                    if author.last == " " { author = String(author.dropLast()) }
                    package.author = author
                } else {
                    package.author = entry["author"] as? String
                }
                package.version = entry["version"] as? String
                if !self.packages.contains(where: { $0.identifier == package.identifier }) && !self.filteredRepos.contains(package.repo ?? "") {
                    self.packages.append(package)
                }
            }
            return fetch()
        }
    }
    
    public func piracy(_ url: URL, response: @escaping (_ piracy: Bool) -> Void) {
        let url = "https://api.canister.me/v1/community/repositories/check?query=\(url.absoluteString)"
        AmyNetworkResolver.request(url: url, method: "GET") { success, dict in
            
            guard success,
                  let dict = dict else { return response(false) }
            return response(dict["data"] as? String ?? "" == "pirated")
        }
    }
    
    public func queuePackage(_ package: Package) {
        cachedQueue.removeAll { $0.packageID == package.packageID }
        cachedQueue.append(package)
    }
    
    @objc private func queueCache() {
        let plm = PackageListManager.shared
        var buffer = 0
        for (index, package) in cachedQueue.enumerated() {
            if let pkg = plm.package(identifier: package.packageID, version: package.version) ?? plm.newestPackage(identifier: package.packageID) {
                let queueFound = DownloadManager.shared.find(package: pkg)
                if queueFound == .none {
                    DownloadManager.shared.add(package: pkg, queue: .installations)
                }
                cachedQueue.remove(at: index - buffer)
                buffer += 1
            }
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
