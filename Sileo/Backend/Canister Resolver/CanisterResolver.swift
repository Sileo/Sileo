//
//  CanisterResolver.swift
//  Sileo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation
// import DepictionKit
import Evander

final class CanisterResolver {
    
    public static let nistercanQueue = DispatchQueue(label: "Sileo.NisterCan", qos: .userInteractive)
    public static let shared = CanisterResolver()
    public var packages = SafeArray<ProvisionalPackage>(queue: canisterQueue, key: queueKey, context: queueContext)
    private var cachedQueue = SafeArray<Package>(queue: canisterQueue, key: queueKey, context: queueContext)
    private var savedSearch = [String]()
    
    static let canisterQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "Sileo.CanisterQueue", qos: .userInitiated)
        queue.setSpecific(key: CanisterResolver.queueKey, value: CanisterResolver.queueContext)
        return queue
    }()
    public static let queueKey = DispatchSpecificKey<Int>()
    public static var queueContext = 50
    
    let filteredRepos = [
        "apt.elucubratus.com",
        "test.apt.bingner.com",
        "apt.bingner.com",
        "apt.procurs.us",
        "apt.saurik.com",
        "repo.theodyssey.dev",
        "repo.chimera.sh"
    ]

    @discardableResult public func fetch(_ query: String, fetch: ((Bool) -> Void)? = nil) -> Bool {
        #if targetEnvironment(macCatalyst)
        fetch?(false); return false
        #endif
        guard UserDefaults.standard.optionalBool("ShowProvisional", fallback: true) else { fetch?(false); return false }
        guard query.count > 3,
           !savedSearch.contains(query),
           let formatted = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { fetch?(false); return false }
        let url = "https://api.canister.me/v2/jailbreak/package/search?q=\(formatted)"
        EvanderNetworking.request(url: url, type: [String: Any].self, cache: .init(localCache: false)) { [self] success, _, _, dict in
            guard success,
                  let dict = dict,
                  let data = dict["data"] as? [[String: Any]] else { return }
            self.savedSearch.append(query)
            var change = false
            for entry in data {
                print(entry)
                guard let package = ProvisionalPackage(entry) else {
                    continue
                }
                if !self.packages.contains(where: { $0.identifier == package.identifier }) && !self.filteredRepos.contains(package.repo ?? "") {
                    change = true
                    self.packages.append(package)
                }
            }
            
            fetch?(change)
        }
        return true
    }
    
    @discardableResult public func batchFetch(_ packages: [String], fetch: ((Bool) -> Void)? = nil) -> Bool {
        #if targetEnvironment(macCatalyst)
        fetch?(false); return false
        #endif
        var packages = packages
        for package in packages {
            if savedSearch.contains(package) {
                packages.removeAll { package == $0 }
            }
        }
        if packages.isEmpty { fetch?(false); return false }
        let identifiers = packages.joined(separator: ",")
        guard let formatted = identifiers.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { fetch?(false); return false }
        let url = "https://api.canister.me/v2/jailbreak/package/multi?ids=\(formatted)"
        EvanderNetworking.request(url: url, type: [String: Any].self, cache: .init(localCache: false)) { [self] success, _, _, dict in
            guard success,
                  let dict = dict,
                  let data = dict["data"] as? [[String: Any]] else { return }
            self.savedSearch += packages
            var change = false
            for entry in data {
                guard let package = ProvisionalPackage(entry) else { continue }
                if !self.packages.contains(where: { $0.identifier == package.identifier }) && !self.filteredRepos.contains(package.repo ?? "") {
                    change = true
                    self.packages.append(package)
                }
            }
            fetch?(change)
        }
        return true
    }
    
    class public func piracy(_ urls: [URL], response: @escaping (_ safe: [URL], _ piracy: [URL]) -> Void) {
        var url = "https://api.canister.me/v2/jailbreak/repository/safety?uris="
        for (index, url2) in urls.enumerated() {
            let suffix = (index == urls.count - 1) ? "" : ","
            url += (url2.absoluteString  + suffix)
        }
        EvanderNetworking.request(url: url, type: [String: Any].self, cache: .init(localCache: false)) { success, _, _, dict in
            guard success,
                  let dict = dict,
                  let data = dict["data"] as? [[String: Any]] else {
                return response(urls, [URL]())
            }
            var safe = [URL]()
            var piracy = [URL]()
            for repo in data {
                guard let repoURI = repo["uri"] as? String,
                      let url3 = URL(string: repoURI) else {
                    continue
                }
                if repo["safe"] as? Bool == true {
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
    
    public func queueCache() {
        let plm = PackageListManager.shared
        var buffer = 0
        var refreshLists = false
        for (index, package) in cachedQueue.enumerated() {
            if let pkg = plm.package(identifier: package.packageID, version: package.version) ?? plm.newestPackage(identifier: package.packageID, repoContext: nil) {
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
            DownloadManager.shared.reloadData(recheckPackages: true)
        }
    }
    
    public class func package(_ provisional: ProvisionalPackage) -> Package? {
        guard let identifier = provisional.identifier else { return nil }
        let package = Package(package: identifier, version: provisional.version ?? "Unknown")
        package.name = provisional.name
        package.source = provisional.repo
        package.icon = provisional.icon
        package.packageDescription = provisional.description
        package.author = provisional.author
        package.depiction = provisional.depiction
        package.legacyDepiction = provisional.legacyDepiction
        package.isProvisional = true
        package.rawSection = provisional.section
        package.section = PackageListManager.humanReadableCategory(package.rawSection)
        return package
    }
    
    public func package(for bundleID: String) -> Package? {
        
        let temp = packages.filter { $0.identifier == bundleID }
        var buffer: Package?
        for provis in temp {
            guard let package = CanisterResolver.package(provis) else { continue }
            if let contained = buffer {
                if DpkgWrapper.isVersion(package.version, greaterThan: contained.version) {
                    buffer = package
                }
            } else {
                buffer = package
            }
        }
        return buffer
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
    var depictionV2: String?
    var section: String?
    
    init?(_ entry: [String: Any]) {
        self.name = entry["name"] as? String
        
        if let repo = entry["repository"] as? [String: Any],
           let url = repo["uri"] as? String {
            self.repo = url
        } else {
            return nil
        }
        if CanisterResolver.shared.filteredRepos.contains(where: { (self.repo?.contains($0) ?? false) }) { return nil }
        self.identifier = entry["package"] as? String
        self.icon = entry["icon"] as? String
        self.description = entry["description"] as? String
        self.depiction = entry["sileoDepiction"] as? String
        self.depictionV2 = entry["nativeDepiction"] as? String
        self.legacyDepiction = entry["depiction"] as? String
        if var author = entry["author"] as? String,
           let range = author.range(of: "<") {
            author.removeSubrange(range.lowerBound..<author.endIndex)
            if author.last == " " { author = String(author.dropLast()) }
            self.author = author
        } else if let author = entry["author"] as? String {
            self.author = author
        } else if var maintainer = entry["maintainer"] as? String,
                  let range = maintainer.range(of: "<") {
            maintainer.removeSubrange(range.lowerBound..<maintainer.endIndex)
            if maintainer.last == " " { maintainer = String(maintainer.dropLast()) }
            self.author = maintainer
        } else if let maintainer = entry["maintainer"] as? String {
            self.author = maintainer
        } else {
            self.author = "Unknown"
        }
        self.version = entry["version"] as? String
        self.section = entry["section"] as? String
    }
    
    /*
    init(package: DepictionPackage) {
        self.name = package.name
        self.repo = package.repo_link.absoluteString
        self.icon = package.icon?.absoluteString
        self.author = package.author
        self.identifier = package.identifier
        self.description = repo
    }
    */
    public var defaultIcon: UIImage {
        if let section = section {
            // we have to do this because some repos have various Addons sections
            // ie, Addons (activator), Addons (youtube), etc
            if section.lowercased().contains("addons") {
                return UIImage(named: "Category_addons") ?? UIImage(named: "Category_tweak")!
            } else if section.lowercased().contains("themes") {
                // same case for themes
                return UIImage(named: "Category_themes") ?? UIImage(named: "Category_tweak")!
            }
            
            return UIImage(named: "Category_\(section.lowercased())") ?? UIImage(named: "Category_tweak")!
        }
        return UIImage(named: "Category_tweak")!
    }
}

