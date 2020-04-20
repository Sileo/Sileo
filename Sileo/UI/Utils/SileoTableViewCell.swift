//
//  SileoTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 9/8/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SileoTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        weak var weakSelf: SileoTableViewCell? = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(SileoTableViewCell.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            self.textLabel?.textColor = .sileoLabel
            
            self.selectedBackgroundView = SileoSelectionView(frame: .zero)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func updateSileoColors() {
        if UIColor.useSileoColors {
            self.textLabel?.textColor = .sileoLabel
        }
    }
}
