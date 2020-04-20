//
//  FeaturedButtonView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

@objc(FeaturedButtonView)
class FeaturedButtonView: DepictionBaseView {
    private var button: UIButton
    
    private var action: String
    private var backupAction: String
    
    private var yPadding: CGFloat
    
    private let openExternal: Bool
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor) {
        guard let text = dictionary["text"] as? String else {
            return nil
        }
        guard let action = dictionary["action"] as? String else {
            return nil
        }
        
        yPadding = (dictionary["yPadding"] as? CGFloat) ?? 0
        
        button = FeaturedButton(type: .custom)
        
        self.action = action
        backupAction = (dictionary["backupAction"] as? String) ?? ""
        
        openExternal = (dictionary["openExternal"] as? Bool) ?? false
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor)
        
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(FeaturedButtonView.buttonTapped), for: .touchUpInside)
        self.addSubview(button)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        56 + (yPadding * 2)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        button.isHighlighted = button.isHighlighted
        button.frame = self.bounds.insetBy(dx: 8, dy: 8)
    }
    
    @objc func buttonTapped(_ : Any?) {
        if !self.processAction(action) {
            self.processAction(backupAction)
        }
    }
    
    @discardableResult func processAction(_ action: String) -> Bool {
        if action.isEmpty {
            return false
        }
        return FeaturedButton.processAction(action, parentViewController: self.parentViewController, openExternal: openExternal)
    }
}
