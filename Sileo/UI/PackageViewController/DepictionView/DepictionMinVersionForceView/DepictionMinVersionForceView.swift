//
//  DepictionMinVersionForceView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DepictionMinVersionForceView: DepictionBaseView {
    var containedView: DepictionBaseView?

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let view = dictionary["view"] as? [String: Any] else {
            return nil
        }
        guard let minVersion = dictionary["minVersion"] as? String else {
            return nil
        }
        if minVersion.compare(StoreVersion) == .orderedDescending {
            return nil
        }

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        if let baseView = DepictionBaseView.view(dictionary: view, viewController: viewController, tintColor: tintColor, isActionable: isActionable) {
            self.containedView = baseView
            self.addSubview(baseView)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        guard let containedView = containedView else {
            return 0
        }
        return containedView.depictionHeight(width: width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        containedView?.frame = self.bounds
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isActionable {
                containedView?.isHighlighted = self.isHighlighted
            }
        }
    }
}
