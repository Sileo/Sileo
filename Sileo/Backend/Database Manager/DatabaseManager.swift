//
//  DatabaseManager.swift
//  Sileo
//
//  Created by CoolStar on 8/17/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation
import SQLite

enum DatabaseSchemaVersion: Int {
    case versionNil = 0
    case version01000 = 1
    case version01004 = 2
    case version02000 = 3
}

class DatabaseManager {
    static let shared = DatabaseManager()
    
    let database: Connection
    let knownPackagesURL: URL
    
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
        knownPackagesURL = sileoURL.appendingPathComponent("knownPackages.json")
        
        print("Database URL: \(databaseURL)")
        
        guard let database = try? Connection(databaseURL.path) else {
            fatalError("Database Connection failed")
        }
        self.database = database
        
        if self.schemaVersion < DatabaseSchemaVersion.version02000.rawValue { //2.x db is not compatible with 1.x
            _ = try? database.run("DROP table NewsArticle")
            _ = try? database.run("DROP table PackageStub")
            self.schemaVersion = Int32(DatabaseSchemaVersion.version02000.rawValue)
        }
        
        PackageStub.createTable(database: database)
    }
    
    private var schemaVersion: Int32 {
        //swiftlint:disable:next force_cast force_try
        get { Int32(try! database.scalar("PRAGMA user_version") as! Int64) }
        //swiftlint:disable:next force_try
        set { try! database.run("PRAGMA user_version = \(newValue)") }
    }
    
    public func serializePackages(_ packages: [Package]) -> Set<[String: String]> {
        Set(packages.map { ["package": $0.package, "version": $0.version] })
    }
    
    public func knownPackages() -> Set<[String: String]> {
        if let data = try? Data(contentsOf: knownPackagesURL),
            let packages = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: String]] {
            return Set(packages)
        }
        return Set()
    }
    
    public func savePackages(_ packages: Set<[String: String]>) {
        let arr = Array(packages)
        if let jsonData = try? JSONSerialization.data(withJSONObject: arr, options: []) {
            try? jsonData.write(to: knownPackagesURL)
        }
    }
}
