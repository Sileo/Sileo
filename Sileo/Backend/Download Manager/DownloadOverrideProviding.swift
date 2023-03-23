//
//  DownloadOverrideProviding.swift
//  Sileo
//
//  Created by CoolStar on 7/23/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

protocol DownloadOverrideProviding {
    func downloadURL(for package: Package, from repo: Repo, completionHandler: @escaping (String?, URL?) -> Void) -> Bool
    
    var hashableObject: AnyHashable { get }
}
