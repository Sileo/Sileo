//
//  SileoSeparatorView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SileoSeparatorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        weak var weakSelf: SileoSeparatorView? = self
        if #available(iOS 13, *) {
            self.backgroundColor = .separator
        } else if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoSeparatorView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.backgroundColor = .sileoSeparatorColor
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        weak var weakSelf: SileoSeparatorView? = self
        if #available(iOS 13, *) {
            self.backgroundColor = .separator
        } else if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoSeparatorView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.backgroundColor = .sileoSeparatorColor
        }
    }
    
    @objc func updateSileoColors() {
        if UIColor.useSileoColors {
            self.backgroundColor = .sileoSeparatorColor
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            self.backgroundColor = .sileoSeparatorColor
        }
    }
}
