//
//  DpkgWrapper.swift
//  Anemone
//
//  Created by CoolStar on 6/23/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

enum pkgwant {
    case unknown,
    install,
    hold,
    deinstall,
    purge,
    /** Not allowed except as special sentinel value in some places. */
    sentinel
}

enum pkgeflag {
    case ok,
    reinstreq
}

enum pkgstatus {
    case notinstalled,
    configfiles,
    halfinstalled,
    unpacked,
    halfconfigured,
    triggersawaited,
    triggerspending,
    installed
}

enum pkgpriority {
    case required,
    important,
    standard,
    optional,
    extra,
    other,
    unknown,
    unset
}

class DpkgWrapper {
    private static let priorityinfos: [String: pkgpriority] = ["required": .required,
                                                               "important": .important,
                                                               "standard": .standard,
                                                               "optional": .optional,
                                                               "extra": .extra,
                                                               "unknown": .unknown]
    private static let wantinfos: [String: pkgwant] = ["unknown": .unknown,
                                                       "install": .install,
                                                       "hold": .hold,
                                                       "deinstall": .deinstall,
                                                       "purge": .purge]
    private static let eflaginfos: [String: pkgeflag] = ["ok": .ok,
                                                         "reinstreq": .reinstreq]
    
    private static let statusinfos: [String: pkgstatus] = ["not-installed": .notinstalled,
                                                           "config-files": .configfiles,
                                                           "half-installed": .halfinstalled,
                                                           "unpackad": .unpacked,
                                                           "half-configured": .halfconfigured,
                                                           "triggers-awaited": .triggersawaited,
                                                           "triggers-pending": .triggerspending,
                                                           "installed": .installed]
    
    public class func dpkgInterrupted() -> Bool {
        let updatesDir = PackageListManager.shared.dpkgDir.appendingPathComponent("updates/")
        var interrupted = false
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: updatesDir.absoluteURL.path) else {
            return interrupted
        }
        for file in contents {
            if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: file)) {
                interrupted = true
            }
        }
        return interrupted
    }
    
    public class func getArchitectures() -> [String] {
        let defaultArchitectures = ["iphoneos-arm"]
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        return defaultArchitectures
        #else
        let (retVal, outputString, _) = spawn(command: "/usr/bin/dpkg", args: ["dpkg", "--print-architecture"])
        guard retVal == 0 else {
            return defaultArchitectures
        }
        return outputString.components(separatedBy: CharacterSet(charactersIn: "\n"))
        #endif
    }
    
    public class func isVersion(_ version: String, greaterThan: String) -> Bool {
        guard let dpkgCmp = try? compareVersions(version, greaterThan) else {
            return false
            //FIXME: Handle exception properly
        }
        
        if dpkgCmp > 0 {
            return true
        }
        return false
    }
    
    public class func getValues(statusField: String?, wantInfo : inout pkgwant, eFlag : inout pkgeflag, pkgStatus : inout pkgstatus) -> Bool {
        guard let statusParts = statusField?.components(separatedBy: CharacterSet(charactersIn: " ")) else {
            return false
        }
        if statusParts.count < 3 {
            return false
        }
        wantInfo = .unknown
        
        for (name, wantValue) in wantinfos where name == statusParts[0] {
            wantInfo = wantValue
        }
        
        for (name, eflagValue) in eflaginfos where name == statusParts[1] {
            eFlag = eflagValue
        }
        
        for (name, statusValue) in statusinfos where name == statusParts[2] {
            pkgStatus = statusValue
        }
        return true
    }
    
    public class func ignoreUpdates(_ ignoreUpdates: Bool, package: String) {
        let ignoreCommand = ignoreUpdates ? "hold" : "install"
        let command = "/bin/echo \"\(package) \(ignoreCommand)\" | /usr/bin/dpkg --set-selections"
        spawnAsRoot(command: command)
    }
    
    public class func rawFields(packageURL: URL) throws -> String {
        guard packageURL.isFileURL else {
            throw NSError(domain: "Sileo.Dpkg", code: 3, userInfo: ["Description": "URL provided not a file url!"])
        }
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        return """
        Package: bash
        Version: 4.4.18
        Architecture: iphoneos-arm
        Maintainer: CoolStar <coolstarorganization@gmail.com>
        Depends: grep, ncurses (>=6.1), sed, cy+cpu.arm64
        Section: Terminal_Support
        Priority: required
        Homepage: http://www.gnu.org/software/bash/
        Description: the best shell ever written by Brian Fox
        Name: Bourne-Again SHell
        """
        #else
        let (_, outputString, _) = spawn(command: "/usr/bin/dpkg-deb", args: ["dpkg-deb", "--field", packageURL.path])
        return outputString
        #endif
    }
}
