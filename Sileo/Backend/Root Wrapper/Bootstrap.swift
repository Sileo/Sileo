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
    static let procursus_real = URL(fileURLWithPath: "\(CommandPath.prefix)/.procursus_strapped").exists
    static let chimera_real = URL(fileURLWithPath: "/etc/apt/sources.list.d/chimera.sources").exists
    
    // Not including the electra strap as it's merely the exact same as elucubratus
    case procursus =        "Procursus"
    case elucubratus =      "Bingner/Elucubratus"
    case chimera =          "Chimera Strap"
    case unknown =          "Unknown Bootstrap (or simulated)"
    
    init(jailbreak: Jailbreak) {
    #if !targetEnvironment(simulator)
        if #available(iOS 12.0, *), Bootstrap.procursus_real {
            self = .procursus
        }   else if #available(iOS 12.0, *), Bootstrap.chimera_real {
            self = .chimera
        } else {
            self = .elucubratus
        }
    #else
        self = .unknown
    #endif
    }
}
