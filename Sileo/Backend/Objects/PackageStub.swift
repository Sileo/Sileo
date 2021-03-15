//
//  PackageStub.swift
//  Sileo
//
//  Created by CoolStar on 8/17/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation
import SQLite

class PackageStub {
    public var package: String
    public var version: String
    
    public var firstSeenDate = Date()
    public var userReadDate: Date?
    
    static func createTable(database: Connection) {
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let packages = Table("Packages")
        _ = try? database.run(packages.create(ifNotExists: true,
                                              block: { tbd in
                                                tbd.column(guid, primaryKey: true)
                                                tbd.column(package)
                                                tbd.column(version)
                                                tbd.column(firstSeen)
                                                tbd.column(userRead)
                                                tbd.unique(guid)
        }))
    }
    
    static func stubs(limit: Int, offset: Int) -> [PackageStub] {
        let database = DatabaseManager.shared.database
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let packages = Table("Packages")
        
        var stubs: [PackageStub] = []
        
        do {
            var query = packages.select(guid,
                                        package,
                                        version,
                                        firstSeen,
                                        userRead)
                .order(firstSeen.desc, package, version)
            if limit > 0 {
                query = query.limit(limit, offset: offset)
            }
            for stub in try database.prepare(query) {
                    let stubObj = PackageStub(packageName: stub[package], version: stub[version])
                    stubObj.firstSeenDate = Date(timeIntervalSince1970: TimeInterval(stub[firstSeen]))
                    if stub[userRead] != 0 {
                        stubObj.userReadDate = Date(timeIntervalSince1970: TimeInterval(stub[userRead]))
                    }
                    stubs.append(stubObj)
            }
        } catch {
            
        }
        return stubs
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
    
    static func delete(packageName: String) {
        let database = DatabaseManager.shared.database
        
        let package = Expression<String>("package")
        let packages = Table("Packages")
        _ = try? database.run(packages.filter(package == packageName).delete())
    }
    
    init(from package: Package) {
        self.package = package.package
        self.version = package.version
    }
    
    fileprivate init(packageName: String, version: String) {
        self.package = packageName
        self.version = version
    }
    
    func save() {
        let database = DatabaseManager.shared.database
        
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let packages = Table("Packages")
        
        let deleteQuery = packages.filter(guid == "\(self.package)-\(self.version)")
        _ = try? database.run(deleteQuery.delete())
        
        _ = try? database.run(packages.insert(
            guid <- "\(self.package)-\(self.version)",
            package <- self.package,
            version <- self.version,
            firstSeen <- Int64(firstSeenDate.timeIntervalSince1970),
            userRead <- Int64(userReadDate?.timeIntervalSince1970 ?? 0)))
    }
}
