//
//  NativePackageViewController.swift
//  Sileo
//
//  Created by Andromeda on 31/08/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit
import DepictionKit

protocol PackageActions: UIViewController {
    @available (iOS 13.0, *)
    func actions() -> [UIAction]
}

class NativePackageViewController: UIViewController, PackageActions {
    
    public var package: Package
    public var downloadButton: PackageQueueButton = PackageQueueButton()
    
    public var theme: Theme {
        Theme(text_color: .sileoLabel,
              background_color: .sileoBackgroundColor,
              tint_color: .tintColor,
              separator_color: .sileoSeparatorColor,
              dark_mode: UIColor.isDarkModeEnabled)
    }
    
    public class func viewController(for package: Package) -> PackageActions {
        if package.nativeDepiction == nil {
            let packageVC = PackageViewController(nibName: "PackageViewController", bundle: nil)
            packageVC.package = package
            return packageVC
        }
        return NativePackageViewController(package: package)
    }
    
    init(package: Package) {
        self.package = package
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @available (iOS 13.0, *)
    func actions() -> [UIAction] {
        _ = self.view
        return downloadButton.actionItems().map({ $0.action() })
    }

}
