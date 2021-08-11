//
//  LZ4.swift
//  Sileo
//
//  Created by Andromeda on 10/07/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

#if !TARGET_SANDBOX && !targetEnvironment(simulator)
import Foundation

// swiftlint:disable type_name
final class LZ4 {
    
    static var available: Bool = {
        if let contents = try? URL(fileURLWithPath: "/usr/local/lib/").contents() {
            return contents.contains(where: { $0.absoluteString.contains("liblz4") })
        }
        return false
    }()
    
    class func decompress(path: String) -> (String?, Data?) {
        guard let fin = fopen(path, "rb") else { return (BZError.fileLoad.rawValue, nil) }
        defer {
            fclose(fin)
        }
        guard let decoder = LZ4_createStreamDecode() else {
            return (nil, nil)
        }
        let cmpBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(LZ4_compressBound(Int32(MESSAGE_MAX_BYTES))))
        let decBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(RING_BUFFER_BYTES))
        defer {
            cmpBuf.deallocate()
            decBuf.deallocate()
        }
        
        return (nil, nil)
    }
}
#endif
