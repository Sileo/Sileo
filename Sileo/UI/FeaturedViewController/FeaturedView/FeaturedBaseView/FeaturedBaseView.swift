//
//  FeaturedBaseView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//
//  Make sure to also update DepictionBaseView.swift

import Foundation

protocol FeaturedViewDelegate: DepictionViewDelegate {
}

open class FeaturedBaseView: DepictionBaseView {
    @objc override class func view(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor?, isActionable: Bool) -> DepictionBaseView? {
        guard let className = dictionary["class"] as? String else {
            return nil
        }
        
        guard let rawclass = Bundle.main.classNamed("Sileo.\(className)") as? DepictionBaseView.Type else {
            return nil
        }
        
        var tintColor: UIColor = tintColor ?? UINavigationBar.appearance().tintColor
        if let tintColorStr = dictionary["tintColor"] as? String {
            tintColor = UIColor(css: tintColorStr) ?? UINavigationBar.appearance().tintColor
        }
        
        return rawclass.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
    }
    
    required public init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
