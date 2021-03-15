//
//  Hash.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import CommonCrypto

enum HashType {

    fileprivate typealias HashFunction =
        (UnsafeRawPointer?, CC_LONG, UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>?
    
    case sha256
    case sha512

    fileprivate var info: (Int32, HashFunction) {
        switch self {
        case .sha256:
            return (CC_SHA256_DIGEST_LENGTH, CC_SHA256)
        case .sha512:
            return (CC_SHA512_DIGEST_LENGTH, CC_SHA512)
        }
    }

}

extension Data {

    // based on https://stackoverflow.com/a/55356729/3769927
    func hash(ofType type: HashType) -> String {
        let info = type.info
        return withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(info.0))
            _ = info.1(bytes.baseAddress, CC_LONG(bytes.count), &hash)
            return hash
        }
            .map { String(format: "%02x", $0) }
            .joined()
    }

}

extension String {

    func hash(ofType type: HashType) -> String {
        Data(utf8).hash(ofType: type)
    }

}
