//
//  SettingsHeaderContainerView.swift
//  Sileo
//
//  Created by Skitty on 1/27/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SettingsHeaderContainerView: UIView {
    private var storedHeaderView: (UIView & SettingsHeaderViewDisplayable)?
    
    var headerView: (UIView & SettingsHeaderViewDisplayable)? {
        get {
            storedHeaderView
        }
        set {
            if storedHeaderView != nil {
                storedHeaderView?.removeFromSuperview()
            }
            
            storedHeaderView = newValue
            
            if newValue == nil {
                return
            }
            
            storedHeaderView?.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(storedHeaderView ?? UIView())
            
            contentBottomConstraint = storedHeaderView?.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            contentBottomConstraint?.isActive = true
            storedHeaderView?.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
            storedHeaderView?.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
            contentHeightConstraint = storedHeaderView?.heightAnchor.constraint(equalToConstant: 0)
            
            self.adjustHeaderViewHeight()
            contentHeightConstraint?.isActive = true
        }
    }
    
    var elasticHeight: CGFloat? {
        didSet {
            if contentBottomConstraint != nil {
                contentBottomConstraint?.constant = -(elasticHeight ?? 0) / 2
            }
        }
    }
    
    private var hairlineHeightConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    
    private var colorInfluenceView: UIView?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = true
        
        let blurEffect: UIBlurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurView: UIVisualEffectView = UIVisualEffectView(effect: blurEffect)
        blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        blurView.frame = self.bounds
        self.addSubview(blurView)
        
        let colourInfluenceView: UIView = UIView()
        colourInfluenceView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        colourInfluenceView.frame = self.bounds
        colourInfluenceView.backgroundColor = UIColor.sileoHeaderColor
        self.addSubview(colourInfluenceView)
        
        self.colorInfluenceView = colourInfluenceView
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        let separatorView: UIView = UIView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = UIColor(white: 0, alpha: 0.07)
        self.addSubview(separatorView)
        
        separatorView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        separatorView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.hairlineHeightConstraint = separatorView.heightAnchor.constraint(equalToConstant: 1)
        self.hairlineHeightConstraint?.isActive = true
    }
    
    @objc func updateSileoColors() {
        self.colorInfluenceView?.backgroundColor = UIColor.sileoHeaderColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13.0, *) {
            self.colorInfluenceView?.backgroundColor = UIColor.sileoHeaderColor
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if hairlineHeightConstraint == nil {
            return
        }
        hairlineHeightConstraint?.constant = 1 / (self.window?.screen.scale ?? 1 as CGFloat)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.adjustHeaderViewHeight()
    }

    func contentHeight(forWidth width: CGFloat) -> CGFloat {
        headerView?.headerHeight(forWidth: width) ?? 0
    }

    func adjustHeaderViewHeight() {
        if contentHeightConstraint == nil || headerView == nil {
            return
        }
        contentHeightConstraint?.constant = headerView?.headerHeight(forWidth: self.bounds.size.width) ?? 0
    }
}
