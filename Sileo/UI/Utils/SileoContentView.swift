//
//  SileoContentView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SileoContentView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.backgroundColor = .sileoContentBackgroundColor
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    @objc func updateSileoColors() {
        self.backgroundColor = .sileoContentBackgroundColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
}
