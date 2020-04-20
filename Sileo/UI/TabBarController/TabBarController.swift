//
//  TabBarController.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation
import LNPopupController

class TabBarController: UITabBarController {
    static var singleton: TabBarController?
    private var downloadsController: UINavigationController?
    private var popupIsPresented = false
    private var popupLock = DispatchSemaphore(value: 1)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        TabBarController.singleton = self
        
        downloadsController = UINavigationController(rootViewController: DownloadManager.shared.viewController)
        downloadsController?.isNavigationBarHidden = true
        downloadsController?.popupItem.title = ""
        downloadsController?.popupItem.subtitle = ""
        
        if UIColor.useSileoColors {
            NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.updateSileoColors), name: UIColor.sileoDarkModeNotification, object: nil)
            self.updateSileoColors()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updatePopup()
    }
    
    func presentPopup() {
        guard let downloadsController = downloadsController else {
            return
        }
        if popupIsPresented {
            return
        }
        popupLock.wait()
        defer { popupLock.signal() }
        if popupIsPresented {
            return
        }
        popupIsPresented = true
        self.popupContentView.popupCloseButtonAutomaticallyUnobstructsTopBars = false
        self.popupBar.toolbar.tag = WHITE_BLUR_TAG
        self.popupBar.barStyle = .prominent
        
        self.updateSileoColors()
        
        self.popupBar.toolbar.setBackgroundImage(nil, forToolbarPosition: .any, barMetrics: .default)
        self.popupBar.isInlineWithTabBar = UIDevice.current.userInterfaceIdiom == .pad
        self.popupBar.tabBarHeight = self.tabBar.frame.height
        self.popupBar.progressViewStyle = .bottom
        self.popupInteractionStyle = .drag
        self.presentPopupBar(withContentViewController: downloadsController, animated: true, completion: nil)
        
        if UIColor.useSileoColors {
            self.updateSileoColors()
        } else {
            self.traitCollectionDidChange(nil)
        }
    }
    
    func dismissPopup() {
        guard popupIsPresented else {
            return
        }
        popupLock.wait()
        defer { popupLock.signal() }
        guard popupIsPresented else {
            return
        }
        popupIsPresented = false
        self.dismissPopupBar(animated: true, completion: nil)
    }
    
    func presentPopupController() {
        guard popupIsPresented else {
            return
        }
        popupLock.wait()
        defer { popupLock.signal() }
        self.openPopup(animated: true, completion: nil)
    }
    
    func dismissPopupController() {
        guard popupIsPresented else {
            return
        }
        popupLock.wait()
        defer { popupLock.signal() }
        self.closePopup(animated: true, completion: nil)
    }
    
    func updatePopup() {
        let manager = DownloadManager.shared
        if manager.lockedForInstallation {
            downloadsController?.popupItem.title = String(localizationKey: "Installing_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.readyPackages())
            downloadsController?.popupItem.progress = Float(manager.totalProgress)
            self.presentPopup()
        } else if manager.downloadingPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Downloading_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.downloadingPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup()
        } else if manager.queuedPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Queued_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.queuedPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup()
        } else if manager.readyPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Ready_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.readyPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup()
        } else if manager.uninstallingPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Removal_Queued_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.uninstallingPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup()
        } else {
            if UIDevice.current.userInterfaceIdiom == .pad && self.view.frame.width >= 768 {
                downloadsController?.popupItem.title = String(localizationKey: "Queued_Package_Status")
                downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), 0)
                self.presentPopup()
            } else {
                self.dismissPopup()
            }
        }
    }
    
    override var bottomDockingViewForPopupBar: UIView? {
        self.tabBar
    }
    
    override var defaultFrameForBottomDockingView: CGRect {
        var tabBarFrame = self.tabBar.frame
        tabBarFrame.origin.y = self.view.bounds.height - tabBarFrame.height
        if UIDevice.current.userInterfaceIdiom == .pad {
            tabBarFrame.origin.x = 0
            tabBarFrame.size.width = self.view.bounds.width
            if tabBarFrame.width >= 768 {
                tabBarFrame.size.width -= 320
            }
        }
        return tabBarFrame
    }
    
    override var insetsForBottomDockingView: UIEdgeInsets {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if self.view.bounds.width < 768 {
                return .zero
            }
            return UIEdgeInsets(top: self.tabBar.frame.height, left: self.view.bounds.width - 320, bottom: 0, right: 0)
        }
        return .zero
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                self.popupBar.systemBarStyle = .black
            } else {
                self.popupBar.systemBarStyle = .default
            }
            self.popupBar.toolbar.barStyle = UIBarStyle(rawValue: Int(self.popupBar.barStyle.rawValue)) ?? .default
        }
    }
    
    @objc func updateSileoColors() {
        if UIColor.isDarkModeEnabled {
            self.popupBar.systemBarStyle = .black
        } else {
            self.popupBar.systemBarStyle = .default
        }
        self.popupBar.toolbar.barStyle = UIBarStyle(rawValue: Int(self.popupBar.barStyle.rawValue)) ?? .default
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.tabBar.itemPositioning = .centered
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.updatePopup()
        }
    }
}
