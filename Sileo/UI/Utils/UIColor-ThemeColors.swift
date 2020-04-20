//
//  UIColor-ThemeColors.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

extension UIColor {
    static var isTransitionLockedForiOS13Bug: Bool = false //Fucking Apple QA/QC
    
    private static var misDarkModeEnabled: Bool = false
    
    @objc static var isDarkModeEnabled: Bool {
        get {
            if #available(iOS 13, *) {
                if let window = UIApplication.shared.keyWindow {
                    return window.traitCollection.userInterfaceStyle == .dark
                } else if !UIApplication.shared.windows.isEmpty {
                    return UIApplication.shared.windows[0].traitCollection.userInterfaceStyle == .dark
                }
                return false
            }
            return misDarkModeEnabled
        }
        set {
            guard #available(iOS 13, *) else {
                misDarkModeEnabled = newValue
                return
            }
        }
    }
    
    @objc static let sileoDarkModeNotification = Notification.Name(rawValue: "SileoDarkModeNotification")
    
    static var sileoLabel: UIColor {
        if #available(iOS 13, *) {
            return .label
        }
        if isDarkModeEnabled {
            return .white
        }
        return .black
    }
    
    @objc static var useSileoColors: Bool {
        if #available(iOS 13, *) {
            return false
        }
        return true
    }
    
    @objc static var sileoBackgroundColor: UIColor {
        if isDarkModeEnabled {
            return UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        } else {
            return .white
        }
    }
    
    static var sileoContentBackgroundColor: UIColor {
        if isDarkModeEnabled {
            return UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1)
        } else {
            return UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
        }
    }
    
    static var sileoHighlightColor: UIColor {
        if isDarkModeEnabled {
            return UIColor(white: 0.2, alpha: 1)
        } else {
            return UIColor(white: 0.9, alpha: 1)
        }
    }
    
    static var sileoSeparatorColor: UIColor {       
        if isDarkModeEnabled {
            return UIColor(red: 71.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1)
        } else {
            return UIColor(red: 234.0/255.0, green: 234.0/255.0, blue: 236.0/255.0, alpha: 1)
        }
    }
    
    static var sileoBannerColor: UIColor {
        if isDarkModeEnabled {
            return UIColor(red: 0.059, green: 0.004, blue: 0, alpha: 1)
        } else {
            return UIColor(red: 0.941, green: 0.996, blue: 1, alpha: 1)
        }
    }
    
    @objc static var sileoHeaderColor: UIColor {
        if isDarkModeEnabled {
            return UIColor(red: 0.02, green: 0.1, blue: 0.2, alpha: 0.5)
        } else {
            return UIColor(red: 0.898, green: 0.98, blue: 1, alpha: 0.5)
        }
    }
}
