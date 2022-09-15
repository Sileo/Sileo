//
//  PackageButton.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class PackageButton: UIButton {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    internal func setup() {
        self.isProminent = true
        self.customAlpha = 1.0
        self.isHighlighted = false
        self.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        self.adjustsImageWhenHighlighted = false
        self.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        self.widthAnchor.constraint(greaterThanOrEqualToConstant: 70).isActive = true
        tintColor = UINavigationBar.appearance().tintColor
        self.updateStyle()
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = min(self.bounds.width, self.bounds.height)/2
    }
    
    override var isHighlighted: Bool {
        didSet {
            self.updateStyle()
        }
    }
    
    public var isProminent: Bool = false {
        didSet {
            FRUIView.animate(withDuration: self.window != nil ? 0.3 : 0) {
                self.updateStyle()
            }
        }
    }
    
    private var _tintColor: UIColor = .tintColor
    
    override var tintColor: UIColor! {
        didSet {
            _tintColor = tintColor
        }
    }
    
    @objc func updateSileoColors() {
        self.tintColor = .tintColor
        self.backgroundColor = .tintColor
    }
    
    public func updateStyle() {
        var tintColor = _tintColor
        if self.isHighlighted {
            var tintHue: CGFloat = 0
            var tintSat: CGFloat = 0
            var tintBrightness: CGFloat = 0
            tintColor.getHue(&tintHue, saturation: &tintSat, brightness: &tintBrightness, alpha: nil)
            
            tintBrightness *= 0.75
            tintColor = UIColor(hue: tintHue, saturation: tintSat, brightness: tintBrightness, alpha: 1)
        }
        self.backgroundColor = tintColor
        self.setTitleColor(.white, for: .normal)
    }
    
    override var isEnabled: Bool {
        didSet {
            self.alpha = isEnabled ? customAlpha * 1.0 : customAlpha * 0.45
        }
    }
    
    public var customAlpha: CGFloat = 1 {
        didSet {
            self.alpha = isEnabled ? customAlpha * 1.0 : customAlpha * 0.45
        }
    }
    
    override func setTitle(_ title: String?, for state: UIControl.State) {
        if title == self.title(for: state) || self.window == nil {
            return super.setTitle(title, for: state)
        } else {
            FRUIView.animateKeyframes(withDuration: 0.25, delay: 0, options: .calculationModeCubicPaced, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                    self.titleLabel?.alpha = 0
                }
                UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.6) {
                    super.setTitle(title, for: state)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                    self.titleLabel?.isHidden = false
                    self.titleLabel?.alpha = 1
                }
            }, completion: ((Bool) -> Void)? {_ in
                    self.layoutIfNeeded()
            })
        }
    }
}
