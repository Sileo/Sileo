//
//  DPKGArchiecture.swift
//  Sileo
//
//  Created by Amy While on 20/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation


struct DPKGArchitecture {
    
    enum Architecture: String, Decodable {
        case rootful = "iphoneos-arm"
        case rootless = "iphoneos-arm64"
        case intel = "darwin-amd64"
        case applesilicon = "darwin-arm64"
    }
    
    let primary: Architecture
    let foreign: Set<Architecture>
    
    func valid(arch: String?) -> Bool {
        guard let arch else {
            return false
        }
        if arch == "all" {
            return true
        }
        guard let arch = Architecture(rawValue: arch) else {
            return false
        }
        return primary == arch || foreign.contains(arch)
    }
    
}
