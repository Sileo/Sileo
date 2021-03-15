//
//  Store.swift
//  Sileo
//
//  Created by CoolStar on 9/10/16.
//  Copyright © 2016 CoolStar. All rights reserved.
//

import Foundation

// swiftlint:disable all
let StoreEndpoint = "https://featuredpage.getsileo.app/"
let StoreVersion = "0.7.1"

func StoreURL(_ relativePath: String) -> URL? {
    URL(string: StoreEndpoint.appending(relativePath))
}

#if TARGET_SANDBOX || targetEnvironment(simulator)
let TEST_UDID = "da39a3ee5e6b4b0d3255bfef95601890afd80709"
let TEST_DEVICE = "iPhone10,3"
#endif
// swiftlint:enable all
