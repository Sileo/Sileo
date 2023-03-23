//
//  DepictionButton.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import SafariServices

class DepictionButton: UIButton {
    var isLink: Bool = false
    var depictionView: DepictionBaseView?
    
    override var isHighlighted: Bool {
        didSet {
            if isLink {
                self.backgroundColor = .clear
                depictionView?.isHighlighted = isHighlighted
                return
            }
            
            if isHighlighted {
                var tintHue: CGFloat = 0
                var tintSat: CGFloat = 0
                var tintBrightness: CGFloat = 0
                self.tintColor.getHue(&tintHue, saturation: &tintSat, brightness: &tintBrightness, alpha: nil)
                
                tintBrightness *= 0.75
                self.backgroundColor = UIColor(hue: tintHue, saturation: tintSat, brightness: tintBrightness, alpha: 1)
            } else {
                self.backgroundColor = self.tintColor
            }
        }
    }
    
    static func processAction(_ action: String, parentViewController: UIViewController?, openExternal: Bool) -> Bool {
        if action.hasPrefix("http"),
            let url = URL(string: action) {
            if openExternal {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let safariViewController = SFSafariViewController(url: url)
                safariViewController.preferredControlTintColor = UINavigationBar.appearance().tintColor
                parentViewController?.present(safariViewController, animated: true, completion: nil)
            }
        } else if action.hasPrefix("mailto"),
            let url = URL(string: action) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if action == "showInstalledContents" {
            if let packageViewController = parentViewController as? PackageViewController {
                let contentsViewController = InstalledContentsViewController(nibName: "InstalledContentsViewController", bundle: nil)
                contentsViewController.packageId = packageViewController.package?.package ?? ""
                
                parentViewController?.navigationController?.pushViewController(contentsViewController, animated: true)
                return true
            }
        } else if action == "showRepoContext" {
            if let packageViewController = parentViewController as? PackageViewController,
               let repo = packageViewController.package?.sourceRepo {
                if let navController = packageViewController.navigationController as? SileoNavigationController {
                    for viewController in navController.viewControllers {
                        if viewController.isKind(of: CategoryViewController.self) {
                            if let categoryVC = viewController as? CategoryViewController,
                               categoryVC.repoContext?.rawURL == repo.rawURL {
                                navController.popToViewController(categoryVC, animated: true)
                                return true
                            }
                        }
                    }
                }
                let categoryVC = CategoryViewController(style: .plain)
                categoryVC.repoContext = repo
                categoryVC.title = repo.repoName
                parentViewController?.navigationController?.pushViewController(categoryVC, animated: true)
                return true
            }
        } else if let url = URL(string: action) {
            if url.isSecure(prefix: "depiction") {
                let subpageController = DepictionSubpageViewController(nibName: "DepictionSubpageViewController", bundle: nil)
                subpageController.depictionURL = URL(string: String(action.dropFirst(10)))
                parentViewController?.navigationController?.pushViewController(subpageController, animated: true)
            } else if url.isSecure(prefix: "form") {
                if let formURL = URL(string: String(action.dropFirst(5))) {
                    let formController = DepictionFormViewController(formURL: formURL)
                    let navController = UINavigationController(rootViewController: formController)
                    navController.modalPresentationStyle = .formSheet
                    parentViewController?.present(navController, animated: true, completion: nil)
                }
            } else {
                var presentModally = false
                if let controller = URLManager.viewController(url: url, isExternalOpen: true, presentModally: &presentModally) {
                    if presentModally {
                        parentViewController?.present(controller, animated: true, completion: nil)
                    } else {
                        parentViewController?.navigationController?.pushViewController(controller, animated: true)
                    }
                }
            }
        }
        return false
    }
}
