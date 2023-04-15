//
//  LZMA.swift
//  Sileo
//
//  Created by Amy on 01/06/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

public enum XZType: UInt8 {
    // swiftlint:disable identifier_name
    case xz = 0
    case lzma = 1
}

// swiftlint:disable type_name
final class XZ {

    class func decompress(path: URL, type: XZType) -> Result<URL, XZError> {
        guard let infile = fopen(path.path, "rb") else {
            return .failure(.fileLoad)
        }
        defer {
            fclose(infile)
        }
        let destinationURL = path.appendingPathExtension("clean")
        guard let fout = fopen(destinationURL.path, "wb") else { return .failure(.fileLoad) }
        defer {
            fclose(fout)
        }
        let ret = decompressXz(infile, fout, type.rawValue)
        if (ret == 0) {
            return .success(destinationURL)
        } else {
            return .failure(XZError(error: ret))
        }
    }
}

enum XZError: String, Error {
    case fileLoad = "Failed to load file"
    case allocation = "Memory Allocation Failed"
    case unsupportedFlags = "Unsupported Decompressor Flags"
    case fileRead = "Error Reading File"
    case fileWrite = "Error Writing File"
    case formatError = "Input file is not correct format"
    case corrupt = "Input file is corrupt"
    case unknown = "Unknown Error"
    
    init(error: UInt8) {
        switch error {
        case 1: self = .allocation
        case 2: self = .unsupportedFlags
        case 3: self = .unknown
        case 4: self = .fileRead
        case 5: self = .fileWrite
        case 8: self = .formatError
        case 9: self = .corrupt
        default: self = .unknown
        }
    }
}

