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
    
    public func valid(arch: String?) -> Bool {
        guard let arch else {
            return false
        }
        if arch == "all" {
            return true
        }
        guard let arch = Architecture(rawValue: arch) else {
            return false
        }
        return arch == primary || foreign.contains(arch)
    }
    
    public func valid(arch: DPKGArchitecture?) -> Bool {
        guard let arch else {
            return false
        }
        let primary = arch.primary
        if self.primary == primary || self.foreign.contains(primary) {
            return true
        }
        if arch.foreign.contains(self.primary) {
            return true
        }
        for arch in arch.foreign {
            if arch == self.primary || self.foreign.contains(arch) {
                return true
            }
        }
        return false
    }
    
    public func valid(arch: Architecture?) -> Bool {
        guard let arch else {
            return false
        }
        return self.primary == arch || self.foreign.contains(arch)
    }
    
}
