//
//  PackageCollectionViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import SwipeCellKit

class PackageCollectionViewCell: SwipeCollectionViewCell {
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
        self.delegate = self
        
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

extension PackageCollectionViewCell: SwipeCollectionViewCellDelegate {
    func collectionView(_ collectionView: UICollectionView, editActionsForItemAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
        // We don't want any left actions so return if that's where we are headed
        // Also making sure that the set package actually exists
        guard orientation == .right,
              let package = targetPackage,
              UserDefaults.standard.optionalBool("SwipeActions", fallback: true)  else { return nil }
        
        var actions = [SwipeAction]()
        let queueFound = DownloadManager.shared.find(package: package)
        print(queueFound)
        if queueFound != .none {
            actions.append(cancelAction(package))
        }
        
        // Check if the package is actually installed
        if let installedPackage = PackageListManager.shared.installedPackage(identifier: package.package) {
            // Add our uninstall action now
            if queueFound != .uninstallations {
                actions.append(uninstallAction(package))
            }
            let repo = RepoManager.shared.repoList.first(where: { $0.rawEntry == package.sourceFile })
            // Check we have a repo for the package
            if package.filename != nil && repo != nil {
                // Check if can be updated
                if DpkgWrapper.isVersion(package.version, greaterThan: installedPackage.version) {
                    if queueFound != .upgrades {
                        actions.append(upgradeAction(package))
                    }
                } else {
                    // Only add re-install if it can't be updated
                    if queueFound != .installations {
                        actions.append(reinstallAction(package))
                    }
                }
            }
        } else {
            if queueFound != .installations {
                // Cringe, package isn't installed
                if package.commercial {
                    actions.append(purchaseAction(package))
                } else {
                    // The package is free, add to queue
                    actions.append(installAction(package))
                }
            }
        }
        return actions
    }
    
    private func cancelAction(_ package: Package) -> SwipeAction {
        let cancel = SwipeAction(style: .destructive, title: String(localizationKey: "Cancel")) { _, _ in
            DownloadManager.shared.remove(package: package.package)
            DownloadManager.shared.reloadData(recheckPackages: true)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.hideSwipe(animated: true)
        }
        return cancel
    }
    
    private func uninstallAction(_ package: Package) -> SwipeAction {
        let uninstall = SwipeAction(style: .destructive, title: String(localizationKey: "Package_Uninstall_Action")) { _, _ in
            DownloadManager.shared.add(package: package, queue: .uninstallations)
            DownloadManager.shared.reloadData(recheckPackages: true)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.hideSwipe(animated: true)
        }
        return uninstall
    }
    
    private func upgradeAction(_ package: Package) -> SwipeAction {
        let update = SwipeAction(style: .default, title: String(localizationKey: "Package_Upgrade_Action")) { _, _ in
            DownloadManager.shared.add(package: package, queue: .upgrades)
            DownloadManager.shared.reloadData(recheckPackages: true)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.hideSwipe(animated: true)
        }
        update.backgroundColor = .systemBlue
        return update
    }
    
    private func reinstallAction(_ package: Package) -> SwipeAction {
        let reinstall = SwipeAction(style: .default, title: String(localizationKey: "Package_Reinstall_Action")) { _, _ in
            DownloadManager.shared.add(package: package, queue: .installations)
            DownloadManager.shared.reloadData(recheckPackages: true)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.hideSwipe(animated: true)
        }
        reinstall.backgroundColor = .systemOrange
        return reinstall
    }
    
    private func purchaseAction(_ package: Package) -> SwipeAction {
        // It's a paid package, that's an L. Omg this is gonna be so much pain
        let purchase = SwipeAction(style: .default, title: "Buy") { _, _ in
            // I'm doing this later cba right now
            self.hideSwipe(animated: true)
        }
        purchase.backgroundColor = .systemGreen
        return purchase
    }
    
    private func installAction(_ package: Package) -> SwipeAction {
        let install = SwipeAction(style: .default, title: String(localizationKey: "Package_Get_Action")) { _, _ in
            if package.sourceRepo != nil && !package.package.contains("/") {
                DownloadManager.shared.add(package: package, queue: .installations)
                DownloadManager.shared.reloadData(recheckPackages: true)
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.hideSwipe(animated: true)
        }
        install.backgroundColor = .systemGreen
        return install
    }
}
