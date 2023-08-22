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
    
    /// Coolstar jailbreaks
    case electra =           "Electra"
    case chimera =           "Chimera"
    case odyssey =           "Odyssey"
    case taurine =           "Taurine"
    
    /// unc0ver jailbreak
    case unc0ver =           "unc0ver"
    
    /// checkra1n-type jailbreaks
    case checkra1n =         "checkra1n"
    case odysseyra1n =       "Odysseyra1n"
    
    case palera1n =          "palera1n"
    case palera1n_rootless = "palera1n • Rootless"
    case palera1n_rootful =  "palera1n • Rootful"
    case palera1n_legacy =   "palera1n • Legacy"

    case bakera1n =          "bakera1n"
    case bakera1n_rootless = "bakera1n • Rootless"
    case bakera1n_rootful =  "bakera1n • Rootful"
    
    /// Xina
    case xina15 =            "XinaA15"
    
    /// Fugu15
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
        .chimera, .odyssey, .taurine,
        
        .odysseyra1n, .checkra1n,
        
        .palera1n, .palera1n_rootful, .palera1n_rootless, .palera1n_legacy,
        
        .bakera1n, .bakera1n_rootful, .bakera1n_rootless,
        
        .fugu15, .dopamine
    ]
    
    public var supportsUserspaceReboot: Bool {
        Self.supported.contains(self)
    }
    
    private init() {
        #if targetEnvironment(simulator)
        self = .simulator
        return
        #endif
                
        let checkra1n = URL(fileURLWithPath: "/var/checkra1n.dmg")
        let bakera1n = URL(fileURLWithPath: "/cores/binpack/.installed_overlay")
        let palera1n = URL(fileURLWithPath: "/cores/jbloader")
        let palera1n_Legacy = URL(fileURLWithPath: "/jbin/post.sh")
        
        let xina = URL(fileURLWithPath: "/var/Liy/.procursus_strapped")
        let fugu15_max = URL(fileURLWithPath: "/var/jb/.installed_fugu15max")
        let dopamine = URL(fileURLWithPath: "/var/jb/.installed_dopamine")
        
        let unc0ver = URL(fileURLWithPath: "/.installed_unc0ver")
        let taurine = URL(fileURLWithPath: "/taurine/jailbreakd")
        let odyssey = URL(fileURLWithPath: "/odyssey/jailbreakd")
        let chimera = URL(fileURLWithPath: "/chimera/jailbreakd")
        let electra = URL(fileURLWithPath: "/electra/jailbreakd")
        
        let arm64e = Self.arch() == "arm64e"
        
        switch (true) {
            
            // bakera1n [rootful, rootless]
        case bakera1n.exists && !arm64e:
            if Bootstrap.procursus_rootless {
                self = .bakera1n_rootless
                return
            } else if Bootstrap.procursus_rootful {
                self = .bakera1n_rootful
                return
            } else {
                self = .bakera1n
            }
            
            // palera1n [rootful, rootless]
        case palera1n.exists && !arm64e:
            if Bootstrap.procursus_rootless {
                self = .palera1n_rootless
                return
            } else if Bootstrap.procursus_rootful {
                self = .palera1n_rootful
                return
            } else {
                self = .palera1n
            }
            
        case palera1n_Legacy.exists && !arm64e:
            self = .palera1n_legacy
            return
            
            // arm64e 15.0+ jailbreaks
        case xina.exists && arm64e:
            self = .xina15
            return
            
        case fugu15_max.exists && arm64e:
            self = .fugu15
            return
            
        case dopamine.exists && arm64e:
            self = .dopamine
            return
            
            // 14.x- jailbreaks
        case checkra1n.exists && !arm64e:
            if Bootstrap.procursus_rootful {
                self = .odysseyra1n
                return
            } else {
                self = .checkra1n
                return
            }
            
        case unc0ver.exists:
            self = .unc0ver
            return
            
        case taurine.exists:
            self = .taurine
            return
            
            // 13.x- jailbreaks
        case odyssey.exists:
            self = .odyssey
            return
            
        case chimera.exists:
            self = .chimera
            return
            
        case electra.exists:
            self = .electra
            return
            
        default:
            #if targetEnvironment(macCatalyst)
            self = .mac
            return
            #endif
            self = .other
            return
        }
    }
}
