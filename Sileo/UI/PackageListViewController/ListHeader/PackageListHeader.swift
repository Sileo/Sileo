//
//  PackageListHeader.swift
//  Sileo
//
//  Created by CoolStar on 7/9/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

class PackageListHeader: UICollectionReusableView {
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var toolbar: UIToolbar?
    @IBOutlet weak var upgradeButton: UIButton?
    @IBOutlet weak var sortIcon: UIImageView?
    @IBOutlet weak var sortHeader: UILabel?
    @IBOutlet weak var separatorView: UIImageView?
    @IBOutlet weak var sortContainer: UIControl?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        toolbar?._hidesShadow = true
        toolbar?.tag = WHITE_BLUR_TAG
        
        sortIcon?.image = UIImage(named: "SortChevron")?.withRenderingMode(.alwaysTemplate)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        updateSileoColors()
    }
    
    @objc func updateSileoColors() {
        label?.textColor = .sileoLabel
        sortIcon?.tintColor = .tintColor
        sortHeader?.textColor = .tintColor
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
