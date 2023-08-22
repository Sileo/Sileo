//
//  FeaturedInfoFooterView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class FeaturedInfoFooterView: FeaturedBaseView {
    let label: UILabel
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        label = UILabel(frame: .zero)
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        label.textAlignment = .center
        self.addSubview(label)
        
        let sileoPackage = FeaturedInfoFooterView.package
        var sileoVersion = sileoPackage?.version ?? "Unknown"

        let platform = UIDevice.current.platform
        let systemVersion = UIDevice.current.systemVersion
        var systemPlatform = "iOS"
        
        if #available(iOS 13.0, *) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                systemPlatform = "iPadOS"
            }
        }
        
        if sileoVersion == "Unknown" {
            if let sileoVersionBundle = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                sileoVersion = sileoVersionBundle
            } else {
                sileoVersion = "Unknown"
            }
        }

        label.text = "\(platform) • \(systemPlatform) \(systemVersion) • Sileo \(sileoVersion)\n\(Jailbreak.current.rawValue) • \(Jailbreak.bootstrap.rawValue)"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.numberOfLines = 3
        label.adjustsFontSizeToFitWidth = true
    }
    
    static var package: Package? {
        switch Bundle.main.bundleIdentifier {
        case "org.coolstar.SileoBeta": return PackageListManager.shared.installedPackage(identifier: "org.coolstar.sileobeta")
        case "org.coolstar.SileoNightly": return PackageListManager.shared.installedPackage(identifier: "org.coolstar.sileonightly")
        default: return PackageListManager.shared.installedPackage(identifier: "org.coolstar.sileo")
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        48
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = CGRect(origin: self.bounds.origin,
                             size: CGSize(width: self.bounds.width, height: 39.5))
    }
}
