//
//  GZIP.swift
//  Sileo
//
//  Created by Amy on 02/06/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

final class GZIP {

    class func decompress(path: URL) -> Result<URL, GZIPError> {
        guard let fin = fopen(path.path, "rb") else { return .failure(.fileRead) }
        defer {
            fclose(fin)
            try? FileManager.default.removeItem(at: path)
        }
        let destinationURL = path.appendingPathExtension("clean")
        guard let fout = fopen(destinationURL.path, "wb") else { return .failure(.failedWrite) }
        defer {
            fclose(fout)
        }
        let ret = decompressGzip(fin, fout)
        if (ret == 0) {
            return .success(destinationURL)
        } else {
            return .failure(GZIPError(error: ret))
        }
    }
}

enum GZIPError: String, Error {
    case fileLoad = "Failed to load file"
    case inflate = "Error starting inflate"
    case fileRead = "Failed to Read File"
    case unknown = "Unknown Error"
    case failedWrite = "Failed to write data"
    
    case Z_NEED_DICT = "Z_NEED_DICT"
    case Z_DATA_ERROR = "Z_DATA_ERROR"
    case Z_MEM_ERROR = "Z_MEM_ERROR"
    case Z_STREAM_ERROR = "Z_STREAM_ERROR"
    
    init(error: UInt8) {
        switch error {
        case 2: self = .inflate
        case 3: self = .fileRead
        case 4: self = .Z_NEED_DICT
        case 5: self = .Z_DATA_ERROR
        case 6: self = .Z_MEM_ERROR
        case 7: self = .Z_STREAM_ERROR
        case 8: self = .failedWrite
        default: self = .unknown
        }
    }
}
