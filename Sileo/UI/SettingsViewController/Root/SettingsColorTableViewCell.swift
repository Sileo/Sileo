//
//  SettingsColorTableViewCell.swift
//  Sileo
//
//  Created by Skitty on 8/9/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

class SettingsColorTableViewCell: UITableViewCell {
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var bgClr: UIColor? = nil {
        willSet {
            accessoryView?.backgroundColor = newValue
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = .clear
        
        let colorPreview = UIView(frame: CGRect(x: 0, y: 0, width: 29, height: 29))
        colorPreview.backgroundColor = .tintColor
        colorPreview.layer.cornerRadius = colorPreview.frame.size.width / 2
        colorPreview.layer.borderWidth = 1.5
        colorPreview.layer.borderColor = UIColor.sileoContentBackgroundColor.cgColor
        
        accessoryView = colorPreview
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        accessoryView?.backgroundColor = bgClr ?? .tintColor
    }
}
