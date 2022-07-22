//
//  FeaturedAutoStackView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//
// Based on DepictionStackView
// Make sure to also update DepictionAutoStackView.swift

import Foundation

class FeaturedAutoStackView: FeaturedBaseView {
    private var views: [DepictionBaseView] = []
    private var viewWidths: [CGFloat] = []
    private var horizontalSpacing = CGFloat(0)
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let views = dictionary["views"] as? [[String: Any]] else {
            return nil
        }
        guard let horizontalSpacing = dictionary["horizontalSpacing"] as? CGFloat else {
            return nil
        }
        self.horizontalSpacing = horizontalSpacing
        
        for dict in views {
            guard (dict["class"] as? String) != nil else {
                return nil
            }
            guard (dict["preferredWidth"] as? CGFloat) != nil else {
                return nil
            }
        }
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        for dict in views {
            guard let preferredWidth = dict["preferredWidth"] as? CGFloat else {
                continue
            }
            if let view = FeaturedBaseView.view(dictionary: dict, viewController: viewController, tintColor: tintColor, isActionable: isActionable) {
                self.views.append(view)
                self.viewWidths.append(preferredWidth)
                addSubview(view)
            }
        }
        
        if let backgroundColor = dictionary["backgroundColor"] as? String {
            self.backgroundColor = UIColor(css: backgroundColor)
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
        
        var idx = 0
        
        var currentRowHeight = CGFloat(0)
        var currentRowWidth = CGFloat(0)
        var currentRowX = CGFloat(0)
        
        for view in views {
            var viewWidth = viewWidths[idx]
            if viewWidth > width {
                viewWidth = width
            }
            
            var effectiveWidth = viewWidth
            if currentRowX > 0 {
                effectiveWidth += horizontalSpacing
            }
            
            let newHeight = view.depictionHeight(width: viewWidth)
            if currentRowWidth + effectiveWidth <= width {
                if newHeight > currentRowHeight {
                    currentRowHeight = newHeight
                }
                currentRowWidth += viewWidth
                currentRowX += effectiveWidth
            } else {
                height += currentRowHeight
                currentRowHeight = newHeight
                currentRowWidth = viewWidth
                currentRowX = viewWidth
            }
            
            idx += 1
        }
        
        height += currentRowHeight
        
        return height
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var height = CGFloat(0)
        var rowWidths: [CGFloat] = []
        
        var currentRowWidth = CGFloat(0)
        for rawWidth in viewWidths {
            var viewWidth = rawWidth
            if viewWidth > self.bounds.width {
                viewWidth = self.bounds.width
            }
            
            var effectiveWidth = viewWidth
            if currentRowWidth > 0 {
                effectiveWidth += horizontalSpacing
            }
            
            if currentRowWidth + effectiveWidth <= self.bounds.width {
                currentRowWidth += effectiveWidth
            } else {
                rowWidths.append(currentRowWidth)
                currentRowWidth = viewWidth
            }
        }
        rowWidths.append(currentRowWidth)
        
        var idx = 0
        var currentRowIdx = 0
        var currentRowHeight = CGFloat(0)
        var currentRowX = CGFloat(0)
        currentRowWidth = rowWidths[currentRowIdx]
        
        for view in views {
            var viewWidth = viewWidths[idx]
            if viewWidth > self.bounds.width {
                viewWidth = self.bounds.width
            }
            
            let newHeight = view.depictionHeight(width: viewWidth)
            var effectiveWidth = viewWidth
            if currentRowX > 0 {
                effectiveWidth += horizontalSpacing
            }
            
            if currentRowX + effectiveWidth <= self.bounds.width {
                if newHeight > currentRowHeight {
                    currentRowHeight = newHeight
                }
                currentRowX += effectiveWidth
            } else {
                height += currentRowHeight
                currentRowIdx += 1
                currentRowHeight = newHeight
                currentRowX = viewWidth
                if currentRowIdx < rowWidths.count {
                    currentRowWidth = rowWidths[currentRowIdx]
                } else {
                    currentRowWidth = 0
                }
            }
            
            let xOffset = (self.bounds.width - currentRowWidth)/2.0
            view.frame = CGRect(x: xOffset + currentRowX - viewWidth, y: height, width: viewWidth, height: newHeight)
            
            idx += 1
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
