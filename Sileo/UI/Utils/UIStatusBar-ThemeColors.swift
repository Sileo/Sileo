//
//  UIStatusBar-ThemeColors.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

extension UIApplication {
    static var enableStatusBarFlip: Bool = true
    
    static var sileoLightStatusBarStyle: UIStatusBarStyle {
        if UIColor.isDarkModeEnabled {
            return .default
        } else {
            return .lightContent
        }
    }
    
    static var sileoDefaultStatusBarStyle: UIStatusBarStyle {
        if UIColor.isDarkModeEnabled {
            return .lightContent
        } else {
            return .default
        }
    }
    
    func flipStatusBar() {
        guard UIApplication.enableStatusBarFlip else {
            return
        }
        if self.statusBarStyle == .lightContent {
            self.statusBarStyle = .default
        } else {
            self.statusBarStyle = .lightContent
        }
    }
}
