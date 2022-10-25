//
//  SettingsHeaderViewDisplayable.swift
//  Sileo
//
//  Created by Skitty on 1/27/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

protocol SettingsHeaderViewDisplayable: NSObject {
    func headerHeight(forWidth: CGFloat) -> CGFloat
}
