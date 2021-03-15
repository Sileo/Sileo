//
//  FeaturedInfoFooterView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class FeaturedInfoFooterView: FeaturedBaseView {
    let label: UILabel
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        label = UILabel(frame: .zero)
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        label.textAlignment = .center
        self.addSubview(label)
        
        let sileoPackage = PackageListManager.shared.installedPackage(identifier: "org.coolstar.sileo")
        let sileoVersion = sileoPackage?.version ?? "Unknown"
        
        let platform = UIDevice.current.platform
        let systemVersion = UIDevice.current.systemVersion
        
        label.text = "\(platform), iOS \(systemVersion), Sileo \(sileoVersion)"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        
        if sileoVersion == "unknown" {
            DispatchQueue.global(qos: .userInitiated).async {
                PackageListManager.shared.waitForReady()
            
                DispatchQueue.main.async {
                    let sileoPackage2 = PackageListManager.shared.installedPackage(identifier: "org.coolstar.sileo")
                    let sileoVersion2 = sileoPackage2?.version ?? "Unknown"
                    self.label.text = "\(platform), iOS \(systemVersion), Sileo \(sileoVersion2)"
                }
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        15
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = self.bounds
    }
}
