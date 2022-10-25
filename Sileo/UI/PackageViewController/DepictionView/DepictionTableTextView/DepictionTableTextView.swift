//
//  DepictionTableTextView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DepictionTableTextView: DepictionBaseView {
    private var titleLabel, textLabel: UILabel

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let title = dictionary["title"] as? String else {
            return nil
        }
        guard let text = dictionary["text"] as? String else {
            return nil
        }
        titleLabel = UILabel(frame: .zero)
        textLabel = UILabel(frame: .zero)

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        titleLabel.text = title
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = UIColor(white: 175.0/255.0, alpha: 1)
        self.addSubview(titleLabel)

        textLabel.text = text
        textLabel.textAlignment = .right
        textLabel.font = UIFont.systemFont(ofSize: 17)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        textLabel.textColor = .sileoLabel
        
        self.addSubview(textLabel)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func updateSileoColors() {
        textLabel.textColor = .sileoLabel
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        44
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var containerFrame = self.bounds
        containerFrame.origin.x = 16
        containerFrame.size.width -= 32

        titleLabel.frame = CGRect(x: containerFrame.minX, y: 12, width: containerFrame.width/2.0, height: 20.0)
        textLabel.frame = CGRect(x: containerFrame.minX + (containerFrame.width / 2.0), y: 12, width: containerFrame.width/2, height: 20)
    }
}
