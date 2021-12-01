//
//  UIDevice+Private.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation

let randomUUID = UUID()

extension UIDevice {
    @objc public var uniqueIdentifier: String {
        #if TARGET_SANDBOX || targetEnvironment(simulator)
        return TEST_UDID
        #else
        let gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY)
        typealias MGCopyAnswerFunc = @convention(c) (CFString) -> CFString
        let MGCopyAnswer = unsafeBitCast(dlsym(gestalt, "MGCopyAnswer"), to: MGCopyAnswerFunc.self)
        return MGCopyAnswer("UniqueDeviceID" as CFString) as String
        #endif
    }
    
    @objc public var platform: String {
        #if targetEnvironment(simulator)
        return TEST_DEVICE
        #else
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [UInt8](repeating: 0, count: size)
        _ = machine.withUnsafeMutableBufferPointer { sysctlbyname("hw.machine", $0.baseAddress, &size, nil, 0) }
        return String(cString: machine)
        #endif
    }
    
    public var kernOSType: String {
        var size: Int = 256
        var ostype = [UInt8](repeating: 0, count: 256)
        _ = ostype.withUnsafeMutableBufferPointer { sysctlbyname("kern.ostype", $0.baseAddress, &size, nil, 0) }
        return String(cString: ostype)
    }
    
    public var kernOSRelease: String {
        var size: Int = 256
        var ostype = [UInt8](repeating: 0, count: 256)
        _ = ostype.withUnsafeMutableBufferPointer { sysctlbyname("kern.osrelease", $0.baseAddress, &size, nil, 0) }
        return String(cString: ostype)
    }
    
    var cfMajorVersion: String {
        let cfVersionRaw = kCFCoreFoundationVersionNumber
        let cfVersionRawFloored = floor(cfVersionRaw)
        let cfVersionDivided = cfVersionRawFloored / 100
        let cfVersionDividedFloored = floor(cfVersionDivided)
        let cfVersionMultiplied = cfVersionDividedFloored * 100
        let cfVersionInt = Int(cfVersionMultiplied)
        return String(format: "%d", cfVersionInt)
    }
    
}
