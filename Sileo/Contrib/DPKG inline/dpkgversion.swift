//
//  dpkgversion.swift
//  Sileo
//
//  Created by CoolStar on 4/17/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation
import Evander

struct DpkgVersion {
    var epoch: UInt
    var version: ArraySlice<CChar>
    var revision: ArraySlice<CChar>
}

func isBlank(char: CChar) -> Bool {
    isblank(Int32(char)) != 0
}

func parseversion(version: String) throws -> DpkgVersion {
    let strArr = version.utf8.map { Int8($0) } + [0]

    var version = ArraySlice<CChar>(strArr)
    var searchIdx = 0
    var found = false
    for char in version {
        if char == 58 { // 58 means a colon :
            found = true
            break
        }
        searchIdx += 1
    }

    var epochNum = 0
    if found {
        var epochStr = version.dropLast(version.count - searchIdx)
        version = version.dropFirst(searchIdx + 1)
        
        guard !version.isEmpty else {
            throw "nothing after colon in version number"
        }
        
        errno = 0
        epochNum = try epochStr.withUnsafeMutableBufferPointer {
            var baseAddrPtr = $0.baseAddress
            let num = strtol($0.baseAddress, &baseAddrPtr, 10)
            guard baseAddrPtr != $0.baseAddress else {
                throw "epoch is not number"
            }
            return num
        }
        guard epochNum <= INT_MAX && errno != ERANGE else {
            throw "epoch version is too big"
        }
        guard epochNum > 0 else {
            throw "epoch is negative"
        }
    }

    searchIdx = version.count
    found = false
    for char in version.reversed() {
        searchIdx -= 1
        if char == 45 { // 45 means a dash -
            found = true
            break
        }
    }

    if found {
        version[version.startIndex + searchIdx] = 0
    }
    
    let versionStr = found ? version.dropLast(version.count - (searchIdx + 1)) : version
    let revisionStr = found ? version.dropFirst(searchIdx + 1) : ArraySlice<CChar>([0])

    for char in versionStr {
        guard isDigit(char: char) || isAlpha(char: char) || strrchr(".-+~:", Int32(char)) != nil else {
            throw "invalid character in version number"
        }
    }

    for char in revisionStr {
        guard isDigit(char: char) || isAlpha(char: char) || strrchr(".-+~:", Int32(char)) != nil else {
            throw "invalid character in version number"
        }
    }
    if versionStr.last != 0 {
        fatalError("Needs null termination")
    }
    if revisionStr.last != 0 {
        fatalError("Needs null termination")
    }
    return DpkgVersion(epoch: UInt(epochNum), version: versionStr, revision: revisionStr)
}

func compareVersions(_ aStr: String, _ bStr: String) throws -> Int {
    let aVer = try parseversion(version: aStr)
    let bVer = try parseversion(version: bStr)
    
    if aVer.epoch > bVer.epoch {
        return 1
    }
    if aVer.epoch < bVer.epoch {
        return -1
    }
    
    let retVal = verrevcmp(val: aVer.version, ref: bVer.version)
    if retVal != 0 {
        return retVal
    }
    
    return verrevcmp(val: aVer.revision, ref: bVer.revision)
}
