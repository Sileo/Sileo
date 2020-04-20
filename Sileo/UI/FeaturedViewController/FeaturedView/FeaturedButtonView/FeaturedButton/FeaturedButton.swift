//
//  FeaturedButton.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class FeaturedButton: DepictionButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setTitleColor(UIColor(red: 44/255.0, green: 177/255.0, blue: 190/255.0, alpha: 1), for: .normal)
        
        NotificationCenter.default.addObserver(self, selector: #selector(FeaturedButton.updateHighlight), name: UIColor.sileoDarkModeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.updateHighlight()
    }
    
    @objc func updateHighlight() {
        if #available(iOS 13, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                self.backgroundColor = UIColor(red: 60/255.0, green: 64/255.0, blue: 65/255.0, alpha: 1)
            } else {
                self.backgroundColor = UIColor(red: 240/255.0, green: 244/255.0, blue: 245/255.0, alpha: 1)
            }
        } else if UIColor.useSileoColors {
            if UIColor.isDarkModeEnabled {
                self.backgroundColor = UIColor(red: 60/255.0, green: 64/255.0, blue: 65/255.0, alpha: 1)
            } else {
                self.backgroundColor = UIColor(red: 240/255.0, green: 244/255.0, blue: 245/255.0, alpha: 1)
            }
        }
        if isHighlighted {
            self.setTitleColor(UIColor(red: 44/255.0, green: 177/255.0, blue: 190/255.0, alpha: 1), for: .normal)
        } else {
            self.setTitleColor(UIColor(red: 44/255.0, green: 177/255.0, blue: 190/255.0, alpha: 1), for: .normal)
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            self.updateHighlight()
        }
    }
}
