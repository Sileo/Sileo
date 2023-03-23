//
//  ZSTD.swift
//  Sileo
//
//  Created by Amy on 31/05/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//
#if !targetEnvironment(simulator) && !TARGET_SANDBOX
import Foundation

final class ZSTD {

    class func decompress(path: URL) -> Result<URL, ZSTDError> {
        guard let fin = fopen(path.path, "rb") else { return .failure(.fileLoad) }
        defer {
            fclose(fin)
            try? FileManager.default.removeItem(at: path)
        }
        let destinationURL = path.appendingPathExtension("clean")
        guard let fout = fopen(destinationURL.path, "wb") else { return .failure(.fileLoad) }
        defer {
            fclose(fout)
        }
        let ret = decompressZst(fin, fout)
        if (ret == 0) {
            return .success(destinationURL)
        } else {
            return .failure(ZSTDError(error: ret))
        }
    }
}

enum ZSTDError: String, Error {
    case fileLoad = "Failed to load file"
    case context = "Failed to create decompression context"
    case unknown = "Unknown Error"
    case empty = "Input File was Empty"
    case midFrame = "Data finished mid-frame"
    case failedWrite = "Failed to write data"

    init(error: UInt8) {
        switch error {
        case 1: self = .context
        case 2: self = .failedWrite
        case 3: self = .empty
        case 4: self = .midFrame
        default: self = .unknown
        }
    }
}
#endif
