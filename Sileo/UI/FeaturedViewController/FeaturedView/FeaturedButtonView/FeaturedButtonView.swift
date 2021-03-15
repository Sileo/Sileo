//
//  FeaturedButtonView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class FeaturedButtonView: FeaturedBaseView {
    private var button: FeaturedButton
    private var subView: DepictionBaseView?
    
    private var action: String
    private var backupAction: String
    
    private var yPadding: CGFloat
    
    private let openExternal: Bool
    private let isLink: Bool
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let action = dictionary["action"] as? String else {
            return nil
        }
        
        yPadding = (dictionary["yPadding"] as? CGFloat) ?? 0
        
        button = FeaturedButton(type: .custom)
        
        self.action = action
        backupAction = (dictionary["backupAction"] as? String) ?? ""
        
        openExternal = (dictionary["openExternal"] as? Bool) ?? false
        
        isLink = (dictionary["isLink"] as? Bool) ?? false
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        if let rawView = dictionary["view"] as? [String: Any],
            let view = FeaturedBaseView.view(dictionary: rawView, viewController: viewController, tintColor: isLink ? tintColor : .white, isActionable: true) {
            view.isUserInteractionEnabled = false
            button.addSubview(view)
            self.subView = view
        } else if let text = dictionary["text"] as? String {
            button.setTitle(text, for: .normal)
        }
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        if !isLink {
            button.layer.cornerRadius = 10
        }
        button.addTarget(self, action: #selector(FeaturedButtonView.buttonTapped), for: .touchUpInside)
        
        button.isLink = isLink
        self.addSubview(button)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        let rawHeight = self.subView?.depictionHeight(width: width) ?? (isLink ? 30 : 40)
        return rawHeight + (isLink ? 0 : 16) + (yPadding * 2)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        button.isHighlighted = button.isHighlighted
        if isLink {
            button.frame = self.bounds
        } else {
            button.frame = self.bounds.insetBy(dx: 8, dy: 8)
        }
        self.subView?.frame = button.bounds
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
