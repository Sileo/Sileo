//
//  SettingsLoadingTableViewCell.swift
//  Sileo
//
//  Created by Skitty on 1/27/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SettingsLoadingTableViewCell: UITableViewCell {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = UITableViewCell.SelectionStyle.none
        self.accessoryType = UITableViewCell.AccessoryType.none
        let loadingView: UIActivityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.startAnimating()
        self.addSubview(loadingView)
        
        loadingView.centerXAnchor.constraint(greaterThanOrEqualTo: self.centerXAnchor).isActive = true
        loadingView.centerYAnchor.constraint(greaterThanOrEqualTo: self.centerYAnchor).isActive = true
    }
}
