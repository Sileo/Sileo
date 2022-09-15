//
//  FeaturedButton.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class FeaturedButton: DepictionButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setTitleColor(UIColor(red: 44/255.0, green: 177/255.0, blue: 190/255.0, alpha: 1), for: .normal)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateHighlight),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.updateHighlight()
    }
    
    @objc func updateHighlight() {
        if isLink {
            self.backgroundColor = .clear
        } else {
            self.backgroundColor = .sileoContentBackgroundColor
        }
        
        if isHighlighted {
            var tintHue: CGFloat = 0
            var tintSat: CGFloat = 0
            var tintBrightness: CGFloat = 0
            UIColor.tintColor.getHue(&tintHue, saturation: &tintSat, brightness: &tintBrightness, alpha: nil)
            
            tintBrightness *= 0.75
            
            self.setTitleColor(UIColor(hue: tintHue, saturation: tintSat, brightness: tintBrightness, alpha: 1), for: .normal)
        } else {
            self.setTitleColor(.tintColor, for: .normal)
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            self.updateHighlight()
        }
    }
}
