//
//  LZMA.swift
//  Sileo
//
//  Created by Amy on 01/06/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

#if !TARGET_SANDBOX && !targetEnvironment(simulator)
import Foundation

public enum XZType {
    // swiftlint:disable identifier_name
    case xz
    case lzma
}

// swiftlint:disable type_name
final class XZ {
    
    static var available: Bool = {
        if let contents = try? URL(fileURLWithPath: "/usr/local/lib/").contents() {
            return contents.contains(where: { $0.absoluteString.contains("liblzma") })
        }
        return false
    }()
    
    class func decompress(path: URL, type: XZType) -> (String?, URL?) {
        var strm = lzma_stream()
        defer {
            lzma_end(&strm)
            try? FileManager.default.removeItem(at: path)
        }
        let ret = type == .xz ? lzma_stream_decoder(&strm, UINT64_MAX, 8) : lzma_alone_decoder(&strm, UINT64_MAX)
        switch ret {
        case LZMA_OK: break
        case LZMA_MEM_ERROR: return (XZError.allocation.rawValue, nil)
        case LZMA_OPTIONS_ERROR: return (XZError.unsupportedFlags.rawValue, nil)
        default: return (XZError.unknown.rawValue, nil)
        }
        guard let infile = fopen(path.path, "rb") else {
            return (XZError.fileLoad.rawValue, nil)
        }
        defer {
            fclose(infile)
        }
        let destinationURL = path.appendingPathExtension("clean")
        guard let fout = fopen(destinationURL.path, "wb") else { return (XZError.fileLoad.rawValue, nil) }
        defer {
            fclose(fout)
        }
        var action = LZMA_RUN
        
        let inbuf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(BUFSIZ))
        let outbuf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(BUFSIZ))
        defer {
            inbuf.deallocate()
            outbuf.deallocate()
        }
        
        strm.next_in = nil
        strm.avail_in = 0
        strm.next_out = outbuf
        strm.avail_out = MemoryLayout.size(ofValue: outbuf)
        
        while true {
            if strm.avail_in == 0 && (feof(infile) == 0) {
                strm.next_in = UnsafePointer(inbuf)
                strm.avail_in = fread(inbuf, 1, MemoryLayout.size(ofValue: inbuf), infile)
                if ferror(infile) != 0 {
                    return (XZError.fileRead.rawValue, nil)
                }
                if feof(infile) != 0 {
                    action = LZMA_FINISH
                }
            }
            
            let ret = lzma_code(&strm, action)
            if strm.avail_out == 0 || ret == LZMA_STREAM_END {
                let writeSize = MemoryLayout.size(ofValue: outbuf) - strm.avail_out
                let written = fwrite(outbuf, 1, writeSize, fout)
                guard written == writeSize else { return (ZSTDError.failedWrite.rawValue, nil) }
                strm.next_out = outbuf
                strm.avail_out = MemoryLayout.size(ofValue: outbuf)
            }
            
            switch ret {
            case LZMA_OK: break
            case LZMA_STREAM_END: return (nil, destinationURL)
            case LZMA_MEM_ERROR: return (XZError.allocation.rawValue, nil)
            case LZMA_FORMAT_ERROR: return (XZError.formatError.rawValue, nil)
            case LZMA_DATA_ERROR, LZMA_BUF_ERROR: return (XZError.corrupt.rawValue, nil)
            default: return (XZError.unknown.rawValue, nil)
            }
        }
    }
}

enum XZError: String {
    case fileLoad = "Failed to load file"
    case allocation = "Memory Allocation Failed"
    case unsupportedFlags = "Unsupported Decompressor Flags"
    case fileRead = "Error Reading File"
    case formatError = "Input file is not correct format"
    case corrupt = "Input file is corrupt"
    case unknown = "Unknown Error"
}
#endif
