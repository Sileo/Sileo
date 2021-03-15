//
//  Download.swift
//  Sileo
//
//  Created by CoolStar on 8/3/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import Alamofire

final class Download {
    var package: Package
    var task: DownloadRequest?
    var backgroundTask: UIBackgroundTaskIdentifier?
    var progress = CGFloat(0)
    var failureReason: String?
    var totalBytesWritten = Int64(0)
    var totalBytesExpectedToWrite = Int64(0)
    var success = false
    var queued = true
    var completed = false
    
    init(package: Package) {
        self.package = package
    }
}
