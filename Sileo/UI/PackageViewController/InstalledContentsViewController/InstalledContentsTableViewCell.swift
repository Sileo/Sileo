//
//  InstalledContentsTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 8/4/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class InstalledContentsTableViewCell: UITableViewCell {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.backgroundColor = .clear
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.textLabel?.textColor = .sileoLabel
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.textLabel?.textColor = .sileoLabel
    }
    
    @objc func updateSileoColors() {
        self.textLabel?.textColor = .sileoLabel
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        guard var imageFrame = imageView?.frame else {
            return
        }

        let offset = CGFloat(indentationLevel) * indentationWidth
        imageFrame.origin.x += offset
        imageView?.frame = imageFrame
    }
}
