//
//  DownloadConfirmButton.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DownloadConfirmButton: UIButton {
    
    @IBInspectable var pleaseJustLetMeBeClearThankYouLoveYouBye: Bool = false
    
    override var isHighlighted: Bool {
        didSet {
            if pleaseJustLetMeBeClearThankYouLoveYouBye {
                self.backgroundColor = .clear
                return
            }
            if isHighlighted {
                var tintHue: CGFloat = 0, tintSat: CGFloat = 0, tintBrightness: CGFloat = 0
                self.tintColor.getHue(&tintHue, saturation: &tintSat, brightness: &tintBrightness, alpha: nil)
                
                tintBrightness *= 0.75
                self.backgroundColor = UIColor(hue: tintHue, saturation: tintSat, brightness: tintBrightness, alpha: 1)
            } else {
                self.backgroundColor = self.tintColor
            }
        }
    }
}
