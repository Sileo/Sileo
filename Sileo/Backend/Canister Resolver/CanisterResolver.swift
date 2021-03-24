//
//  CanisterResolver.swift
//  Sileo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import Foundation

final class CanisterResolver {
    
    public static let shared = CanisterResolver()
    public var packages = [ProvisionalPackage]()
    
    public func fetch(_ query: String, fetch: @escaping () -> Void) {
        let url = "https://api.canister.me/v1/lookup/packages?query=\(query)&fields=id,name,description,icon,repository,author"
        AmyNetworkResolver.request(url: url, method: "GET") { success, dict in
            guard success,
                  let dict = dict,
                  dict["message"] as? String == "Successful",
                  let data = dict["data"] as? [[String: Any]] else { return fetch() }
            for entry in data {
                var package = ProvisionalPackage()
                package.name = entry["name"] as? String
                package.repo = entry["repository"] as? String
                package.identifier = entry["identifier"] as? String
                package.icon = entry["icon"] as? String
                package.description = entry["description"] as? String
                package.author = entry["author"] as? String
                if !self.packages.contains(where: { $0.identifier == package.identifier }) {
                    self.packages.append(package)
                }
            }
            return fetch()
        }
    }
    
}

struct ProvisionalPackage {
    var name: String?
    var repo: String?
    var identifier: String?
    var icon: String?
    var description: String?
    var author: String?
}
