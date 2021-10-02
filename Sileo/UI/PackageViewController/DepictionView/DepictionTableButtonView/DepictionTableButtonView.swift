//
//  DepictionTableButtonView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class DepictionTableButtonView: DepictionBaseView, UIGestureRecognizerDelegate {
    private var selectionView: UIView
    private var titleLabel: UILabel
    private var chevronView: UIImageView
    private var repoIcon: UIImageView?

    private var action: String
    private var backupAction: String

    private let openExternal: Bool

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let title = dictionary["title"] as? String else {
            return nil
        }

        guard let action = dictionary["action"] as? String else {
            return nil
        }

        selectionView = UIView(frame: .zero)
        titleLabel = UILabel(frame: .zero)
        chevronView = UIImageView(image: UIImage(named: "Chevron")?.withRenderingMode(.alwaysTemplate))

        self.action = action
        backupAction = (dictionary["backupAction"] as? String) ?? ""

        openExternal = (dictionary["openExternal"] as? Bool) ?? false

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
        
        if let repo = dictionary["_repo"] as? String {
            repoIcon = UIImageView(frame: .zero)
            repoIcon?.layer.masksToBounds = true
            repoIcon?.layer.cornerRadius = 7.5
            loadRepoImage(repo)
            self.addSubview(repoIcon!)
        }
        
        titleLabel.text = title
        titleLabel.textAlignment = .left
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        self.addSubview(titleLabel)

        self.addSubview(chevronView)
        
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(DepictionTableButtonView.buttonTapped))
        tapGestureRecognizer.minimumPressDuration = 0.05
        tapGestureRecognizer.delegate = self
        self.addGestureRecognizer(tapGestureRecognizer)

        self.accessibilityTraits = .link
        self.isAccessibilityElement = true
        self.accessibilityLabel = titleLabel.text
    }
    
    private func loadRepoImage(_ repo: String) {
        guard let url = URL(string: repo) else { return }
        if url.host == "apt.thebigboss.org" {
            self.repoIcon?.image = UIImage(named: "BigBoss")
            return
        }
        let scale = Int(UIScreen.main.scale)
        for i in (1...scale).reversed() {
            let filename = i == 1 ? CommandPath.RepoIcon : "\(CommandPath.RepoIcon)@\(i)x"
            if let iconURL = URL(string: repo)?
                .appendingPathComponent(filename)
                .appendingPathExtension("png") {
                let cache = EvanderNetworking.shared.imageCache(iconURL, scale: CGFloat(i))
                if let image = cache.1 {
                    repoIcon?.image = image
                    return
                }
            }
        }
        repoIcon?.image = UIImage(named: "Repo Icon")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        44
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        titleLabel.textColor = self.tintColor
        chevronView.tintColor = self.tintColor

        var containerFrame = self.bounds
        containerFrame.origin.x = 16
        containerFrame.size.width -= 32

        selectionView.frame = self.bounds
        if let repoIcon = repoIcon {
            repoIcon.frame = CGRect(x: containerFrame.minX, y: 4.5, width: 35, height: 35)
            titleLabel.frame = CGRect(x: containerFrame.minX + 40, y: 12, width: containerFrame.width - 60, height: 20.0)
        } else {
            titleLabel.frame = CGRect(x: containerFrame.minX, y: 12, width: containerFrame.width - 20, height: 20.0)
        }
        chevronView.frame = CGRect(x: containerFrame.maxX - 9, y: 15, width: 7, height: 13)
    }

    override func accessibilityActivate() -> Bool {
        self.buttonTapped(nil)
        return true
    }

    @objc func buttonTapped(_ gestureRecognizer: UIGestureRecognizer?) {
        if let gestureRecognizer = gestureRecognizer {
            if gestureRecognizer.state == .began {
                selectionView.alpha = 1
            } else if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled || gestureRecognizer.state == .failed {
                selectionView.alpha = 0
            }

            if gestureRecognizer.state != .ended {
                return
            }
        }

        if !self.processAction(action) {
            self.processAction(backupAction)
        }
    }

    @discardableResult func processAction(_ action: String) -> Bool {
        if action.isEmpty {
            return false
        }
        return DepictionButton.processAction(action, parentViewController: self.parentViewController, openExternal: openExternal)
    }
}
