//
//  SourceLicense.swift
//  Sileo
//
//  Created by Jamie Bishop on 30/07/2019.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

struct LicenseFile: Decodable {
    static func licensesFrom(url: URL) -> [SourceLicense]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let file = try? PropertyListDecoder().decode(LicenseFile.self, from: data) else { return nil }
        return file.licenses
    }
    
    let licenses: [SourceLicense]
    
    enum CodingKeys: String, CodingKey {
        case licenses = "Licenses"
    }
}

struct SourceLicense: Decodable {
    let name: String
    let licenseText: String
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case licenseText = "LicenseText"
    }
}
