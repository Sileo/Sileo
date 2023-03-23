//
//  PackageStub.swift
//  Sileo
//
//  Created by CoolStar on 8/17/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import SQLite

struct PackageStub: Codable {
    
    public var package: String
    public var version: String
    public var repoURL: String
    public var guid: String
    
    public var firstSeenDate = Date()
    public var userReadDate: Int64?
    public var firstSeen: Int64?
    
    static func createTable(database: Connection) {
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let repoURL = Expression<String>("repoURL")
        let packages = Table("Packages")
        _ = try? database.run(packages.create(ifNotExists: true,
                                              block: { tbd in
                                                tbd.column(guid, primaryKey: true)
                                                tbd.column(package)
                                                tbd.column(version)
                                                tbd.column(firstSeen)
                                                tbd.column(userRead)
                                                tbd.column(repoURL)
                                                tbd.unique(guid)
        }))
    }
    
    static func timestamps() -> [Int64] {
        let database = DatabaseManager.shared.database
        var timestamps: [Int64] = []
        let packages = Table("Packages")
        
        let firstSeen = Expression<Int64>("firstSeen")
        do {
            for stamps in try database.prepare(packages.select(firstSeen).select(distinct: firstSeen).order(firstSeen.desc)) {
                let stamp = stamps[firstSeen]
                timestamps.append(stamp)
            }
        } catch {
            
        }
        return timestamps
    }

    init(from package: Package) {
        self.package = package.package
        self.version = package.version
        self.repoURL = package.sourceFileURL?.lastPathComponent ?? "status"
        self.guid = "\(self.package)-\(self.version)"
    }
    
    public init(packageName: String, version: String, source: String) {
        self.package = packageName
        self.version = version
        self.repoURL = source
        self.guid = "\(self.package)-\(self.version)"
    }

}
