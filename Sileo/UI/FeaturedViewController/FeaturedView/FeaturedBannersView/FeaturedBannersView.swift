//
//  FeaturedBannersView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

class FeaturedBannersView: FeaturedBaseView, FeaturedBannerViewPreview {
    var scrollView: UIScrollView?
    let stackView = UIStackView()
    
    let itemSize: CGSize
    
    let bannerViews: [FeaturedBannerView] = []
    
    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        var dictionary = dictionary
        
        let deviceName = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        if let specificDict = dictionary[deviceName] as? [String: Any] {
            dictionary = specificDict
        }
        
        guard let rawItemSize = dictionary["itemSize"] as? String else {
            return nil
        }
        
        guard let itemCornerRadius = dictionary["itemCornerRadius"] as? CGFloat else {
            return nil
        }
        
        let itemSize = NSCoder.cgSize(for: rawItemSize)
        guard itemSize != .zero else {
            return nil
        }
        self.itemSize = itemSize
        
        guard let banners = dictionary["banners"] as? [[String: Any]] else {
            return nil
        }
        
        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)
    
        let scrollView = UIScrollView(frame: self.bounds)
        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        self.addSubview(scrollView)
        
        self.scrollView = scrollView
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 16
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        scrollView.addSubview(stackView)
        
        stackView.heightAnchor.constraint(equalToConstant: itemSize.height).isActive = true
        stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16).isActive = true
        stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16).isActive = true
        stackView.leftAnchor.constraint(greaterThanOrEqualTo: scrollView.leftAnchor, constant: 16).isActive = true
        stackView.rightAnchor.constraint(lessThanOrEqualTo: scrollView.rightAnchor, constant: -16).isActive = true
        
        let centerX = stackView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor)
        centerX.priority = .defaultLow
        centerX.isActive = true
        
        var packages = [String]()
        for banner in banners {
            guard (banner["url"] as? String) != nil else {
                continue
            }
            guard (banner["title"] as? String) != nil else {
                continue
            }
            
            let bannerView = FeaturedBannerView()
            bannerView.layer.cornerRadius = itemCornerRadius
            bannerView.banner = banner
            if let package = banner["package"] as? String {
                packages.append(package)
            }
            bannerView.addTarget(self, action: #selector(FeaturedBannersView.bannerTapped), for: .touchUpInside)
            bannerView.widthAnchor.constraint(equalToConstant: itemSize.width).isActive = true
            bannerView.previewDelegate = self
            
            viewController.registerForPreviewing(with: bannerView, sourceView: bannerView)
            stackView.addArrangedSubview(bannerView)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func depictionHeight(width: CGFloat) -> CGFloat {
        itemSize.height + 32
    }
    
    func viewController(bannerView: FeaturedBannerView) -> UIViewController? {
        let banner = bannerView.banner
        if let package = banner["package"] as? String {
            let package: Package? = {
                if let holder = PackageListManager.shared.newestPackage(identifier: package, repoContext: nil) {
                    return holder
                } else if let provisional = CanisterResolver.shared.package(for: package) {
                    return provisional
                }
                return nil
            }()
            if let package = package {
                return NativePackageViewController.viewController(for: package)
            }
        } else if let packages = banner["packages"] as? [String] {
            if let controllerName = banner["controllerName"] as? String {
                let loadIdentifier = "idents: ".appending(packages.joined(separator: " "))
                let listViewController = PackageListViewController(nibName: "PackageListViewController", bundle: nil)
                listViewController.title = controllerName
                listViewController.packagesLoadIdentifier = loadIdentifier
                listViewController.navigationItem.largeTitleDisplayMode = .never
                return listViewController
            }
        }
        return nil
    }
    
    @objc func bannerTapped(_ bannerView: FeaturedBannerView) {
        guard let controller = self.viewController(bannerView: bannerView) else {
            if (bannerView.banner["package"] as? String) != nil {
                if let repoName = bannerView.banner["repoName"] as? String {
                    let title = String(localizationKey: "Package Unavailable")
                    let message = String(format: String(localizationKey: "Package_Unavailable"), repoName)
                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: { _ in
                        alertController.dismiss(animated: true, completion: nil)
                    }))
                    self.parentViewController?.present(alertController, animated: true, completion: nil)
                }
            }
            return
        }
        self.parentViewController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.parentViewController?.navigationController?.pushViewController(viewControllerToCommit, animated: false)
    }
}
