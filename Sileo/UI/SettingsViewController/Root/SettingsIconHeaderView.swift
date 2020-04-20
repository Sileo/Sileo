//
//  SettingsIconHeaderView.swift
//  Sileo
//
//  Created by Skitty on 1/26/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class SettingsIconHeaderView: UIView, SettingsHeaderViewDisplayable {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let iconView: UIImageView = UIImageView()
        iconView.image = UIImage(named: "AppIconDisplay")
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.layer.setValue(true, forKey: "continuousCorners")
        iconView.layer.cornerRadius = 29 // size / 4
        self.addSubview(iconView)
        
        iconView.widthAnchor.constraint(equalToConstant: 116).isActive = true
        iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor).isActive = true
        iconView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        iconView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -20).isActive = true
    }
    
    func headerHeight(forWidth width: CGFloat) -> CGFloat {
        192
    }
}
