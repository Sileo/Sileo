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
    
}
