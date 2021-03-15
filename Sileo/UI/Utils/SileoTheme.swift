//
//  SileoTheme.swift
//  Sileo
//
//  Created by Skitty on 8/2/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import UIKit

@objc enum SileoThemeInterfaceStyle: Int {
    case dark = 0
    case light
    case system
}

class SileoTheme: NSObject {
    var name: String
    @objc var preferredUserInterfaceStyle = SileoThemeInterfaceStyle.dark
    
    var backgroundColor: UIColor?
    var secondaryBackgroundColor: UIColor?
    var labelColor: UIColor?
    var highlightColor: UIColor?
    var seperatorColor: UIColor?
    var headerColor: UIColor?
    var bannerColor: UIColor?
    
    init(name: String, interfaceStyle: SileoThemeInterfaceStyle) {
        self.name = name
        preferredUserInterfaceStyle = interfaceStyle
    }
}
