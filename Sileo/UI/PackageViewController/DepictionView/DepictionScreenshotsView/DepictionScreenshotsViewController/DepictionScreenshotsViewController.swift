//
//  DepictionScreenshotsViewController.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DepictionScreenshotsViewController: UIViewController, DepictionViewDelegate {
    public var depiction: [String: Any] = [:]
    public var tintColor: UIColor?

    private var screenshotsView: DepictionScreenshotsView?

    override func loadView() {
        self.view = SileoRootView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Done"),
                                                                 style: .done,
                                                                 target: self,
                                                                 action: #selector(DepictionScreenshotsViewController.dismiss(_:)))
        self.navigationController?.navigationBar.tintColor = self.tintColor
        self.navigationController?.navigationBar.superview?.tag = WHITE_BLUR_TAG
        self.navigationController?.navigationBar._hidesShadow = true

        screenshotsView = DepictionScreenshotsView(dictionary: depiction,
                                                   viewController: self,
                                                   tintColor: tintColor ?? self.view.tintColor,
                                                   isPaging: true, isActionable: false)
        screenshotsView?.delegate = self
        self.view.addSubview(screenshotsView!)
        
        if #available(iOS 13, *) {
            self.view.backgroundColor = .sileoBackgroundColor
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            self.view.backgroundColor = .sileoBackgroundColor
        }
    }

    func subviewHeightChanged() {
        self.viewDidLayoutSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let insets = self.view.safeAreaInsets
        let width = self.view.bounds.width - (insets.left + insets.right)
        let height = screenshotsView?.depictionHeight(width: width)
        screenshotsView?.frame = CGRect(x: insets.left, y: insets.top, width: width, height: height ?? 0)
    }

    @objc func dismiss(_ : Any) {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let previousIndex = screenshotsView?.currentPageIndex() ?? 0
        coordinator.animate(alongsideTransition: { _ in
            self.screenshotsView?.scrollToPageIndex(previousIndex, animated: false)
        }, completion: nil)
    }
}
