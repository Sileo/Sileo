//
//  Download.swift
//  Sileo
//
//  Created by CoolStar on 8/3/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation

final class Download {
    var package: Package
    var task: AmyDownloadParser?
    var backgroundTask: UIBackgroundTaskIdentifier?
    var progress = CGFloat(0)
    var failureReason: String?
    var totalBytesWritten = Int64(0)
    var totalBytesExpectedToWrite = Int64(0)
    var success = false
    var queued = true
    var completed = false
    var message: String?
    
    init(package: Package) {
        self.package = package
    }
}
