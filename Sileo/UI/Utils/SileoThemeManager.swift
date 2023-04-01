//
//  SileoThemeManager.swift
//  Sileo
//
//  Created by Skitty on 8/2/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Evander
import ZippyJSON

func dynamicColor(default defaultColor: UIColor, dark: UIColor) -> UIColor {
    if #available(iOS 13.0, *) {
        return UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return dark
            } else {
                return defaultColor
            }
        })
    }
    return defaultColor
}

class SileoThemeManager: NSObject {
    @objc static var shared = SileoThemeManager()
    static let sileoChangedThemeNotification = Notification.Name("sileoChangedThemeNotification")
    
    var tintColor: UIColor
    
    @objc var currentTheme: SileoTheme
    var themeList = [SileoTheme]()
    
    override init() {
        let lightTheme = SileoTheme(name: String(localizationKey: "Sileo_Light"), interfaceStyle: .light)
        lightTheme.backgroundColor = .white
        lightTheme.secondaryBackgroundColor = UIColor(white: 245/255, alpha: 1)
        lightTheme.labelColor = .black
        lightTheme.highlightColor = UIColor(white: 0.9, alpha: 1)
        lightTheme.seperatorColor = UIColor(red: 234.0/255.0, green: 234.0/255.0, blue: 236.0/255.0, alpha: 1)
        lightTheme.headerColor = UIColor(red: 0.898, green: 0.98, blue: 1, alpha: 0.5)
        lightTheme.bannerColor = UIColor(red: 0.941, green: 0.996, blue: 1, alpha: 1)
        themeList.append(lightTheme)

        let darkTheme = SileoTheme(name: String(localizationKey: "Sileo_Dark"), interfaceStyle: .dark)
        darkTheme.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        darkTheme.secondaryBackgroundColor = UIColor(white: 60/255, alpha: 1)
        darkTheme.labelColor = .white
        darkTheme.highlightColor = UIColor(white: 0.2, alpha: 1)
        darkTheme.seperatorColor = UIColor(red: 71.0/255.0, green: 71.0/255.0, blue: 73.0/255.0, alpha: 1)
        darkTheme.headerColor = UIColor(red: 0.02, green: 0.1, blue: 0.2, alpha: 0.5)
        darkTheme.bannerColor = UIColor(red: 0.059, green: 0.004, blue: 0, alpha: 1)
        themeList.append(darkTheme)
        
        if #available(iOS 13.0, *) {
            let adaptiveTheme = SileoTheme(name: String(localizationKey: "Sileo_Adaptive"), interfaceStyle: .system)
            adaptiveTheme.backgroundColor = dynamicColor(default: .white,
                                                         dark: UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1))
            adaptiveTheme.secondaryBackgroundColor = dynamicColor(default: UIColor(white: 245/255, alpha: 1),
                                                                  dark: UIColor(white: 60/255, alpha: 1))
            adaptiveTheme.labelColor = .label
            adaptiveTheme.highlightColor = dynamicColor(default: UIColor(white: 0.9, alpha: 1),
                                                        dark: UIColor(white: 0.2, alpha: 1))
            adaptiveTheme.seperatorColor = .separator
            adaptiveTheme.headerColor = dynamicColor(default: UIColor(red: 0.898, green: 0.98, blue: 1, alpha: 0.5),
                                                     dark: UIColor(red: 0.02, green: 0.1, blue: 0.2, alpha: 0.5))
            adaptiveTheme.bannerColor = dynamicColor(default: UIColor(red: 0.941, green: 0.996, blue: 1, alpha: 1),
                                                     dark: UIColor(red: 0.059, green: 0.004, blue: 0, alpha: 1))
            themeList.append(adaptiveTheme)
            
            let systemTheme = SileoTheme(name: String(localizationKey: "System"), interfaceStyle: .system)
            systemTheme.backgroundColor = .systemBackground
            systemTheme.secondaryBackgroundColor = .secondarySystemBackground
            systemTheme.labelColor = .label
            systemTheme.highlightColor = .tertiarySystemBackground
            systemTheme.seperatorColor = .separator
            systemTheme.headerColor = .tertiarySystemBackground
            themeList.append(systemTheme)
        }
        
        var defaultTheme = "Sileo Light"
        if #available(iOS 13.0, *) {
            defaultTheme = "Sileo Adaptive"
        }
        
        let fallbackColor = UIColor(red: 44/255, green: 177/255, blue: 190/255, alpha: 1)
        if let archivedData = UserDefaults.standard.value(forKey: "tintColor") as? Data {
            let unarchivedData = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archivedData) as? UIColor
            self.tintColor = unarchivedData ?? fallbackColor
        } else {
            self.tintColor = fallbackColor
        }
        
        if let userSavedThemesData = UserDefaults.standard.data(forKey: "userSavedThemes"), let userSavedThemes = try? ZippyJSONDecoder().decode([SileoCodableTheme].self, from: userSavedThemesData) {
            themeList.append(contentsOf: Array(Set(userSavedThemes.map { $0.sileoTheme })))
        }
        
        themeList = Array(Set(themeList)) // duplicate removal
        
        let strings = themeList.map({ $0.name })
        currentTheme = themeList[strings.firstIndex(of: UserDefaults.standard.value(forKey: "currentTheme") as? String ?? defaultTheme) ?? 0]
        
        super.init()
    }
    
    func activate(theme: SileoTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.name, forKey: "currentTheme")
        FRUIView.animate(withDuration: 0.25) {
            NotificationCenter.default.post(name: SileoThemeManager.sileoChangedThemeNotification, object: nil)
        }
        updateUserInterface()
    }
    
    func resetTintColor() {
        setTintColor(UIColor(red: 44/255, green: 177/255, blue: 190/255, alpha: 1))
    }
    
    func setTintColor(_ color: UIColor) {
        tintColor = color
        
        if let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            UserDefaults.standard.set(archivedData, forKey: "tintColor")
        }
        
        FRUIView.animate(withDuration: 0.25) {
            NotificationCenter.default.post(name: SileoThemeManager.sileoChangedThemeNotification, object: nil)
        }
    }
    
    func updateUserInterface() {
        if #available(iOS 13.0, *) {
            for window in UIApplication.shared.windows {
                if currentTheme.preferredUserInterfaceStyle == .light {
                    window.overrideUserInterfaceStyle = .light
                } else if currentTheme.preferredUserInterfaceStyle == .dark {
                    window.overrideUserInterfaceStyle = .dark
                } else {
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
        if let barButton = NSClassFromString("UICalloutBarButton") as? UIButton.Type {
            let button = barButton.appearance()
            button.setTitleColor(UIColor.isDarkModeEnabled ? .black : .white, for: .normal)
            button.backgroundColor = UIColor.isDarkModeEnabled ? UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.00) : UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.00)
        }
    }
}
