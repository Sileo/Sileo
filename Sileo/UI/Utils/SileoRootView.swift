//
//  SileoRootView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SileoRootView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        weak var weakSelf: SileoRootView? = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoRootView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.backgroundColor = .sileoBackgroundColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        weak var weakSelf: SileoRootView? = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoRootView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.backgroundColor = .sileoBackgroundColor
        }
    }
    
    @objc func updateSileoColors() {
        if UIColor.useSileoColors {
            self.backgroundColor = .sileoBackgroundColor
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            self.backgroundColor = .sileoBackgroundColor
        }
    }
}
