//
//  DepictionFormTextView.swift
//  Sileo
//
//  Created by Amy on 30/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit

class DepictionFormTextView: UITableViewCell {
    
    public var textField = InsetTextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(textField)
        self.backgroundColor = .none
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        textField.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor).isActive = true
        textField.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor).isActive = true
        textField.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        textField.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        
        self.updateSileoColors()
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.updateSileoColors()
    }
    
    @objc private func updateSileoColors() {
        if #available(iOS 13.0, *) {
            textField.overrideUserInterfaceStyle = UIColor.isDarkModeEnabled ? .dark : .light
        }
        textField.textColor = .sileoLabel
        if UIColor.isDarkModeEnabled {
            textField.backgroundColor = .sileoContentBackgroundColor
        } else {
            textField.backgroundColor = .sileoBackgroundColor
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class InsetTextField: UITextField {
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: 20, dy: 0)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: 20, dy: 0)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: 20, dy: 0)
    }
    
}
