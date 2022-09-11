//
//  InstalledContentsTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 8/4/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class InstalledContentsTableViewCell: UITableViewCell {
    
    public var node: FileNode?
    
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
    
    @objc public func openInFilza(_ sender: UIMenuController?) {
        guard let node = node else { return }
        let url = URL(string: "filza://\(node.path)")!
        UIApplication.shared.open(url)
    }
    
    @objc public func copyPath(_ sender: UIMenuController?) {
        guard let node = node else { return }
        UIPasteboard.general.string = node.path
    }
}
