//
//  main.swift
//  Sileo
//
//  Created by CoolStar on 8/29/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

#if TARGET_SANDBOX || targetEnvironment(simulator)
#warning("Building for Sandboxed target. Many features will not be available")
#endif

UIApplicationMain(CommandLine.argc,
                  CommandLine.unsafeArgv,
                  nil,
                  NSStringFromClass(AppDelegate.self))
