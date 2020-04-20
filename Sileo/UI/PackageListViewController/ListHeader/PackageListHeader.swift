//
//  PackageListHeader.swift
//  Sileo
//
//  Created by CoolStar on 7/9/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import UIKit

class PackageListHeader: UICollectionReusableView {
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var toolbar: UIToolbar?
    @IBOutlet weak var upgradeButton: UIButton?
    @IBOutlet weak var sortButton: UIButton?
    @IBOutlet weak var separatorView: UIImageView?
    @IBOutlet weak var settingsButton: UIButton?
    @IBOutlet weak var settingsControl: UISegmentedControl?

    override func awakeFromNib() {
        super.awakeFromNib()
        toolbar?._hidesShadow = true
        toolbar?.tag = WHITE_BLUR_TAG
        
        weak var weakSelf: PackageListHeader? = self
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(PackageListHeader.updateSileoColors),
                                                   name: UIColor.sileoDarkModeNotification,
                                                   object: nil)
            label?.textColor = .sileoLabel
        }
    }
    
    @objc func updateSileoColors() {
        if UIColor.useSileoColors {
            label?.textColor = .sileoLabel
        }
    }
    
    public var actionText: String? {
        didSet {
            if let actionText = actionText {
                upgradeButton?.setTitle(actionText, for: .normal)
                upgradeButton?.isHidden = false
            } else {
                upgradeButton?.isHidden = true
            }
        }
    }
}
