//
//  BZIP.swift
//  Sileo
//
//  Created by Amy on 02/06/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

final class BZIP {
    
    class func decompress(path: URL) -> Result<URL, BZError> {
        guard let fin = fopen(path.path, "rb") else { return .failure(.fileLoad) }
        defer {
            fclose(fin)
            try? FileManager.default.removeItem(at: path)
        }
        let destinationURL = path.appendingPathExtension("clean")
        guard let fout = fopen(destinationURL.path, "wb") else { return .failure(.failedWrite) }
        defer {
            fclose(fout)
        }
        let ret = decompressBzip(fin, fout)
        if (ret == 0) {
            return .success(destinationURL)
        } else {
            return .failure(BZError(error: ret))
        }
    }
    
}

enum BZError: String, Error {
    case fileLoad = "Failed to load file"
    case allocation = "Error opening file"
    case corrupt = "Input file is corrupt"
    case failedWrite = "Failed to write data"
    
    init(error: UInt8) {
        switch error {
        case 1: self = .allocation
        case 2: self = .failedWrite
        default: self = .corrupt
        }
    }
}
