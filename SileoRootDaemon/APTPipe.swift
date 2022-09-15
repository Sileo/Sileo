//
//  APTPipe.swift
//  SileoRootDaemon
//
//  Created by Andromeda on 13/07/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

#if targetEnvironment(macCatalyst) || os(macOS)
@objc public class AptRootPipeWrapper: NSObject, AptRootPipeProtocol {
    
    var stdoutCompletion: ((String) -> Void)?
    var stderrCompletion: ((String) -> Void)?
    var statusFdCompletion: ((String) -> Void)?
    var pipeCompletion: ((Int) -> Void)?
    
    public func stdout(str: String) {
        stdoutCompletion?(str)
    }
    
    public func stderr(str: String) {
        stderrCompletion?(str)
    }
    
    public func statusFd(str: String) {
        statusFdCompletion?(str)
    }
    
    public func completion(status: Int) {
        pipeCompletion?(status)
    }
}
#endif
