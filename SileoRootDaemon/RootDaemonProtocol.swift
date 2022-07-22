//
//  RootDaemonProtocol.swift
//  Sileo
//
//  Created by Andromeda on 12/07/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
#if targetEnvironment(macCatalyst) || os(macOS)
// swiftlint:disable identifier_name
let DaemonVersion = "2.2-40"

@objc public protocol RootHelperProtocol {
    func spawn(command: String, args: [String], _ completion: @escaping (Int, String, String) -> Void)
    func version(_ completion: @escaping (String) -> Void)
    func spawnAsRoot(command: String, args: [String])
}

@objc public protocol AptRootPipeProtocol {
    @objc optional func stdout(str: String)
    @objc optional func stderr(str: String)
    @objc optional func statusFd(str: String)
    @objc optional func completion(status: Int)
}
#endif
