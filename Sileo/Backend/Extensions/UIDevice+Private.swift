//
//  UIDevice+Private.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

final class PrivateIdentifiers {
    
    static let shared = PrivateIdentifiers()
    
    let uniqueIdentifier: String
    let platform: String
    let kernOSType: String
    let kernOSRelease: String
    let cfMajorVersion: String
    
    init() {
        #if TARGET_SANDBOX || targetEnvironment(simulator)
        uniqueIdentifier = TEST_UDID
        platform = TEST_DEVICE
        var size: Int = 256
        #else
        let gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY)
        typealias MGCopyAnswerFunc = @convention(c) (CFString) -> CFString
        let MGCopyAnswer = unsafeBitCast(dlsym(gestalt, "MGCopyAnswer"), to: MGCopyAnswerFunc.self)
        uniqueIdentifier = MGCopyAnswer("UniqueDeviceID" as CFString) as String
        
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [UInt8](repeating: 0, count: size)
        _ = machine.withUnsafeMutableBufferPointer { sysctlbyname("hw.machine", $0.baseAddress, &size, nil, 0) }
        platform = String(cString: machine)
        
        size = 256
        #endif

        var ostype = [UInt8](repeating: 0, count: 256)
        _ = ostype.withUnsafeMutableBufferPointer { sysctlbyname("kern.ostype", $0.baseAddress, &size, nil, 0) }
        kernOSType = String(cString: ostype)
        
        _ = ostype.withUnsafeMutableBufferPointer { sysctlbyname("kern.osrelease", $0.baseAddress, &size, nil, 0) }
        kernOSRelease = String(cString: ostype)
        
        let cfVersionRaw = kCFCoreFoundationVersionNumber
        let cfVersionRawFloored = floor(cfVersionRaw)
        let cfVersionDivided = cfVersionRawFloored / 100
        let cfVersionDividedFloored = floor(cfVersionDivided)
        let cfVersionMultiplied = cfVersionDividedFloored * 100
        let cfVersionInt = Int(cfVersionMultiplied)
        cfMajorVersion = String(format: "%d", cfVersionInt)
    }
    
    public lazy var headers: [String: String] = {
        /*
         Example:
         Sec-CH-UA: Sileo;v=2.4.4;t=client,dopamine;v=1.0.1;t=jailbreak,procursus;t=distribution
         Sec-CH-UA-Platform: iphoneos
         Sec-CH-UA-Platform-Version: 15.4.1
         Sec-CH-UA-Arch: iphoneos-arm64
         Sec-CH-UA-Bitness: 64
         Sec-CH-UA-Model: iPhone11,9
         */
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let jb = Jailbreak.current.rawValue.split(separator: " ").first!.lowercased()
        let bootstrap = Jailbreak.bootstrap.rawValue.lowercased()
        #if targetEnvironment(macCatalyst)
        let platform = "macos"
        #else
        let platform = "iphoneos"
        #endif
        let version = UIDevice.current.systemVersion
        let arch = DpkgWrapper.architecture.primary.rawValue
        let bitness = MemoryLayout<Int>.size * 8
        let model = self.platform
        return [
            "Sec-CH-UA": "Sileo;v=\(appVersion);t=client,\(jb);t=jailbreak,\(bootstrap);t=distribution",
            "Sec-CH-UA-Platform": platform,
            "Sec-CH-UA-Platform-Version": version,
            "Sec-CH-UA-Arch": arch,
            "Sec-CH-UA-Bitness": "\(bitness)",
            "Sec-CH-UA-Model": model
        ]
    }()
    
}

extension UIDevice {
    
    @objc public var uniqueIdentifier: String {
        PrivateIdentifiers.shared.uniqueIdentifier
    }
    
    @objc public var platform: String {
        PrivateIdentifiers.shared.platform
    }
    
    public var kernOSType: String {
        PrivateIdentifiers.shared.kernOSType
    }
    
    public var kernOSRelease: String {
        PrivateIdentifiers.shared.kernOSRelease
    }
    
    var cfMajorVersion: String {
        PrivateIdentifiers.shared.cfMajorVersion
    }
    
    public var headers: [String: String] {
        PrivateIdentifiers.shared.headers
    }
    
}
