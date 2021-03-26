//
//  AltIconTableViewCell.swift
//  Sileo
//
//  Created by Amy on 21/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import UIKit

class AltIconTableViewCell: UITableViewCell {
    
    private var iconName = UILabel()
    private var iconView = UIImageView()
    private var author = UILabel()
    var altIcon: AltIcon? {
        didSet {
            if let altIcon = altIcon {
                self.iconName.text = altIcon.displayName
                self.iconView.image = altIcon.image
                self.author.text = altIcon.author
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(iconView)
        self.contentView.addSubview(iconName)
        self.contentView.addSubview(author)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 60).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        iconView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 17.5).isActive = true
        iconView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        iconView.layer.masksToBounds = true
        iconView.layer.cornerRadius = 15
        
        iconName.translatesAutoresizingMaskIntoConstraints = false
        iconName.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant: -7.5).isActive = true
        iconName.leadingAnchor.constraint(equalTo: self.iconView.trailingAnchor, constant: 7.5).isActive = true
        iconName.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 7.5).isActive = true
        iconName.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        author.translatesAutoresizingMaskIntoConstraints = false
        author.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant: 10).isActive = true
        author.leadingAnchor.constraint(equalTo: self.iconView.trailingAnchor, constant: 7.5).isActive = true
        author.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 7.5).isActive = true
        author.font = UIFont.systemFont(ofSize: 13, weight: .light)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
