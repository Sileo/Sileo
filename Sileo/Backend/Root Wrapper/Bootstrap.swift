//
//  Bootstrap.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

enum Bootstrap: String, Codable {
        
    static let procursus_rootless = URL(fileURLWithPath: "/var/jb/.procursus_strapped").exists
    static let procursus_rootful = URL(fileURLWithPath: "/.procursus_strapped").exists
    
    case procursus = "Procursus"
    case elucubratus = "Bingner/Elucubratus"
    
    case xinaa15_strap = "Procursus/Xina"
    case electra_strap = "Electra/Chimera"
    case other_strap = "Unknown Bootstrap"
    
    init(jailbreak: Jailbreak) {
        switch jailbreak {
            
        case .electra:
            self = .electra_strap
            
        case .chimera:
            if Bootstrap.procursus_rootful {
                self = .procursus
            } else {
                self = .electra_strap
            }
            
        case .unc0ver:
            self = .elucubratus
            
        case .checkra1n:
            self = .elucubratus
            
        case .odysseyra1n, .taurine, .odyssey:
            self = .procursus
            
        case .palera1n_legacy, .palera1n_rootful, .palera1n_rootless, .bakera1n_rootful, .bakera1n_rootless:
            if Bootstrap.procursus_rootful || Bootstrap.procursus_rootless {
                self = .procursus
            } else {
                self = .other_strap
            }
            
        case .xina15:
            self = .xinaa15_strap
            
        default:
            self = .other_strap
        }
    }
    
}
