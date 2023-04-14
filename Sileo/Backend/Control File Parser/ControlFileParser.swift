//
//  ControlFileParser.swift
//  Sileo
//
//  Created by CoolStar on 6/22/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

struct PackageTags: OptionSet {
    let rawValue: Int
    
    static let none = PackageTags([])
    static let commercial = PackageTags(rawValue: 1)
    static let sileo = PackageTags(rawValue: 2)
}

final class ControlFileParser {
    enum Error: LocalizedError {
        case invalidStringData
        case invalidMultilineValue
        case expectedSeparator
    }
    
    // static let dispatchLock = DispatchSemaphore(value: 1)

    class func dictionary(controlFile: String, isReleaseFile: Bool) throws -> ([String: String], PackageTags) {
        guard let controlData = controlFile.data(using: .utf8) else {
            throw Error.invalidStringData
        }
        return try dictionary(controlData: controlData, isReleaseFile: isReleaseFile)
    }
    
    class func dictionary(controlData: Data, isReleaseFile: Bool) throws -> ([String: String], PackageTags) {
        var dictionary: [String: String] = Dictionary(minimumCapacity: 20)
        var tags: PackageTags = .none
        // self.dispatchLock.wait()
        
        let controlDataArr = [UInt8](controlData)
        parseControlFile(controlDataArr, controlData.count, isReleaseFile, { rawKey, rawVal in
            let key = String(cString: rawKey)
            let val = String(cString: rawVal)
            dictionary[key] = val
        }, { rawTags in
            tags = PackageTags(rawValue: Int(rawTags))
        })
        // self.dispatchLock.signal()
        return (dictionary, tags)
    }

}
