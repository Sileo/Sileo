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
    public var source: String?
    public var isProvisional: Bool?
    public var sourceFileURL: URL?
    public var rawControl: [String: String] = [:]
    public var rawData: Data?
    public var essential: Bool = false
    public var commercial: Bool = false
    public var tags: PackageTags = .none
    
    public var allVersionsInternal = [PackageOld]()
    public func addOld(_ packages: [Package]) {
        for package in packages {
            let packageOld = PackageOld(package: package)
            allVersionsInternal.removeAll(where: { packageOld == $0 })
            allVersionsInternal.append(packageOld)
        }
    }
    public var allVersions: [Package] {
        return allVersionsInternal.map({ $0.packageNew })
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

final class PackageOld: Hashable, Equatable {
 
    public var sourceFile: String?
    public var package: String
    public var packageID: String
    public var name: String?
    public var version: String
    public var rawControl: [String: String] = [:]
    public var rawData: Data?
    public var sourceFileURL: URL?
    public var source: String?
    public var commercial: Bool = false
    public var filename: String?
    public var size: String?
    public var packageFileURL: URL?
    public var architecture: String?
    
    init(package: Package) {
        self.sourceFile = package.sourceFile
        self.package = package.package
        self.packageID = package.packageID
        self.name = package.name
        self.version = package.version
        self.rawControl = package.rawControl
        self.rawData = package.rawData
        self.sourceFileURL = package.sourceFileURL
        self.source = package.source
        self.commercial = package.commercial
        self.filename = package.filename
        self.size = package.size
        self.packageFileURL = package.packageFileURL
        self.architecture = package.architecture
    }
    
    public var packageNew: Package {
        let package = Package(package: self.package, version: self.version)
        package.sourceFile = self.sourceFile
        package.name = self.name
        package.rawControl = self.rawControl
        package.rawData = self.rawData
        package.sourceFileURL = self.sourceFileURL
        package.source = self.source
        package.commercial = self.commercial
        package.filename = self.filename
        package.size = self.size
        package.packageFileURL = self.packageFileURL
        package.architecture = self.architecture
        return package
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(package)
        hasher.combine(version)
    }
}

func == (lhs: PackageOld, rhs: PackageOld) -> Bool {
    lhs.package == rhs.package && lhs.version == rhs.version
}
