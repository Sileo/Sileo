//
//  DepictionSubheaderView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DepictionSubheaderView: DepictionBaseView {
    var headerLabel: UILabel?
    let useMargins: Bool
    let useBottomMargin: Bool

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let title = dictionary["title"] as? String else {
            return nil
        }
        useMargins = (dictionary["useMargins"] as? Bool) ?? true
        useBottomMargin = (dictionary["useBottomMargin"] as? Bool) ?? true

        headerLabel = UILabel(frame: .zero)
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        let useBoldText = (dictionary["useBoldText"] as? Bool) ?? false
        if useBoldText {
            headerLabel?.textColor = .sileoLabel
            headerLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            
            weak var weakSelf = self
            NotificationCenter.default.addObserver(weakSelf as Any,
                                                   selector: #selector(updateSileoColors),
                                                   name: SileoThemeManager.sileoChangedThemeNotification,
                                                   object: nil)
        } else {
            headerLabel?.textColor = UIColor(white: 175.0/255.0, alpha: 1)
            headerLabel?.font = UIFont.systemFont(ofSize: 14)
        }
        headerLabel?.text = title

        let alignment = (dictionary["alignment"] as? Int) ?? 0
        switch alignment {
        case 1: do {
            headerLabel?.textAlignment = .center
            break
            }
        case 2: do {
            headerLabel?.textAlignment = .right
            break
            }
        default: do {
            headerLabel?.textAlignment = .left
            break
            }
        }

        addSubview(headerLabel!)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func updateSileoColors() {
        headerLabel?.textColor = .sileoLabel
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        guard useMargins else {
            return 20
        }
        guard useBottomMargin else {
            return 40
        }
        return 60
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if useMargins {
            headerLabel?.frame = CGRect(x: 16, y: 20, width: self.bounds.width - 32, height: 20)
        } else {
            headerLabel?.frame = CGRect(origin: .zero, size: CGSize(width: self.bounds.width, height: 20))
        }
    }
}
