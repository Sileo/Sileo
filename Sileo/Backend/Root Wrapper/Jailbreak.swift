//
//  File.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation
import MachO

enum Jailbreak: String, Codable {
    
    static let current = Jailbreak()
    static let bootstrap = Bootstrap(jailbreak: current)
    
    case electra =           "Electra"
    case chimera =           "Chimera"
    case odyssey =           "Odyssey"
    case taurine =           "Taurine"
    case unc0ver =           "unc0ver"
    case checkra1n =         "checkra1n"
    case odysseyra1n =       "Odysseyra1n"
    case palera1n =          "palera1n"
    case palera1n_legacy =   "palera1n (Legacy)"
    case bakera1n =          "bakera1n"
    case xina15 =            "XinaA15"
    case fugu15 =            "Fugu15"
    case dopamine =          "Dopamine"
    case mac =               "macOS"
    case other =             "Unknown Jailbreak"
    case simulator =         "Simulator"
    
    fileprivate static func arch() -> String {
        guard let archRaw = NXGetLocalArchInfo().pointee.name else {
            return "arm64"
        }
        return String(cString: archRaw)
    }
    
    
    
    // Supported for userspace reboots
    static private let supported: Set<Jailbreak> = [
        .chimera,
        .odyssey,
        .taurine,
        .checkra1n,
        .odysseyra1n,
        .palera1n,
        .palera1n_legacy,
        .bakera1n,
        .fugu15,
        .dopamine
    ]
    
    public var supportsUserspaceReboot: Bool {
        Self.supported.contains(self)
    }
    
    private init() {
                
        let checkra1n =         URL(fileURLWithPath: "/var/checkra1n.dmg")
        let bakera1n =          URL(fileURLWithPath: "/cores/binpack/.installed_overlay")
        let palera1n =          URL(fileURLWithPath: "/cores/jbloader")
        let palera1n_Legacy =   URL(fileURLWithPath: "/jbin/post.sh")
        let xina =              URL(fileURLWithPath: "/var/Liy/.procursus_strapped")
        let fugu15_max =        URL(fileURLWithPath: "/var/jb/.installed_fugu15max")
        let dopamine =          URL(fileURLWithPath: "/var/jb/.installed_dopamine")
        let unc0ver =           URL(fileURLWithPath: "/.installed_unc0ver")
        let taurine =           URL(fileURLWithPath: "/taurine/jailbreakd")
        let odyssey =           URL(fileURLWithPath: "/odyssey/jailbreakd")
        let chimera =           URL(fileURLWithPath: "/chimera/jailbreakd")
        let electra =           URL(fileURLWithPath: "/electra/jailbreakd")
        
        let arm64e = Self.arch() == "arm64e"
        switch (true) {
        case xina.exists && arm64e:                 self = .xina15; return
        case fugu15_max.exists && arm64e:           self = .fugu15; return
        case dopamine.exists:                       self = .dopamine; return
        case unc0ver.exists:                        self = .unc0ver; return
        case taurine.exists:                        self = .taurine; return
        case odyssey.exists:                        self = .odyssey; return
        case chimera.exists:                        self = .chimera; return
        case electra.exists:                        self = .electra; return
        case checkra1n.exists && !arm64e:           self = Bootstrap.procursus_real ? .odysseyra1n : .checkra1n; return
        case bakera1n.exists && !arm64e:            self = .bakera1n; return
        case palera1n.exists && !arm64e:            self = .palera1n; return
        case palera1n_Legacy.exists && !arm64e:     self = .palera1n_legacy; return
        default:
            #if targetEnvironment(macCatalyst)
            self = .mac; return
            #endif
            #if targetEnvironment(simulator)
            self = .simulator; return
            #endif
            self = .other; return
        }
    }
}
