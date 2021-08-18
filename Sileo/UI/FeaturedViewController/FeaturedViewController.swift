//
//  FeaturedViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/18/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation

final class FeaturedViewController: SileoViewController, UIScrollViewDelegate, FeaturedViewDelegate {
    private var profileButton: UIButton?
    @IBOutlet var scrollView: UIScrollView?
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView?
    var featuredView: FeaturedBaseView?
    var cachedData: [String: Any]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = String(localizationKey: "Featured_Page")
        self.navigationController?.tabBarItem._setInternalTitle(String(localizationKey: "Featured_Page"))
        
        self.setupProfileButton()
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updatePicture),
                                               name: Notification.Name("iCloudProfile"),
                                               object: nil)
        
        UIView.animate(withDuration: 0.7, animations: {
            self.activityIndicatorView?.alpha = 0
        }, completion: { _ in
            self.activityIndicatorView?.isHidden = true
        })

        #if targetEnvironment(simulator) || TARGET_SANDBOX
        #else
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
            let (status, output, _) = spawnAsRoot(args: [CommandPath.whoami])
            print(status, output)
            if status != 0 || output != "root\n" {
                DispatchQueue.main.sync {
                    let alertController = UIAlertController(title: String(localizationKey: "Installation_Error.Title", type: .error),
                                                            message: String(localizationKey: "Installation_Error.Body", type: .error),
                                                            preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            
            PackageListManager.shared.initWait()
            
            var foundBroken = false
            for package in PackageListManager.shared.installedPackages.values where package.status == .halfconfigured {
                foundBroken = true
            }
            
            if DpkgWrapper.dpkgInterrupted() || foundBroken {
                DispatchQueue.main.sync {
                    let alertController = UIAlertController(title: String(localizationKey: "FixingDpkg.Title", type: .error),
                                                            message: String(localizationKey: "FixingDpkg.Body", type: .error),
                                                            preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
                
                DispatchQueue.global(qos: .default).async {
                    let (status, output, errorOutput) = spawnAsRoot(args: [CommandPath.dpkg, "--configure", "-a"])
                    PackageListManager.shared.installChange()
                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {
                            if status != 0 {
                                let errorAttrs = [NSAttributedString.Key.foregroundColor: Dusk.errorColor]
                                let errorString = NSMutableAttributedString(string: errorOutput, attributes: errorAttrs)
                                
                                let stringAttrs = [NSAttributedString.Key.foregroundColor: Dusk.foregroundColor]
                                let mutableAttributedString = NSMutableAttributedString(string: output, attributes: stringAttrs)
                                mutableAttributedString.append(NSAttributedString(string: "\n"))
                                mutableAttributedString.append(errorString)
                                
                                let errorsVC = SourcesErrorsViewController(nibName: "SourcesErrorsViewController", bundle: nil)
                                errorsVC.attributedString = mutableAttributedString
                                
                                let navController = UINavigationController(rootViewController: errorsVC)
                                navController.navigationBar.barStyle = .blackTranslucent
                                navController.modalPresentationStyle = .formSheet
                                self.present(navController, animated: true, completion: nil)
                            }
                        }
                    }
                }
            }
        }
        #endif
    }
    
    private var userAgent: String {
        let cfVersion = String(format: "%.3f", kCFCoreFoundationVersionNumber)
        let bundleName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] ?? ""
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
        let osType = UIDevice.current.kernOSType
        let osRelease = UIDevice.current.kernOSRelease
        return "\(bundleName)/\(bundleVersion)/FeaturedPage CoreFoundation/\(cfVersion) \(osType)/\(osRelease)"
    }
    
    @objc func reloadData() {
        if UIApplication.shared.applicationState == .background {
            return
        }
        #if targetEnvironment(macCatalyst)
        let deviceName = "mac"
        #else
        let deviceName = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #endif
        guard let jsonURL = StoreURL("featured-\(deviceName).json") else {
            return
        }
        let agent = self.userAgent 
        let headers: [String: String] = ["User-Agent": agent]
        AmyNetworkResolver.dict(url: jsonURL, headers: headers, cache: true) { [weak self] success, dict in
            guard success,
                  let strong = self,
                  let dict = dict else { return }
            if let cachedData = strong.cachedData,
               NSDictionary(dictionary: cachedData).isEqual(to: dict) {
                return
            }
            strong.cachedData = dict
            DispatchQueue.main.async {
                if let minVersion = dict["minVersion"] as? String,
                    minVersion.compare(StoreVersion) == .orderedDescending {
                    strong.versionTooLow()
                }
                
                CanisterResolver.nistercanQueue.async {
                    let packageMan = PackageListManager.shared
                    packageMan.initWait()
                    
                    // Nistercan trolling
                    var packages = [String]()
                    func findPackageInDict(_ dict: [String: Any]) {
                        for (key, value) in dict {
                            if key == "package",
                               let package = value as? String {
                                packages.append(package)
                            } else if let dict = value as? [String: Any] {
                                findPackageInDict(dict)
                            } else if let array = value as? [[String: Any]] {
                                for view in array {
                                    findPackageInDict(view)
                                }
                            }
                        }
                    }
                    findPackageInDict(dict)
                    
                    var nonFound = [String]()
                    let allPackages = packageMan.allPackagesArray
                    for package in packages {
                        if packageMan.newestPackage(identifier: package, repoContext: nil, packages: allPackages) == nil {
                            nonFound.append(package)
                        }
                    }
                
                    CanisterResolver.shared.batchFetch(nonFound) { change in
                        if change {
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: FeaturedPackageView.featuredPackageReload, object: nil)
                            }
                        }
                    }
                }
                            
                strong.featuredView?.removeFromSuperview()
                if let featuredView = FeaturedBaseView.view(dictionary: dict,
                                                            viewController: strong,
                                                            tintColor: nil, isActionable: false) as? FeaturedBaseView {
                    featuredView.delegate = self
                    strong.featuredView?.removeFromSuperview()
                    strong.scrollView?.addSubview(featuredView)
                    strong.featuredView = featuredView
                }
                strong.viewDidLayoutSubviews()
            }
        }
    }
    
    func versionTooLow() {
        let alertController = UIAlertController(title: String(localizationKey: "Sileo_Update_Required.Title", type: .error),
                                                message: String(localizationKey: "Featured_Requires_Sileo_Update", type: .error),
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func updateSileoColors() {
        statusBarStyle = .default
        profileButton?.tintColor = .tintColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.reloadData()
        updateSileoColors()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.navigationItem.hidesSearchBarWhenScrolling = true
        scrollView?.contentInsetAdjustmentBehavior = .always
        
        self.navigationController?.navigationBar.superview?.tag = WHITE_BLUR_TAG
        self.navigationController?.navigationBar._hidesShadow = true
        
        UIView.animate(withDuration: 0.2) {
            self.profileButton?.alpha = 1.0
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.navigationBar._hidesShadow = false
        
        UIView.animate(withDuration: 0.2) {
            self.profileButton?.alpha = 0
        }
    }
    
    @objc private func updatePicture() {
        if let button = self.profileButton {
            self.profileButton = setPicture(button)
        }
    }
    
    private func windowCheck() {
        guard let tabBarController = UIApplication.shared.windows.first?.rootViewController as? UITabBarController else {
            fatalError("Invalid Storyboard")
        }
        for viewController in tabBarController.viewControllers ?? [] {
            if viewController as? SileoNavigationController != nil { continue }
            if viewController as? SourcesSplitViewController != nil { continue }
            tabBarController.viewControllers?.removeAll(where: { $0 == viewController })
        }
        if tabBarController.viewControllers?.count ?? 0 >= 6 {
            fatalError("Invalid View Controllers")
        }
    }
    
    func setPicture(_ button: UIButton) -> UIButton {
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        if UserDefaults.standard.optionalBool("iCloudProfile", fallback: true),
            let image = ICloudPFPHandler.refreshiCloudPicture({ image in
                DispatchQueue.main.async {
                    if UserDefaults.standard.optionalBool("iCloudProfile", fallback: true) {
                        button.setImage(image, for: .normal)
                    }
                }
            }) {
                button.setImage(image, for: .normal)
        } else {
            button.setImage(UIImage(named: "User")?.withRenderingMode(.alwaysTemplate), for: .normal)
        }
        button.tintColor = .tintColor
        windowCheck()
        return button
    }
    
    func setupProfileButton() {
        let profileButton = setPicture(UIButton())
        
        profileButton.addTarget(self, action: #selector(FeaturedViewController.showProfile(_:)), for: .touchUpInside)
        profileButton.accessibilityIgnoresInvertColors = true
        
        profileButton.layer.cornerRadius = 20
        profileButton.clipsToBounds = true
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        
        if let navigationBar = self.navigationController?.navigationBar {
            navigationBar.addSubview(profileButton)
            if LanguageHelper.shared.isRtl {
                profileButton.leftAnchor.constraint(equalTo: navigationBar.leftAnchor, constant: 16).isActive = true
            } else {
                profileButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -16).isActive = true
            }
            NSLayoutConstraint.activate([
                profileButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -12)
            ])
        }
        self.profileButton = profileButton
    }
    
    @objc func showProfile(_ sender: Any?) {
        let profileViewController = SettingsViewController(style: .grouped)
        let navController = SettingsNavigationController(rootViewController: profileViewController)
        self.present(navController, animated: true, completion: nil)
    }
    
    public func showPackage(_ package: Package?) {
        let packageViewController = PackageViewController(nibName: "PackageViewController", bundle: nil)
        packageViewController.package = package
        self.navigationController?.pushViewController(packageViewController, animated: true)
    }
    
    func moveAndResizeProfile(height: CGFloat) {
        let delta = height - 44
        let heightDifferenceBetweenStates: CGFloat = 96.5 - 44
        let coeff = delta / heightDifferenceBetweenStates
        
        let factor: CGFloat = 32.0/40.0
        
        let scale = min(1.0, coeff * (1.0 - factor) + factor)
        
        let sizeDiff = 40.0 * (1.0 - factor)
        let maxYTranslation = 12.0 - 6.0 + sizeDiff
        let yTranslation = max(0, min(maxYTranslation, (maxYTranslation - coeff * (6.0 + sizeDiff))))
        
        let xTranslation = max(0, sizeDiff - coeff * sizeDiff)
        profileButton?.transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xTranslation, y: yTranslation)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let height = self.navigationController?.navigationBar.frame.height else {
            return
        }
        self.moveAndResizeProfile(height: height)
    }
    
    func subviewHeightChanged() {
        self.viewDidLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let featuredHeight = featuredView?.depictionHeight(width: self.view.bounds.width) {
            scrollView?.contentSize = CGSize(width: self.view.bounds.width, height: featuredHeight)
        
            featuredView?.frame = CGRect(origin: .zero, size: CGSize(width: self.view.bounds.width, height: featuredHeight))
        }
        
        self.view.updateConstraintsIfNeeded()
    }
}
