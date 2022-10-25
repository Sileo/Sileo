//
//  SourcesSplitViewController.swift
//  Sileo
//
//  Created by CoolStar on 1/2/21.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

class SourcesSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        self.preferredDisplayMode = .allVisible
        self.title = String(localizationKey: "Sources_Page")
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        if secondaryViewController is UINavigationController {
            return false
        }
        return true
    }
    
    override var childForStatusBarStyle: UIViewController? {
        if isCollapsed {
            return viewControllers.last
        } else {
            return viewControllers.first
        }
    }
    
    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        if let navController = viewControllers.first as? UINavigationController {
            navController.navigationBar.tintColor = UINavigationBar.appearance().tintColor
            navController.navigationBar._backgroundOpacity = 1
        }
    }
}
