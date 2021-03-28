//
//  WishListManager.swift
//  Sileo
//
//  Created by CoolStar on 7/3/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class WishListManager {
    public static let shared = WishListManager()
    public static let changeNotification = NSNotification.Name("SileoWishlistChanged")
    private(set) public var wishlist: [String] = []
    
    init() {
        self.reloadData()
    }
    
    func reloadData() {
        guard var rawWishlist = UserDefaults.standard.array(forKey: "wishlist") as? [String] else {
            wishlist = []
            return
        }
        let installedPackages = PackageListManager.shared.packagesList(loadIdentifier: "--installed", repoContext: nil) ?? []
        rawWishlist.removeAll { item in installedPackages.contains { $0.package == item } }
        wishlist = rawWishlist
    }
    
    func isPackageInWishList(_ package: String) -> Bool {
        wishlist.contains(package)
    }
    
    func addPackageToWishList(_ package: String) -> Bool {
        guard PackageListManager.shared.installedPackage(identifier: package) == nil else {
            return false
        }
        if self.isPackageInWishList(package) {
            return false
        }
        wishlist.append(package)
        UserDefaults.standard.set(wishlist, forKey: "wishlist")
        NotificationCenter.default.post(name: WishListManager.changeNotification, object: nil)
        return true
    }
    
    func removePackageFromWishList(_ package: String) {
        wishlist.removeAll { package == $0 }
        UserDefaults.standard.set(wishlist, forKey: "wishlist")
        NotificationCenter.default.post(name: WishListManager.changeNotification, object: nil)
    }
}
