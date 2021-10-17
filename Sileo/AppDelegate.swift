//
//  AppDelegate.swift
//  Sileo
//
//  Created by CoolStar on 8/29/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import UserNotifications
import Evander
	
class SileoAppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {
    public var window: UIWindow?
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        #if targetEnvironment(macCatalyst)
        _ = MacRootWrapper.shared
        #endif
        SileoThemeManager.shared.updateUserInterface()
        // Begin parsing sources files
        _ = RepoManager.shared
        // Init the local database
        _ = PackageListManager.shared
        _ = DatabaseManager.shared
        _ = DownloadManager.shared
        // Will delete anything cached older than 7 days
        _ = EvanderNetworking.shared
        // Start the language helper for customised localizations
        _ = LanguageHelper.shared
        
        guard let tabBarController = self.window?.rootViewController as? UITabBarController else {
            fatalError("Invalid Storyboard")
        }
        tabBarController.delegate = self
        tabBarController.tabBar._blurEnabled = true
        tabBarController.tabBar.tag = WHITE_BLUR_TAG
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3)) {
            let updatesPrompt = UserDefaults.standard.bool(forKey: "updatesPrompt")
            if !updatesPrompt {
                if UIApplication.shared.backgroundRefreshStatus == .denied {
                    DispatchQueue.main.async {
                        let title = String(localizationKey: "Background_App_Refresh")
                        let msg = String(localizationKey: "Background_App_Refresh_Message")
                        
                        let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: String(localizationKey: "OK"), style: .cancel) { _ in
                            alert.dismiss(animated: true, completion: nil)
                        }
                        alert.addAction(okAction)
                        self.window?.rootViewController?.present(alert, animated: true, completion: nil)
                        
                        UserDefaults.standard.set(true, forKey: "updatesPrompt")
                    }
                }
            }
        }
        
        UIApplication.shared.setMinimumBackgroundFetchInterval(4 * 3600)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {_, _ in
            
        }
        
        _ = NotificationCenter.default.addObserver(forName: SileoThemeManager.sileoChangedThemeNotification, object: nil, queue: nil) { _ in
            self.updateTintColor()
            for window in UIApplication.shared.windows {
                for view in window.subviews {
                    view.removeFromSuperview()
                    window.addSubview(view)
                }
            }
        }
        self.updateTintColor()
        
        // Force all view controllers to load now
        for (index, controller) in (tabBarController.viewControllers ?? []).enumerated() {
            _ = controller.view
            if let navController = controller as? UINavigationController {
                _ = navController.viewControllers[0].view
            }
            if index == 4 {
                controller.tabBarItem._setInternalTitle(String(localizationKey: "Search_Page"))
            }
        }
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            PackageListManager.shared.initWait()
            
            let currentUpdates = PackageListManager.shared.availableUpdates().filter({ $0.1?.wantInfo != .hold }).map({ $0.0 })
            let currentPackages = PackageListManager.shared.allPackagesArray
            if currentUpdates.isEmpty { return completionHandler(.newData) }
            RepoManager.shared.update(force: false, forceReload: false, isBackground: true) { _, _ in
                let newUpdates = PackageListManager.shared.availableUpdates().filter({ $0.1?.wantInfo != .hold }).map({ $0.0 })
                let newPackages = PackageListManager.shared.allPackagesArray
                if newPackages.isEmpty { return completionHandler(.newData) }
                
                let diffUpdates = newUpdates.filter { !currentUpdates.contains($0) }
                if diffUpdates.count > 3 {
                    let content = UNMutableNotificationContent()
                    content.title = String(localizationKey: "Updates Available")
                    content.body = String(format: String(localizationKey: "New updates for %d packages are available"), diffUpdates.count)
                    content.badge = newUpdates.count as NSNumber
                    
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: "org.coolstar.sileo.updates", content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                } else {
                    for package in diffUpdates {
                        let content = UNMutableNotificationContent()
                        content.title = String(localizationKey: "New Update")
                        content.body = String(format: String(localizationKey: "%@ by %@ has been updated to version %@ on %@"),
                                              package.name ?? "",
                                              ControlFileParser.authorName(string: package.author ?? ""),
                                              package.version,
                                              package.sourceRepo?.displayName ?? "")
                        content.badge = newUpdates.count as NSNumber
                        
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        
                        let request = UNNotificationRequest(identifier: "org.coolstar.sileo.update-\(package.package)",
                                                            content: content,
                                                            trigger: trigger)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    }
                }
                
                let diffPackages = newPackages.filter { !currentPackages.contains($0) }
                
                let wishlist = WishListManager.shared.wishlist
                for package in diffPackages {
                    if wishlist.contains(package.package) {
                        let content = UNMutableNotificationContent()
                        content.title = String(localizationKey: "New Update")
                        content.body = String(format: String(localizationKey: "%@ by %@ has been updated to version %@ on %@"),
                                              package.name ?? "",
                                              ControlFileParser.authorName(string: package.author ?? ""),
                                              package.version,
                                              package.sourceRepo?.displayName ?? "")
                        content.badge = newUpdates.count as NSNumber
                        
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        
                        let request = UNNotificationRequest(identifier: "org.coolstar.sileo.update-\(package.package)",
                                                            content: content,
                                                            trigger: trigger)
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    }
                }
                completionHandler(.newData)
            }
        }
        
    }
    
    func updateTintColor() {
        var tintColor = UIColor.tintColor
        if UIAccessibility.isInvertColorsEnabled {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            tintColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            tintColor = UIColor(red: 1 - red, green: 1 - green, blue: 1 - blue, alpha: 1 - alpha)
        }
        
        if #available(iOS 13, *) {
        } else {
            if UIColor.isDarkModeEnabled {
                UINavigationBar.appearance().barStyle = .blackTranslucent
                UITabBar.appearance().barStyle = .black
                UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).keyboardAppearance = .dark
            } else {
                UINavigationBar.appearance().barStyle = .default
                UITabBar.appearance().barStyle = .default
                UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).keyboardAppearance = .default
            }
        }
        
        UINavigationBar.appearance().tintColor = tintColor
        UIToolbar.appearance().tintColor = tintColor
        UISearchBar.appearance().tintColor = tintColor
        UITabBar.appearance().tintColor = tintColor
        
        UICollectionView.appearance().tintColor = tintColor
        UITableView.appearance().tintColor = tintColor
        DepictionBaseView.appearance().tintColor = tintColor
        self.window?.tintColor = tintColor
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        DispatchQueue.global(qos: .default).async {
            PackageListManager.shared.initWait()
            DispatchQueue.main.async {
                if url.scheme == "file" {
                    // The file is a deb. Open the package view controller to that file.
                    guard let tabBarController = self.window?.rootViewController as? UITabBarController,
                        let featuredVc = tabBarController.viewControllers?[0] as? UINavigationController?,
                        let featuredView = featuredVc?.viewControllers[0] as? FeaturedViewController else {
                        return
                    }
                    featuredView.showPackage(PackageListManager.shared.package(url: url))
                    tabBarController.selectedIndex = 0
                } else {
                    // presentModally ignored; we always present modally for an external URL open.
                    var presentModally = false
                    if let viewController = URLManager.viewController(url: url, isExternalOpen: true, presentModally: &presentModally) {
                        self.window?.rootViewController?.present(viewController, animated: true, completion: nil)
                    }
                }
            }
        }
        
        if url.host == "source" && url.scheme == "sileo" {
            guard let tabBarController = self.window?.rootViewController as? UITabBarController,
                let sourcesSVC = tabBarController.viewControllers?[2] as? UISplitViewController,
                let sourcesNavNV = sourcesSVC.viewControllers[0] as? SileoNavigationController,
                let sourcesVC = sourcesNavNV.viewControllers[0] as? SourcesViewController else {
                return false
            }
            let newURL = url.absoluteURL
            tabBarController.selectedViewController = sourcesSVC
            sourcesVC.presentAddSourceEntryField(url: newURL)
        }
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let tabBarController = TabBarController.singleton,
              let controllers = tabBarController.viewControllers,
              let sourcesSVC = controllers[2] as? SourcesSplitViewController,
              let sourcesNVC = sourcesSVC.viewControllers[0] as? SileoNavigationController,
              let sourcesVC = sourcesNVC.viewControllers[0] as? SourcesViewController,
              let packageListNVC = controllers[3] as? SileoNavigationController,
              let packageListVC = packageListNVC.viewControllers[0] as? PackageListViewController
        else {
            return
        }
        
        if shortcutItem.type.hasSuffix(".UpgradeAll") {
            tabBarController.selectedViewController = packageListNVC
            
            let title = String(localizationKey: "Sileo")
            let msg = String(localizationKey: "Upgrade_All_Shortcut_Processing_Message")
            let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
            packageListVC.present(alert, animated: true, completion: nil)
            
            sourcesVC.refreshSources(forceUpdate: true, forceReload: true, isBackground: false, useRefreshControl: true, useErrorScreen: true, completion: { _, _ in
                PackageListManager.shared.upgradeAll(completion: {
                    if UserDefaults.standard.optionalBool("AutoConfirmUpgradeAllShortcut", fallback: false) {
                        let downloadMan = DownloadManager.shared
                        downloadMan.reloadData(recheckPackages: false)
                    }
                    
                    tabBarController.presentPopupController()
                    alert.dismiss(animated: true, completion: nil)
                })
            })
        } else if shortcutItem.type.hasSuffix(".Refresh") {
            tabBarController.selectedViewController = sourcesSVC
            sourcesVC.refreshSources(forceUpdate: true, forceReload: true, isBackground: false, useRefreshControl: true, useErrorScreen: true, completion: nil)
        } else if shortcutItem.type.hasSuffix(".AddSource") {
            tabBarController.selectedViewController = sourcesSVC
            sourcesVC.addSource(nil)
        } else if shortcutItem.type.hasSuffix(".Packages") {
            tabBarController.selectedViewController = packageListNVC
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        UIColor.isTransitionLockedForiOS13Bug = true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        UIColor.isTransitionLockedForiOS13Bug = false
    }
}
