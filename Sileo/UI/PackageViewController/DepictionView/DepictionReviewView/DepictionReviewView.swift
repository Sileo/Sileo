//
//  DepictionReviewView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DepictionReviewView: DepictionBaseView {
    private var backgroundView: UIView?
    private var containedReviewView: DepictionBaseView?
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let title = dictionary["title"] as? String else {
            return nil
        }
        guard let author = dictionary["author"] as? String else {
            return nil
        }
        guard let markdown = dictionary["markdown"] as? String else {
            return nil
        }
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        let rating: Any = (dictionary["rating"] as? CGFloat) ?? ""
        
        let subDepiction: [String: Any] = [
            "class": "DepictionStackView",
            "views": [
                [
                    "class": "DepictionStackView",
                    "orientation": "landscape",
                    "views": [
                        [
                            "class": "DepictionStackView",
                            "views": [
                                [
                                    "class": "DepictionSubheaderView",
                                    "useMargins": false,
                                    "useBoldText": true,
                                    "title": title
                                ], [
                                    "class": "DepictionSubheaderView",
                                    "useMargins": false,
                                    "useBoldText": false,
                                    "title": String(format: String(localizationKey: "By_Author"), author)
                                ]
                            ]
                        ], [
                            "class": "DepictionRatingView",
                            "alignment": 2,
                            "rating": rating
                        ]
                    ]
                ],
                [
                    "class": "DepictionSpacerView",
                    "spacing": 8
                ],
                [
                    "class": "DepictionMarkdownView",
                    "useSpacing": false,
                    "useMargins": false,
                    "markdown": markdown
                ]
            ]
        ]
        
        backgroundView = UIView(frame: .zero)
        backgroundView?.backgroundColor = .sileoContentBackgroundColor
        backgroundView?.layer.cornerRadius = 10
        self.addSubview(backgroundView!)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(SileoContentView.updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        let color = self.tintColor
        let view = DepictionBaseView.view(dictionary: subDepiction, viewController: viewController, tintColor: color, isActionable: isActionable)
        self.containedReviewView = view
        self.addSubview(view!)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        guard let containedReviewView = containedReviewView else {
            return 0
        }
        return containedReviewView.depictionHeight(width: width - 40.0) + 40.0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView?.frame = self.bounds.insetBy(dx: 8, dy: 8)
        containedReviewView?.frame = self.bounds.insetBy(dx: 20, dy: 16)
    }
    
    @objc func updateSileoColors() {
        backgroundView?.backgroundColor = .sileoContentBackgroundColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            backgroundView?.backgroundColor = .sileoContentBackgroundColor
        }
    }
}
