//
//  DatabaseManager.swift
//  Sileo
//
//  Created by Andromeda on 8/17/20.
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
    
    private var packages = ContiguousArray<Package>()
    private var updateQueue: DispatchQueue = DispatchQueue(label: "org.coolstar.SileoStore.news-seen-update")
    
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
            _ = try? database.run("DROP table Packages")
        } else if self.schemaVersion < DatabaseSchemaVersion.version02000.rawValue {
            _ = try? database.run("DROP table NewsArticle")
            _ = try? database.run("DROP table PackageStub")
        }
        self.schemaVersion = Int32(DatabaseSchemaVersion.version02111.rawValue)
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
    
    public func addToSaveQueue(packages: [Package]) {
        self.packages += packages
    }
    
    public func saveQueue() {
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
        
        try? database.transaction {
            for tmp in packages {
                let stub = PackageStub(from: tmp)
                let count = try? database.scalar(table.filter(guid == stub.guid).count)
                guard count ?? 0 == 0 else { continue }
                _ = try? database.run(table.insert(
                    guid <- "\(stub.package)-\(stub.version)",
                    package <- stub.package,
                    version <- stub.version,
                    firstSeen <- firstSeenLocal,
                    userRead <- stub.userReadDate ?? 0,
                    repoURL <- stub.repoURL
                ))
            }
        }
        packages.removeAll()
    }
    
    public func saveStubs(stubs: [PackageStub]) {
        if stubs.isEmpty { return }
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let repoURL = Expression<String>("repoURL")
        let table = Table("Packages")

        try? database.transaction {
            for stub in stubs {
                let count = try? database.scalar(table.filter(guid == stub.guid).count)
                guard count ?? 0 == 0 else { continue }
                _ = try? database.run(table.insert(
                    guid <- "\(stub.package)-\(stub.version)",
                    package <- stub.package,
                    version <- stub.version,
                    firstSeen <- Int64(stub.firstSeenDate.timeIntervalSince1970),
                    userRead <- stub.userReadDate ?? 0,
                    repoURL <- stub.repoURL
                ))
            }
        }
    }
    
    public func stubsAtTimestamp(_ timestamp: Int64) -> [PackageStub] {
        let database = self.database
        let guid = Expression<String>("guid")
        let package = Expression<String>("package")
        let version = Expression<String>("version")
        let firstSeen = Expression<Int64>("firstSeen")
        let userRead = Expression<Int64>("userRead")
        let repoURL = Expression<String>("repoURL")
        let packages = Table("Packages")
        
        var stubs: [PackageStub] = []
        
        do {
            let query = packages.select(guid,
                                        package,
                                        version,
                                        firstSeen,
                                        userRead,
                                        repoURL)
                .filter(firstSeen == timestamp)
            for stub in try database.prepare(query) {
                let stubObj = PackageStub(packageName: stub[package], version: stub[version], source: stub[repoURL])
                stubObj.firstSeenDate = Date(timeIntervalSince1970: TimeInterval(stub[firstSeen]))
                stubObj.firstSeen = stub[firstSeen]
                stubObj.repoURL = stub[repoURL]
                stubObj.userReadDate = stub[userRead]
                stubs.append(stubObj)
            }
        } catch {
            
        }
        return stubs
    }
    
    public func markAsSeen(_ dataPackage: Package) {
        updateQueue.async {
            let database = self.database
            let packages = Table("Packages")
            let package = Expression<String>("package")
            let userRead = Expression<Int64>("userRead")
            
            let stub = packages.filter(package == dataPackage.packageID)
            do {
                try database.run(stub.update(userRead <- 1))
            } catch {
                
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
