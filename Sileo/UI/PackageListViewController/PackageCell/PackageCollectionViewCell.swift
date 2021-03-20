//
//  PackageCollectionViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class PackageCollectionViewCell: UICollectionViewCell {
    
    public var packageView: PackageCellView = .fromNib()
    
    public var targetPackage: Package? {
        didSet {
            if let targetPackage = targetPackage {
                self.packageView.targetPackage = targetPackage
            }
            self.refreshState()
        }
    }
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    let visibleContainerView = UIView()
    let hiddenContainerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.selectedBackgroundView = UIView()
        self.selectedBackgroundView?.backgroundColor = UIColor.lightGray.withAlphaComponent(0.25)
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.addArrangedSubview(packageView)

        addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        scrollView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: 1).isActive = true
            
        NotificationCenter.default.addObserver([self],
                                               selector: #selector(PackageCollectionViewCell.refreshState),
                                               name: DownloadManager.reloadNotification, object: nil)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    @objc func updateSileoColors() {
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    func setTargetPackage(_ package: Package, isUnread: Bool) {
        self.packageView.targetPackage = package
        self.packageView.unreadView?.isHidden = !isUnread
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()

    }
    
    @objc func refreshState() {
        guard let targetPackage = targetPackage else {
            return
        }
        let queueState = DownloadManager.shared.find(package: targetPackage)
        let isInstalled = PackageListManager.shared.installedPackage(identifier: targetPackage.package) != nil
        self.packageView.refreshState(queueState: queueState, isInstalled: isInstalled)
    }
}
