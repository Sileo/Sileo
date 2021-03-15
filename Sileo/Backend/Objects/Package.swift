//
//  Package.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

final class Package: Hashable, Equatable {
    public var package: String
    public var packageID: String
    public var name: String?
    public var version: String
    public var architecture: String?
    public var author: String?
    public var maintainer: String?
    public var section: String?
    public var packageDescription: String?
    public var legacyDepiction: String?
    public var depiction: String?
    public var icon: String?
    public var sourceFile: String?
    public var sourceFileURL: URL?
    public var rawControl: [String: String] = [:]
    public var rawData: Data?
    public var essential: Bool = false
    public var commercial: Bool = false
    public var tags: PackageTags = .none
    
    public var allVersionsInternal: PackageVersionList = PackageVersionList()
    public var allVersions: [Package] {
        allVersionsInternal.list
    }
    
    public var fromStatusFile: Bool = false
    public var wantInfo: pkgwant = .unknown
    public var eFlag: pkgeflag = .ok
    public var status: pkgstatus = .installed
    
    public var filename: String?
    public var size: String?
    
    public var packageFileURL: URL?
    
    public var userReadDate: Date?
    
    public func hasIcon() -> Bool {
        icon?.isEmpty == false
    }
    
    var sourceRepo: Repo? {
        guard let sourceFileSafe = sourceFile else {
            return nil
        }
        return RepoManager.shared.repo(withSourceFile: sourceFileSafe)
    }
    
    var guid: String {
        String(format: "%@|-|%@", package, version)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(package)
        hasher.combine(version)
    }
    
    init(package: String, version: String) {
        self.package = package
        self.packageID = package
        self.version = version
    }
}

func == (lhs: Package, rhs: Package) -> Bool {
    lhs.package == rhs.package && lhs.version == rhs.version
}
