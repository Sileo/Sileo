//
//  AmyLogManager.swift
//  Sileo
//
//  Created by Andromeda on 03/06/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation

public class AmyLogManager {
    
    public class func log(_ string: String) {
        let path = AmyNetworkResolver.shared.cacheDirectory.appendingPathComponent("RepoRefreshLog").appendingPathExtension("txt")
        var contents = (try? String(contentsOf: path)) ?? ""
        contents.append(string)
        contents.append("\n")
        try? contents.write(to: path, atomically: true, encoding: .utf8)
    }
    
}
