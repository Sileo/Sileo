//
//  AltIconTableViewCell.swift
//  Sileo
//
//  Created by Andromeda on 21/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import UIKit

class AltIconTableViewCell: UITableViewCell {
    
    private var label = UILabel()
    private var iconView = UIImageView()
    var altIcon: AltIcon? {
        didSet {
            if let altIcon = altIcon {
                self.label.text = altIcon.displayName
                self.iconView.image = altIcon.image
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(iconView)
        self.contentView.addSubview(label)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 75).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 75).isActive = true
        iconView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 17.5).isActive = true
        iconView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 7.5).isActive = true
        iconView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -7.5).isActive = true
        iconView.layer.masksToBounds = true
        iconView.layer.cornerRadius = 12.5
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        label.leadingAnchor.constraint(equalTo: self.iconView.trailingAnchor, constant: 7.5).isActive = true
        label.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 7.5).isActive = true
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
