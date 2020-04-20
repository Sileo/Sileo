//
//  SileoSelectionView.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SileoSelectionView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        weak var weakSelf = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoSelectionView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.backgroundColor = .sileoHighlightColor
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        weak var weakSelf = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoSelectionView.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.backgroundColor = .sileoHighlightColor
        }
    }
    
    @objc func updateSileoColors() {
        if UIColor.useSileoColors {
            self.backgroundColor = .sileoHighlightColor
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            self.backgroundColor = .sileoHighlightColor
        }
    }
}
