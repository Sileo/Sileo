//
//  BZIP.swift
//  Sileo
//
//  Created by Amy on 02/06/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation

final class BZIP {
    
    class func decompress(path: String) -> (String?, Data?) {
        guard let fin = fopen(path, "rb") else { return (BZError.fileLoad.rawValue, nil) }
        defer {
            fclose(fin)
        }
        
        var error: Int32 = 0
        let data = NSMutableData()
        var buf = [Int8](repeating: 0, count: 4096)
        let bzf = BZ2_bzReadOpen(&error, fin, 0, 0, nil, 0)
        defer {
            BZ2_bzReadClose(&error, bzf)
        }
        if error != BZ_OK {
            return (BZError.allocation.rawValue, nil)
        }
        while error == BZ_OK {
            let read = BZ2_bzRead(&error, bzf, &buf, Int32(MemoryLayout.size(ofValue: buf)))
            if error == BZ_OK || error == BZ_STREAM_END {
                data.append(Data(bytes: buf, count: Int(read)))
            }
        }
        if error != BZ_STREAM_END {
            return (BZError.corrupt.rawValue, nil)
        }
        return (nil, data as Data)
    }
    
}

enum BZError: String {
    case fileLoad = "Failed to load file"
    case allocation = "Error opening file"
    case corrupt = "Input file is corrupt"
}
