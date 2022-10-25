//
//  TabBar.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class TabBar: UITabBar {
    override var traitCollection: UITraitCollection {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return super.traitCollection
        }
        if UIApplication.shared.statusBarOrientation.isLandscape && self.bounds.width >= 400 {
            return super.traitCollection
        }
        return UITraitCollection(traitsFrom: [super.traitCollection, UITraitCollection(horizontalSizeClass: .compact)])
    }
}
