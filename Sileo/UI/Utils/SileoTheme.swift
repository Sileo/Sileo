//
//  SileoTheme.swift
//  Sileo
//
//  Created by Skitty on 8/2/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

@objc enum SileoThemeInterfaceStyle: Int, Codable {
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
    
    var codable: SileoCodableTheme {
        SileoCodableTheme(name: name, preferredUserInterfaceStyle: preferredUserInterfaceStyle, backgroundColor: .init(backgroundColor), secondaryBackgroundColor: .init(secondaryBackgroundColor), labelColor: .init(labelColor), highlightColor: .init(highlightColor), seperatorColor: .init(seperatorColor), headerColor: .init(headerColor), bannerColor: .init(bannerColor))
    }
    
    init(name: String, interfaceStyle: SileoThemeInterfaceStyle) {
        self.name = name
        preferredUserInterfaceStyle = interfaceStyle
    }
}

// The following 2 structs, CodableColor and SileoCodableTheme,
// Exist for the purpose of being able to encode and save a theme.
// CodableColor interops with UIColor
// and SileoCodableTheme interops with the non-Codable SileoTheme class


struct CodableColor: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    
    var uiColor: UIColor {
        .init(red: self.red, green: self.green, blue: self.blue, alpha: self.alpha)
    }
    
    init?(_ color: UIColor?) {
        guard let color = color,
        let rgba = color.rgba else {
            return nil
        }

        self.red = rgba.red
        self.green = rgba.green
        self.blue = rgba.blue
        self.alpha = rgba.alpha
    }
}


struct SileoCodableTheme: Codable {
    let name: String
    var preferredUserInterfaceStyle: SileoThemeInterfaceStyle = .dark
    
    var backgroundColor: CodableColor?
    var secondaryBackgroundColor: CodableColor?
    var labelColor: CodableColor?
    var highlightColor: CodableColor?
    var seperatorColor: CodableColor?
    var headerColor: CodableColor?
    var bannerColor: CodableColor?
    
    var sileoTheme: SileoTheme {
        let theme = SileoTheme(name: name, interfaceStyle: preferredUserInterfaceStyle)
        theme.backgroundColor = backgroundColor?.uiColor
        theme.secondaryBackgroundColor = secondaryBackgroundColor?.uiColor
        theme.labelColor = labelColor?.uiColor
        theme.highlightColor = highlightColor?.uiColor
        theme.seperatorColor = seperatorColor?.uiColor
        theme.headerColor = headerColor?.uiColor
        theme.bannerColor = bannerColor?.uiColor
        return theme
    }
}
