//
//  SettingsIconHeaderView.swift
//  Sileo
//
//  Created by Skitty on 1/26/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SettingsIconHeaderView: UIView, SettingsHeaderViewDisplayable {
    
    private var observer: Any?
    private var iconView: UIImageView = UIImageView()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        guard let obs = observer else { return }
        NotificationCenter.default.removeObserver(obs)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setImage()
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.layer.setValue(true, forKey: "continuousCorners")
        iconView.layer.cornerRadius = 29 // size / 4
        self.addSubview(iconView)
        
        iconView.widthAnchor.constraint(equalToConstant: 116).isActive = true
        iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor).isActive = true
        iconView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        iconView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -20).isActive = true
        
        observer = NotificationCenter.default.addObserver(forName: AltIconTableViewController.IconUpdate,
                                                          object: nil,
                                                          queue: OperationQueue.main) { _ in
            self.setImage()
        }
    }
    
    private func setImage() {
        if let imageName = UIApplication.shared.alternateIconName {
            iconView.image = AltIconTableViewController.altImage(imageName)
        } else {
            iconView.image = AltIconTableViewController.altImage("AppIcon60x60")
        }
    }
    
    func headerHeight(forWidth width: CGFloat) -> CGFloat {
        192
    }
}
