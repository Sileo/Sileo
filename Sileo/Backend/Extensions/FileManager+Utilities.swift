//
//  URL+Utilities.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

extension FileManager {

    var documentDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension URL {

    var exists: Bool {
        FileManager.default.fileExists(atPath: aptPath)
    }

    var dirExists: Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func contents() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
    }

    var implicitContents: [URL] {
        (try? contents()) ?? []
    }

}
