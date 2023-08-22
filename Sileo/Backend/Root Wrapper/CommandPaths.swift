//
//  FilePaths.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

public class CommandPath {
    
    static let prefix: String = {
        #if targetEnvironment(macCatalyst)
        return "/opt/procursus"
        #else
        if Bootstrap.procursus_rootless {
            return "/var/jb"
        } else {
            return ""
        }
        #endif
    }()

    // swiftlint:disable identifier_name
    static var mv: String = {
        if Jailbreak.bootstrap == .procursus {
            return "\(prefix)/usr/bin/mv"
        }

        return "/bin/mv"
    }()

    static var chmod: String = {
        if Jailbreak.bootstrap == .procursus {
            return "\(prefix)/usr/bin/chmod"
        }

        return "/bin/chmod"
    }()

    // swiftlint:disable identifier_name
    static var ln: String = {
        if Jailbreak.bootstrap == .procursus {
            return "\(prefix)/usr/bin/ln"
        }

        return "/bin/ln"
    }()

    // swiftlint:disable identifier_name
    static var rm: String = {
        if Jailbreak.bootstrap == .procursus {
            return "\(prefix)/usr/bin/rm"
        }

        return "/bin/rm"
    }()

    static var mkdir: String = {
        if Jailbreak.bootstrap == .procursus {
            return "\(prefix)/usr/bin/mkdir"
        }

        return "/bin/mkdir"
    }()

    // swiftlint:disable identifier_name
    static var cp: String = {
        if Jailbreak.bootstrap == .procursus {
            return "\(prefix)/usr/bin/cp"
        }

        return "/bin/cp"
    }()

    static var sourcesListD: String = {
        "\(prefix)/etc/apt/sources.list.d"
    }()
    
    static var alternativeSources: String = {
        "\(prefix)/etc/apt/sileo.list.d"
    }()

    static var chown: String = {
        #if targetEnvironment(macCatalyst)
        return "/usr/sbin/chown"
        #else
        return "\(prefix)/usr/bin/chown"
        #endif
    }()

    static var aptmark: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/apt-mark"
        #else
        return "\(prefix)/usr/bin/apt-mark"
        #endif
    }()

    static var dpkgdeb: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/dpkg-deb"
        #else
        return "\(prefix)/usr/bin/dpkg-deb"
        #endif
    }()

    static var dpkg: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/dpkg"
        #else
        return "\(prefix)/usr/bin/dpkg"
        #endif
    }()

    static var aptget: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/apt-get"
        #else
        return "\(prefix)/usr/bin/apt-get"
        #endif
    }()

    static var aptkey: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/apt-key"
        #else
        return "\(prefix)/usr/bin/apt-key"
        #endif
    }()
    
    static var gpg: String = {
        "\(prefix)/etc/apt/trusted.gpg.d/"
    }()

    // swiftlint:disable identifier_name
    static var sh: String = {
        "\(prefix)/bin/sh"
    }()

    static var sileolists: String = {
        return "\(prefix)/var/lib/apt/sileolists"
    }()

    static var lists: String = {
        return "\(prefix)/var/lib/apt/lists"
    }()

    static var whoami: String = {
        #if targetEnvironment(macCatalyst)
        "/usr/bin/whoami"
        #else
        if #available(iOS 13, *) {
            return "\(prefix)/usr/bin/whoami"
        }
        return "whoami"
        #endif
    }()

    static var uicache: String = {
        "\(prefix)/usr/bin/uicache"
    }()

    static var dpkgDir: URL = {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        return Bundle.main.bundleURL
        #else
        return URL(fileURLWithPath: "\(prefix)/Library/dpkg")
        #endif
    }()

    static var RepoIcon: String = {
        #if targetEnvironment(macCatalyst)
        return "RepoIcon"
        #else
        return "CydiaIcon"
        #endif
    }()

    static var group: String = {
        #if targetEnvironment(macCatalyst)
        return "\(NSUserName()):staff"
        #else
        return "mobile:mobile"
        #endif
    }()
    
}
