//
//  DepictionAdmobView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import GoogleMobileAds
import AdSupport

class DepictionAdmobView: DepictionBaseView, GADBannerViewDelegate {
    var bannerView: GADBannerView?

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let adUnitID = dictionary["adUnitID"] as? String else {
            return nil
        }

        if let packageViewController = viewController as? PackageViewController {
            guard packageViewController.packageAdvertisementCount < 1 else {
                return nil
            }
        }

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        var adSize = kGADAdSizeMediumRectangle
        var adCount = Double(1)

        if let adSizeStr = dictionary["adSize"] as? String {
            if adSizeStr == "LargeBanner" {
                adSize = kGADAdSizeLargeBanner
                adCount = 0.4
            }
            if adSizeStr == "Banner" {
                adSize = kGADAdSizeBanner
                adCount = 0.2
            }
            if adSizeStr == "SmartBanner" {
                adSize = kGADAdSizeSmartBannerPortrait
                adCount = 0.28
            }
        }

        if let packageViewController = viewController as? PackageViewController {
            if packageViewController.packageAdvertisementCount + adCount > 1 {
                return nil
            }
            packageViewController.packageAdvertisementCount += adCount
        }

        bannerView = GADBannerView(adSize: adSize)
        bannerView?.delegate = self
        bannerView?.adUnitID = adUnitID
        bannerView?.rootViewController = viewController

        self.addSubview(bannerView!)

        if !ASIdentifierManager.shared().isAdvertisingTrackingEnabled {
            /*
 [[GADODevice sharedInstance] setValue:[UIDevice currentDevice]._uniqueIdentifierUUID forKey:@"_pseudonymousIdentifier"];
 [[GADOInjectedSettings sharedInstance] addEntriesFromDictionary:@{@"use_pseudonym": @true}];
             */
        }

        let request = GADRequest()
        if let contentURL = dictionary["contentURL"] as? String {
            request.contentURL = contentURL
        } else if let packageViewController = viewController as? PackageViewController,
            let package = packageViewController.package {
            if URL(string: package.legacyDepiction ?? "") != nil {
                request.contentURL = package.legacyDepiction
            } else {
                if let sourceRepo = package.sourceRepo {
                    request.contentURL = URL(string: package.legacyDepiction ?? "", relativeTo: sourceRepo.url)?.absoluteString
                }
            }
        }

        bannerView?.load(request)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        guard let bannerView = self.bannerView else {
            return 0
        }
        return bannerView.bounds.size.height + 5
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let bannerView = self.bannerView {
            bannerView.frame = CGRect(origin: CGPoint(x: (self.frame.width - bannerView.bounds.width)/2, y: 2.5), size: bannerView.bounds.size)
        }
    }

    func adViewDidReceiveAd(_ bannerView: GADBannerView) {

    }

    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        print("loading ad failed: ", error)
    }
}
