//
//  Bootstrap.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

enum Bootstrap: String, Codable {
    
    static let rootless = URL(fileURLWithPath: "/var/jb/.procursus_strapped").exists
    
    case procursus = "Procursus"
    case xina = "Procursus/Xina"
    case elucubratus = "Bingner/Elucubratus"
    case electra = "Electra/Chimera"
    case unc0ver = "Unc0verstrap"
    
    init(jailbreak: Jailbreak) {
        switch jailbreak {
        case .electra: self = .electra
        case .chimera:
            if URL(fileURLWithPath: "/.procursus_strapped").exists {
                self = .procursus
            } else {
                self = .electra
            }
        case .unc0ver11:
            self = .unc0ver
        case .unc0ver12, .unc0ver13, .unc0ver14, .checkra1n12, .checkra1n13, .checkra1n14:
            self = .elucubratus
        case .xina15:
            self = .xina
        default:
            self = .procursus
        }
    }
    
}
