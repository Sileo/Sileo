//
//  Download.swift
//  Sileo
//
//  Created by CoolStar on 8/3/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander

final class Download {
    var package: Package
    var task: EvanderDownloader?
    var backgroundTask: UIBackgroundTaskIdentifier?
    var progress = CGFloat(0)
    var failureReason: String?
    var totalBytesWritten = Int64(0)
    var totalBytesExpectedToWrite = Int64(0)
    var success = false
    var queued = false
    var completed = false
    var started = false
    var message: String?
    
    init(package: Package) {
        self.package = package
    }
}
