//
//  Hash.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import CommonCrypto

enum HashType {
    case sha256
    case sha512
}

extension URL {
    
    func hash(ofType type: HashType) -> String? {
        do {
            let bufferSize = 1024 * 1024
            let file = try FileHandle(forReadingFrom: self)
            defer {
                file.closeFile()
            }
            switch type {
            case .sha256:
                var context = CC_SHA256_CTX()
                CC_SHA256_Init(&context)
                
                while autoreleasepool(invoking: {
                    let data = file.readData(ofLength: bufferSize)
                    if data.count > 0 {
                        _ = data.withUnsafeBytes { bytesFromBuffer -> Int32 in
                            guard let rawBytes = bytesFromBuffer.bindMemory(to: UInt8.self).baseAddress else {
                                return Int32(kCCMemoryFailure)
                            }
                            return CC_SHA256_Update(&context, rawBytes, numericCast(data.count))
                        }
                        return true
                    } else {
                        return false
                    }
                }) { }
                
                var digestData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
                _ = digestData.withUnsafeMutableBytes { bytesFromDigest -> Int32 in
                    guard let rawBytes = bytesFromDigest.bindMemory(to: UInt8.self).baseAddress else {
                        return Int32(kCCMemoryFailure)
                    }
                    return CC_SHA256_Final(rawBytes, &context)
                }
                return digestData.compactMap { String(format: "%02x", $0) }.joined()
            case .sha512:
                var context = CC_SHA512_CTX()
                CC_SHA512_Init(&context)
                
                while autoreleasepool(invoking: {
                    let data = file.readData(ofLength: bufferSize)
                    if data.count > 0 {
                        _ = data.withUnsafeBytes { bytesFromBuffer -> Int32 in
                            guard let rawBytes = bytesFromBuffer.bindMemory(to: UInt8.self).baseAddress else {
                                return Int32(kCCMemoryFailure)
                            }
                            return CC_SHA512_Update(&context, rawBytes, numericCast(data.count))
                        }
                        return true
                    } else {
                        return false
                    }
                }) { }
                
                var digestData = Data(count: Int(CC_SHA512_DIGEST_LENGTH))
                _ = digestData.withUnsafeMutableBytes { bytesFromDigest -> Int32 in
                    guard let rawBytes = bytesFromDigest.bindMemory(to: UInt8.self).baseAddress else {
                        return Int32(kCCMemoryFailure)
                    }
                    return CC_SHA512_Final(rawBytes, &context)
                }
                return digestData.compactMap { String(format: "%02x", $0) }.joined()
            }
        } catch {}
        return nil
    }
    
}
