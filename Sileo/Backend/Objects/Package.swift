//
//  Package.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

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
    public var essential: String?
    public var commercial: Bool = false
    public var installedSize: Int?
    public var tags: PackageTags = .none
    public var nativeDepiction: String?
    
    public var allVersionsInternal = [String: PackageOld]()
    public var allVersions: [Package] {
        var allVersionsInternal = allVersionsInternal.map { $1.packageNew }
        allVersionsInternal.insert(self, at: 0)
        return allVersionsInternal
    }
    
    public var fromStatusFile: Bool = false
    public var wantInfo: pkgwant = .unknown
    public var eFlag: pkgeflag = .ok
    public var status: pkgstatus = .installed
    
    public var filename: String?
    public var size: String?
    public var packageFileURL: URL?
    public var userRead = false
    
    var sourceRepo: Repo? {
        guard let sourceFileSafe = sourceFile else {
            return nil
        }
        return RepoManager.shared.repo(withSourceFile: sourceFileSafe)
    }
    
    var guid: String {
        String(format: "%@|-|%@", package, version)
    }
    
    init(package: String, version: String) {
        self.package = package
        self.packageID = package
        self.version = version
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(package)
        hasher.combine(version)
    }
    
    public func hasIcon() -> Bool {
        icon?.isEmpty == false
    }
    
    public func addOld(_ packages: [Package]) {
        for package in packages {
            let packageOld = PackageOld(package: package)
            allVersionsInternal[packageOld.version] = packageOld
        }
    }
    
    public func addOldInternal(_ packages: [PackageOld]) {
        for package in packages {
            allVersionsInternal[package.version] = package
        }
    }
    
    public func getVersion(_ version: String) -> Package? {
        if version == self.version { return self }
        if let package = allVersionsInternal[version] {
            return package.packageNew
        }
        return nil
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
    public var essential: String?
    public var commercial: Bool = false
    public var filename: String?
    public var size: String?
    public var packageFileURL: URL?
    public var architecture: String?
    public var installedSize: Int?
    public var author: String?
    public var maintainer: String?
    public var nativeDepiction: String?
    
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
        self.essential = package.essential
        self.commercial = package.commercial
        self.filename = package.filename
        self.size = package.size
        self.packageFileURL = package.packageFileURL
        self.architecture = package.architecture
        self.installedSize = package.installedSize
        self.author = package.author
        self.maintainer = package.maintainer
        self.nativeDepiction = package.nativeDepiction
    }
    
    public var packageNew: Package {
        let package = Package(package: self.package, version: self.version)
        package.sourceFile = self.sourceFile
        package.name = self.name
        package.rawControl = self.rawControl
        package.rawData = self.rawData
        package.sourceFileURL = self.sourceFileURL
        package.source = self.source
        package.essential = self.essential
        package.commercial = self.commercial
        package.filename = self.filename
        package.size = self.size
        package.packageFileURL = self.packageFileURL
        package.architecture = self.architecture
        package.installedSize = self.installedSize
        package.maintainer = self.maintainer
        package.author = self.author
        package.nativeDepiction = self.nativeDepiction
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
