//
//  main.swift
//  Sileo
//
//  Created by CoolStar on 8/29/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

#if targetEnvironment(simulator) || TARGET_SANDBOX
#warning("Building for Sandboxed target. Many featuers will not be available")
#endif

UIApplicationMain(CommandLine.argc,
                  CommandLine.unsafeArgv,
                  nil,
                  NSStringFromClass(AppDelegate.self))
