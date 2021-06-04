//
//  DatabaseManager.swift
//  Sileo
//
//  Created by CoolStar on 8/17/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation
import SQLite

enum DatabaseSchemaVersion: Int {
    case versionNil = 0
    case version01000 = 1
    case version01004 = 2
    case version02000 = 3
    case version02111 = 4
}

class DatabaseManager {
    static let shared = DatabaseManager()
    
    let database: Connection
    
    init() {
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
                fatalError("Unable to get Sileo container!")
        }
        let sileoURL = libraryURL.appendingPathComponent("Sileo")
        try? FileManager.default.createDirectory(at: sileoURL,
                                                 withIntermediateDirectories: true,
                                                 attributes: [
                                                    FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                                                 ])
        let databaseURL = sileoURL.appendingPathComponent("sileo.sqlite3")
        
        guard let database = try? Connection(databaseURL.path) else {
            fatalError("Database Connection failed")
        }
        self.database = database
        
        if self.schemaVersion < DatabaseSchemaVersion.version02111.rawValue { // 2.x database is not compatible with 1.x
            _ = try? database.run("DROP table NewsArticle")
            _ = try? database.run("DROP table PackageStub")
            _ = try? database.run("DROP table Packages")
            self.schemaVersion = Int32(DatabaseSchemaVersion.version02111.rawValue)
        }
        PackageStub.createTable(database: database)
    }
    
    private var schemaVersion: Int32 {
        // swiftlint:disable:next force_cast force_try
        get { Int32(try! database.scalar("PRAGMA user_version") as! Int64) }
        // swiftlint:disable:next force_try
        set { try! database.run("PRAGMA user_version = \(newValue)") }
    }
    
    public func serializePackages(_ packages: [Package]) -> Set<[String: String]> {
        Set(packages.map { ["package": $0.package, "version": $0.version] })
    }
    
    public func save(packages: [Package]) {
        if packages.isEmpty { return }
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let repoURL = Expression<String>("repoURL")
        let table = Table("Packages")
        
        let stubToCopy = PackageStub(from: packages[0])
        let firstSeenLocal = Int64(stubToCopy.firstSeenDate.timeIntervalSince1970)
        let userReadLocal = Int64(stubToCopy.userReadDate?.timeIntervalSince1970 ?? 0)
        
        try? database.transaction {
            for tmp in packages {
                let stub = PackageStub(from: tmp)
                let deleteQuery = table.filter(guid == "\(stub.package)-\(stub.version)")
                _ = try? database.run(deleteQuery.delete())
                _ = try? database.run(table.insert(
                    guid <- "\(stub.package)-\(stub.version)",
                    package <- stub.package,
                    version <- stub.version,
                    firstSeen <- firstSeenLocal,
                    userRead <- userReadLocal,
                    repoURL <- stub.repoURL
                ))
            }
        }
    }
    
    public func deleteRepo(repo: Repo) {
        let file = RepoManager.shared.cacheFile(named: "Packages", for: repo).lastPathComponent
        let repoURL = Expression<String>("repoURL")
        let packages = Table("Packages")
        _ = try? database.run(packages.filter(repoURL == file).delete())
    }
}
