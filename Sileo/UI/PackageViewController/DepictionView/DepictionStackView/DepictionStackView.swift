//
//  DepictionStackView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//
// Make sure to also update FeaturedStackView.swift

import Foundation

@objc(DepictionStackView)
class DepictionStackView: DepictionBaseView {
    private var views: [DepictionBaseView] = []
    private var isLandscape: Bool = false

    private var xPadding = CGFloat(0)

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor) {
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
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor)
        for viewDict in views {
            if let view = DepictionBaseView.view(dictionary: viewDict, viewController: viewController, tintColor: tintColor) {
                self.views.append(view)
                addSubview(view)
            }
        }

        if let backgroundColor = dictionary["backgroundColor"] as? String {
            /*UIColor *color = [UIColor colorWithCSS:depiction[@"backgroundColor"]];
             CGFloat red, green, blue, alpha;
             [color getRed:&red green:&green blue:&blue alpha:&alpha];
             if (alpha > 0.2)
             alpha = 0.2;
             self.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];*/
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
}
