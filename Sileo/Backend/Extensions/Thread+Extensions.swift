//
//  Thread+Extensions.swift
//  Sileo
//
//  Created by Andromeda on 26/12/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation

extension Thread {
    
    public class func mainBlock(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
}
