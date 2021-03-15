//
//  FeaturedViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/18/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class FeaturedViewController: SileoViewController, UIScrollViewDelegate, FeaturedViewDelegate {
    private var profileButton: UIButton?
    @IBOutlet var scrollView: UIScrollView?
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView?
    var featuredView: FeaturedBaseView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = String(localizationKey: "Featured_Page")
        
        self.setupProfileButton()
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        self.reloadData()
        UIView.animate(withDuration: 0.7, animations: {
            self.activityIndicatorView?.alpha = 0
        }, completion: { _ in
            self.activityIndicatorView?.isHidden = true
        })
        DispatchQueue.global(qos: .userInitiated).async {
            PackageListManager.shared.waitForReady()
        }
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        #else
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
            let (status, output, _) = spawnAsRoot(command: "whoami")
            if status != 0 || output != "root\n" {
                DispatchQueue.main.sync {
                    let alertController = UIAlertController(title: String(localizationKey: "Installation_Error.Title", type: .error),
                                                            message: String(localizationKey: "Installation_Error.Body", type: .error),
                                                            preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            
            PackageListManager.shared.waitForReady()
            
            var foundBroken = false
            
            if let installedPackages = PackageListManager.shared.packagesList(loadIdentifier: "--installed", repoContext: nil) {
                for package in installedPackages where package.status == .halfconfigured {
                    foundBroken = true
                }
            }
            
            if DpkgWrapper.dpkgInterrupted() || foundBroken {
                DispatchQueue.main.sync {
                    let alertController = UIAlertController(title: String(localizationKey: "FixingDpkg.Title", type: .error),
                                                            message: String(localizationKey: "FixingDpkg.Body", type: .error),
                                                            preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
                
                DispatchQueue.global(qos: .default).async {
                    let (status, output, errorOutput) = spawnAsRoot(command: "dpkg --configure -a")
                    
                    PackageListManager.shared.purgeCache()
                    PackageListManager.shared.waitForReady()
                    
                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {
                            if status != 0 {
                                let errorsVC = SourcesErrorsViewController(nibName: "SourcesErrorsViewController", bundle: nil)
                                let mutableAttributedString = NSMutableAttributedString(string: output,
                                                                                        attributes: [
                                                                                            NSAttributedString.Key.foregroundColor: Dusk.foregroundColor
                                                                                        ])
                                
                                let errorString = NSMutableAttributedString(string: errorOutput,
                                                                            attributes: [NSAttributedString.Key.foregroundColor: Dusk.errorColor])
                                mutableAttributedString.append(NSAttributedString(string: "\n"))
                                mutableAttributedString.append(errorString)
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
    
    @objc func reloadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let deviceName = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
            
            guard let jsonURL = StoreURL("featured-\(deviceName).json") else {
                return
            }
            if let jsonData = try? Data(contentsOf: jsonURL, options: []) {
                if let rawDepiction = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
                    if let depiction = rawDepiction as? [String: Any] {
                        DispatchQueue.main.async {
                            if let minVersion = depiction["minVersion"] as? String,
                                minVersion.compare(StoreVersion) == .orderedDescending {
                                self.versionTooLow()
                            }
                            
                            self.featuredView?.removeFromSuperview()
                            if let featuredView = FeaturedBaseView.view(dictionary: depiction,
                                                                        viewController: self,
                                                                        tintColor: nil, isActionable: false) as? FeaturedBaseView {
                                featuredView.delegate = self
                                self.scrollView?.addSubview(featuredView)
                                self.featuredView = featuredView
                            }
                            self.viewDidLayoutSubviews()
                        }
                    }
                }
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
    
    func setupProfileButton() {
        let profileButton = UIButton()
        profileButton.setImage(UIImage(named: "User")?.withRenderingMode(.alwaysTemplate), for: .normal)
        profileButton.addTarget(self, action: #selector(FeaturedViewController.showProfile(_:)), for: .touchUpInside)
        profileButton.accessibilityIgnoresInvertColors = true
        
        profileButton.tintColor = .tintColor
        
        profileButton.layer.cornerRadius = 20
        profileButton.clipsToBounds = true
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        
        if let navigationBar = self.navigationController?.navigationBar {
            navigationBar.addSubview(profileButton)
            NSLayoutConstraint.activate([
                profileButton.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -16),
                profileButton.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -12),
                profileButton.heightAnchor.constraint(equalToConstant: 40),
                profileButton.widthAnchor.constraint(equalToConstant: 40)
            ])
        }
        self.profileButton = profileButton
    }
    
    @objc func showProfile(_ sender: Any?) {
        let profileViewController = SettingsViewController(style: .grouped)
        let navController = SettingsNavigationController(rootViewController: profileViewController)
        self.present(navController, animated: true, completion: nil)
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
