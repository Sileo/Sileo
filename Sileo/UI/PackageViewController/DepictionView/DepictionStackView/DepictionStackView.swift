//
//  DepictionStackView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

// Make sure to also update FeaturedStackView.swift

import Foundation

class DepictionStackView: DepictionBaseView {
    private var views: [DepictionBaseView] = []
    private var isLandscape: Bool = false
    
    private var xPadding = CGFloat(0)
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let views = dictionary["views"] as? [[String: Any]] else {
            return nil
        }
        if let orientationString = dictionary["orientation"] as? String {
            guard orientationString == "landscape" || orientationString == "portrait" else {
                return nil
            }
            if orientationString == "landscape" {
                isLandscape = true
            }
        }
        
        for viewDict in views {
            guard (viewDict["class"] as? String) != nil else {
                return nil
            }
        }
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        for viewDict in views {
            if let depictView = DepictionBaseView.view(dictionary: viewDict,
                                                       viewController: viewController,
                                                       tintColor: tintColor,
                                                       isActionable: isActionable) {
                self.views.append(depictView)
                addSubview(depictView)
            }
        }
        
        if let backgroundColor = dictionary["backgroundColor"] as? String {
            self.backgroundColor = UIColor(css: backgroundColor)
        }
        if let xPadding = dictionary["xPadding"] as? CGFloat {
            self.xPadding = xPadding
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func subviewHeightChanged() {
        self.layoutSubviews()
        super.subviewHeightChanged()
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        var height = CGFloat(0)

        var width = width
        width -= (2 * xPadding)
        if isLandscape {
            let viewWidth = width/CGFloat(views.count)
            for view in views {
                let newHeight = view.depictionHeight(width: viewWidth)
                if newHeight > height {
                    height = newHeight
                }
            }
        } else {
            for view in views {
                height += view.depictionHeight(width: width)
            }
        }
        return height
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = self.bounds.width - (2 * xPadding)
        if isLandscape {
            let itemWidth = width/CGFloat(views.count)

            var x = xPadding
            for view in views {
                view.frame = CGRect(x: x, y: 0, width: itemWidth, height: view.depictionHeight(width: itemWidth))
                view.layoutSubviews()
                x += itemWidth
            }
        } else {
            var y = CGFloat(0)
            for view in views {
                view.frame = CGRect(x: xPadding, y: y, width: width, height: view.depictionHeight(width: width))
                view.layoutSubviews()
                y += view.frame.height
            }
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isActionable {
                for view in views {
                    view.isHighlighted = self.isHighlighted
                }
            }
        }
    }
}
