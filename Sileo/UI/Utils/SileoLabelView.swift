//
//  SileoLabelView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SileoLabelView: UILabel {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        weak var weakSelf: SileoLabelView? = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoLabelView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.textColor = .sileoLabel
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        weak var weakSelf: SileoLabelView? = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoLabelView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.textColor = .sileoLabel
        }
    }
    
    @objc func updateSileoColors() {
        if UIColor.useSileoColors {
            self.textColor = .sileoLabel
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            self.textColor = .sileoLabel
        }
    }
}
