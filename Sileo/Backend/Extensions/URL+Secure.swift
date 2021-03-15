//
//  URL+Secure.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

extension URL {
    var isSecure: Bool {
        self.isSecure(prefix: "")
    }
    
    func isSecure(prefix: String) -> Bool {
        #if TARGET_SANDBOX || targetEnvironment(simulator)
        return prefix.isEmpty || self.scheme?.lowercased().hasPrefix(prefix) == true
        #else
        let expectedScheme = prefix.isEmpty ? "https" : String(format: "%@-https", prefix.lowercased())
        return expectedScheme == self.scheme?.lowercased()
        #endif
    }
}
