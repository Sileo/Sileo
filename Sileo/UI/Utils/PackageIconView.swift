//
//  PackageIconView.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class PackageIconView: UIImageView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.backgroundColor = UIColor(white: 246.0/255.0, alpha: 1)
        self.layer.setValue(true, forKey: "continuousCorners")
        self.clipsToBounds = true
        self.accessibilityIgnoresInvertColors = true
        self.contentMode = .scaleAspectFill
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = fmin(self.bounds.width, self.bounds.height)/4
    }
}
