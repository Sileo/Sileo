//
//  UIView+FromNib.swift
//  Sileo
//
//  Created by Amy on 18/03/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit

extension UITextView {
    #if targetEnvironment(macCatalyst)
    @objc(_focusRingType)
    var focusRingType: UInt {
        return 1
    }
    #endif
}
