//
//  PackageCollectionViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class PackageCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var titleLabel: UILabel?
    @IBOutlet var authorLabel: UILabel?
    @IBOutlet var descriptionLabel: UILabel?
    @IBOutlet var separatorView: UIView?
    @IBOutlet var unreadView: UIView?
    
    var item: CGFloat = 0
    var numberOfItems: CGFloat = 0
    var alwaysHidesSeparator = false
    var stateBadgeView: PackageStateBadgeView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public var targetPackage: Package? {
        didSet {
            if let targetPackage = targetPackage {
                titleLabel?.text = targetPackage.name
                authorLabel?.text = ControlFileParser.authorName(string: targetPackage.author ?? "")
                descriptionLabel?.text = targetPackage.packageDescription
            
                self.imageView?.sd_setImage(with: URL(string: targetPackage.icon ?? ""), placeholderImage: UIImage(named: "Tweak Icon"))
            
                titleLabel?.textColor = targetPackage.commercial ? self.tintColor : .sileoLabel
            }
            unreadView?.isHidden = true
            
            self.accessibilityLabel = String(format: String(localizationKey: "Package_By_Author"),
                                             self.titleLabel?.text ?? "", self.authorLabel?.text ?? "")
            
            self.refreshState()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.selectedBackgroundView = UIView()
        self.selectedBackgroundView?.backgroundColor = UIColor.lightGray.withAlphaComponent(0.25)
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        
        stateBadgeView = PackageStateBadgeView(frame: .zero)
        stateBadgeView?.translatesAutoresizingMaskIntoConstraints = false
        stateBadgeView?.state = .installed
        
        if let stateBadgeView = stateBadgeView {
            self.contentView.addSubview(stateBadgeView)
            
            if let imageView = imageView {
                stateBadgeView.centerXAnchor.constraint(equalTo: imageView.rightAnchor).isActive = true
                stateBadgeView.centerYAnchor.constraint(equalTo: imageView.bottomAnchor).isActive = true
            }
        }
        
        NotificationCenter.default.addObserver([self],
                                               selector: #selector(PackageCollectionViewCell.refreshState),
                                               name: DownloadManager.reloadNotification, object: nil)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    @objc func updateSileoColors() {
        if !(targetPackage?.commercial ?? false) {
            titleLabel?.textColor = .sileoLabel
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var numberOfItemsInRow = CGFloat(1)
        if UIDevice.current.userInterfaceIdiom == .pad || UIApplication.shared.statusBarOrientation.isLandscape {
            numberOfItemsInRow = (self.superview?.bounds.width ?? 0) / 300
        }
        
        if alwaysHidesSeparator || ceil((item + 1) / numberOfItemsInRow) == ceil(numberOfItems / numberOfItemsInRow) {
            separatorView?.isHidden = true
        } else {
            separatorView?.isHidden = false
        }
    }
    
    func setTargetPackage(_ package: Package, isUnread: Bool) {
        self.targetPackage = package
        unreadView?.isHidden = !isUnread
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        
        if targetPackage?.commercial ?? false {
            titleLabel?.textColor = self.tintColor
        }
        
        unreadView?.backgroundColor = self.tintColor
    }
    
    @objc func refreshState() {
        stateBadgeView?.isHidden = false
        guard let targetPackage = targetPackage else {
            return
        }
        
        let queueState = DownloadManager.shared.find(package: targetPackage)
        let isInstalled = PackageListManager.shared.installedPackage(identifier: targetPackage.package) != nil
        switch queueState {
        case .installations:
            stateBadgeView?.state = isInstalled ? .reinstallQueued : .installQueued
        case .upgrades:
            stateBadgeView?.state = .updateQueued
        case .uninstallations:
            stateBadgeView?.state = .deleteQueued
        default:
            stateBadgeView?.state = .installed
            stateBadgeView?.isHidden = !isInstalled
        }
    }
}
