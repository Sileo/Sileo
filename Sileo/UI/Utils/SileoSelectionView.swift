//
//  SileoSelectionView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SileoSelectionView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.backgroundColor = .sileoHighlightColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.backgroundColor = .sileoHighlightColor
    }
    
    @objc func updateSileoColors() {
        self.backgroundColor = .sileoHighlightColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
}
