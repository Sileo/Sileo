//
//  NewsGradientBackgroundView.swift
//  Sileo
//
//  Created by Skitty on 3/1/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class NewsGradientBackgroundView: UIView {
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    required init?(coder: NSCoder) {
        fatalError("initWithCoder not implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let layer = self.layer as? CAGradientLayer
        layer?.colors = [ UIColor.white.cgColor, UIColor(white: 247.0 / 255.0, alpha: 1).cgColor ]
        self.traitCollectionDidChange(self.traitCollection)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection) {
        updateColors()
    }
    
    @objc func updateColors() {
        let layer = self.layer as? CAGradientLayer
        if UIColor.isDarkModeEnabled {
            layer?.colors = [
                UIColor.sileoBackgroundColor.cgColor,
                UIColor(red: 36.0 / 255.0, green: 36.0 / 255.0, blue: 38.0 / 255.0, alpha: 1).cgColor
            ]
        } else {
            layer?.colors = [
                UIColor.sileoBackgroundColor.cgColor,
                UIColor(white: 247.0 / 255.0, alpha: 1).cgColor
            ]
        }
    }
}
