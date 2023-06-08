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
    
    // Coolstar
    case electra = "Electra (iOS 11)"
    case chimera = "Chimera (iOS 12)"
    case odyssey = "Odyssey (iOS 13)"
    case taurine = "Taurine (iOS 14)"
    
    // unc0ver
    case unc0ver11 = "unc0ver (iOS 11)"
    case unc0ver12 = "unc0ver (iOS 12)"
    case unc0ver13 = "unc0ver (iOS 13)"
    case unc0ver14 = "unc0ver (iOS 14)"
    
    // checkra1n
    case checkra1n12 = "checkra1n (iOS 12)"
    case checkra1n13 = "checkra1n (iOS 13)"
    case checkra1n14 = "checkra1n (iOS 14)"
    
    // Odysseyra1n
    case odysseyra1n12 = "Odysseyra1n (iOS 12)"
    case odysseyra1n13 = "Odysseyra1n (iOS 13)"
    case odysseyra1n14 = "Odysseyra1n (iOS 14)"
    
    // Palera1n
    case palera1n_rootless15 = "palera1n Rootless (iOS 15)"
    case palera1n_rootless16 = "palera1n Rootless (iOS 16)"
    case palera1n_rootful15 = "palera1n Rootful (iOS 15)"
    case palera1n_rootful16 = "palera1n Rootful (iOS 16)"
    case palera1n17 = "palera1n (iPadOS 17)"
    
    // Xina
    case xina15 = "XinaA15 (iOS 15)"
    
    // Fugu15
    case fugu15 = "Fugu15 (iOS 15)"
    case dopamine = "Dopamine (iOS 15)"
    
    // Bakera1n
    case bakera1n_rootless15 = "bakera1n Rootless (iOS 15)"
    case bakera1n_rootless16 = "bakera1n Rootless (iOS 16)"
    case bakera1n_rootful15 = "bakera1n Rootful (iOS 15)"
    case bakera1n_rootful16 = "bakera1n Rootful (iOS 16)"
    case bakera1n17 = "bakera1n (iPadOS 17)"
    
    case mac = "macOS"
    case other = "Other"
    case simulator = "Simulator"
    
    fileprivate static func arch() -> String {
        guard let archRaw = NXGetLocalArchInfo().pointee.name else {
            return "arm64"
        }
        return String(cString: archRaw)
    }
    
    static private let supported: Set<Jailbreak> = [.chimera, .odyssey, .taurine, .odysseyra1n12, .odysseyra1n13, .odysseyra1n14, .palera1n_rootful15, .palera1n_rootful16, .palera1n_rootless15, .palera1n_rootless16, .palera1n17, .fugu15, .dopamine]
    public var supportsUserspaceReboot: Bool {
        Self.supported.contains(self)
    }
    
    private init() {
        #if targetEnvironment(simulator)
        self = .simulator
        return
        #endif
        
        let palecursus = URL(fileURLWithPath: "/.palecursus_strapped")
        let procursus = URL(fileURLWithPath: "/.procursus_strapped")
        let rootless_procursus = URL(fileURLWithPath: "/var/jb/.procursus_strapped")
        let checkra1n = URL(fileURLWithPath: "/var/checkra1n.dmg")
        let unc0ver = URL(fileURLWithPath: "/.installed_unc0ver")
        let bakera1n = URL(fileURLWithPath: "/cores/binpack/.installed_overlay")
        
        
        let arm64e = Self.arch() == "arm64e"
        
        if #available(iOS 17.0, *) {
            if bakera1n.exists && rootless_procursus.exists {
                self = .bakera1n17
                return
            } else if rootless_procursus.exists {
                self = .palera1n17
                return
            }
        } else if #available(iOS 16.0, *) {
            if palecursus.exists {
                self = .palera1n_rootful16
                return
            } else if bakera1n.exists && procursus.exists {
                self = .bakera1n_rootful16
                return
            } else if bakera1n.exists && rootless_procursus.exists {
                self = .bakera1n_rootless16
                return
            } else if rootless_procursus.exists {
                self = .palera1n_rootless16
                return
            }
        } else if #available(iOS 15.0, *) {
            if arm64e {
                let xina = URL(fileURLWithPath: "/var/Liy/.procursus_strapped")
                if xina.exists {
                    self = .xina15
                    return
                }
                
                let fugu = URL(fileURLWithPath: "/var/jb/.installed_fugu15max")
                if fugu.exists {
                    self = .fugu15
                    return
                }
                
                let dopamine = URL(fileURLWithPath: "/var/jb/.installed_dopamine")
                if dopamine.exists {
                    self = .dopamine
                    return
                }
            } else {
                if palecursus.exists {
                    self = .palera1n_rootful15
                    return
                } else if bakera1n.exists && procursus.exists {
                    self = .bakera1n_rootful15
                    return
                } else if bakera1n.exists && rootless_procursus.exists {
                    self = .bakera1n_rootless15
                    return
                } else if rootless_procursus.exists {
                    self = .palera1n_rootless15
                    return
                }
            }
        } else if #available(iOS 14.0, *) {
            if procursus.exists {
                if checkra1n.exists {
                    self = .odysseyra1n14
                    return
                }
                let taurine = URL(fileURLWithPath: "/taurine/jailbreakd")
                if taurine.exists {
                    self = .taurine
                    return
                }
            } else {
                if unc0ver.exists {
                    self = .unc0ver14
                    return
                } else {
                    self = .checkra1n14
                    return
                }
            }
        } else if #available(iOS 13.0, *) {
            if procursus.exists {
                if checkra1n.exists {
                    self = .odysseyra1n13
                    return
                }
                let taurine = URL(fileURLWithPath: "/odyssey/jailbreakd")
                if taurine.exists {
                    self = .odyssey
                    return
                }
            } else {
                if unc0ver.exists {
                    self = .unc0ver13
                    return
                } else {
                    self = .checkra1n13
                    return
                }
            }
        } else if #available(iOS 12.0, *) {
            if procursus.exists {
                if checkra1n.exists {
                    self = .odysseyra1n12
                    return
                }
                let taurine = URL(fileURLWithPath: "/chimera/jailbreakd")
                if taurine.exists {
                    self = .chimera
                    return
                }
            } else {
                if unc0ver.exists {
                    self = .unc0ver12
                    return
                } else {
                    self = .checkra1n12
                    return
                }
            }
        } else if #available(iOS 11.0, *) {
            let electra = URL(fileURLWithPath: "/electra/jailbreakd")
            if electra.exists {
                self = .electra
                return
            } else {
                self = .unc0ver11
                return
            }
        } else {
            #if targetEnvironment(macCatalyst)
            self = .mac
            return
            #endif
        }
        self = .other
    }

    
}
