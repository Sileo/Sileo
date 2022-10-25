//
//  CSGradientView.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class CSGradientView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        guard let layer = self.layer as? CAGradientLayer else {
            return
        }
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.colors = [UIColor(white: 0, alpha: 0).cgColor,
                        UIColor(white: 0, alpha: 0.2).cgColor,
                        UIColor(white: 0, alpha: 0.5).cgColor]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        guard let layer = self.layer as? CAGradientLayer else {
            return
        }
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.colors = [UIColor(white: 0, alpha: 0).cgColor,
                        UIColor(white: 0, alpha: 0.2).cgColor,
                        UIColor(white: 0, alpha: 0.5).cgColor]
    }
    
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
}
