//
//  SileoRootView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SileoRootView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.backgroundColor = .sileoBackgroundColor
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        weak var weakSelf: SileoRootView? = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.backgroundColor = .sileoBackgroundColor
    }
    
    @objc func updateSileoColors() {
        self.backgroundColor = .sileoBackgroundColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
}
