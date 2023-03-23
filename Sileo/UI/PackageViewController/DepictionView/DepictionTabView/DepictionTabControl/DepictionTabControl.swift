//
//  DepictionTabControl.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

protocol DepictionTabControlContainer {
    func tabTapped(_ : DepictionTabControl)
}

class DepictionTabControl: UIView {
    private var tabLabel: UILabel
    private let text: String

    required init(text: String) {
        tabLabel = UILabel(frame: .zero)
        self.text = text

        super.init(frame: .zero)
        tabLabel.textAlignment = .center
        tabLabel.text = text
        tabLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        addSubview(tabLabel)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(DepictionTabControl.viewTapped))
        tapGestureRecognizer.numberOfTouchesRequired = 1
        tapGestureRecognizer.numberOfTapsRequired = 1
        self.addGestureRecognizer(tapGestureRecognizer)

        self.accessibilityTraits = .button
        self.isAccessibilityElement = true
        self.accessibilityLabel = text
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func textWidth() -> CGFloat {
        text.size(withAttributes: [.font: tabLabel.font as Any]).width
    }

    @objc public func viewTapped(_ : Any) {
        if let tabView = self.superview?.superview as? DepictionTabControlContainer {
            tabView.tabTapped(self)
        }
    }

    public var highlighted: Bool = false {
        didSet {
            if highlighted {
                tabLabel.textColor = self.tintColor
            } else {
                tabLabel.textColor = UIColor(red: 143.0/255.0, green: 142.0/255.0, blue: 128.0/255.0, alpha: 1.0)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tabLabel.frame = CGRect(x: 0, y: (self.bounds.height-20)/2.0, width: self.bounds.width, height: 20.0)
    }
}
