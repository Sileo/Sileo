//
//  DownloadPackage.swift
//  Sileo
//
//  Created by CoolStar on 8/2/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

final class DownloadPackage: Hashable {
    public var package: Package
    
    init(package: Package) {
        self.package = package
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(package)
    }
}

func == (lhs: DownloadPackage, rhs: DownloadPackage) -> Bool {
    lhs.package.packageID == rhs.package.packageID
}
