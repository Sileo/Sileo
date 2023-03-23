//
//  PackageStateBadgeView.swift
//  Sileo
//
//  Created by CoolStar on 7/29/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

@objc public enum PackageBadgeState: Int {
    case installed
    case installQueued
    case updateQueued
    case reinstallQueued
    case deleteQueued
}

@objc public class PackageStateBadgeView: UIView {
    @objc var state: PackageBadgeState = .installed {
        didSet {
            self.backgroundColor = self.backgroundColor(state: state)
            self.imageView.image = self.image(state: state)
        }
    }
    var imageView: UIImageView
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        
        super.init(frame: frame)
          
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.heightAnchor.constraint(equalToConstant: 12).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        
        self.addSubview(imageView)
        
        imageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 4).isActive = true
        imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -4).isActive = true
        imageView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 4).isActive = true
        imageView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -4).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
      
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = fmin(self.bounds.width, self.bounds.height)/2
    }
    
    func backgroundColor(state: PackageBadgeState) -> UIColor {
        switch state {
        case .installed:
            return UIColor(red: 0.278, green: 0.914, blue: 0.129, alpha: 1)
        case .installQueued, .updateQueued, .reinstallQueued:
            return UIColor(red: 0.176, green: 0.663, blue: 1, alpha: 1)
        case .deleteQueued:
            return .red
        }
    }
    
    func image(state: PackageBadgeState) -> UIImage? {
        switch state {
        case .installed:
            return UIImage(named: "Installed")
        case .installQueued:
            return UIImage(named: "InstallQueue")
        case .updateQueued:
            return UIImage(named: "UpdateQueue")
        case .reinstallQueued:
            return UIImage(named: "ReinstallQueue")
        case .deleteQueued:
            return UIImage(named: "DeleteQueue")
        }
    }
    
}
