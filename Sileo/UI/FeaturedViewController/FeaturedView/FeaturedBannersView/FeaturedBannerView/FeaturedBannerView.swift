//
//  FeaturedBannerView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander

protocol FeaturedBannerViewPreview: AnyObject {
    func viewController(bannerView: FeaturedBannerView) -> UIViewController?
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    var parentViewController: UIViewController? { get }
}

class FeaturedBannerView: UIButton, UIViewControllerPreviewingDelegate {
    weak var previewDelegate: FeaturedBannerViewPreview?
    var interaction: NSObject?
    var banner: [String: Any] = [:] {
        didSet {
            if let bannerURL = banner["url"] as? String {
                bannerImageView?.image = EvanderNetworking.shared.image(bannerURL, size: itemSize) { [weak self] refresh, image in
                    if refresh,
                          let strong = self,
                          let image = image,
                          bannerURL == strong.banner["url"] as? String {
                        DispatchQueue.main.async {
                            strong.bannerImageView?.image = image
                        }
                    }
                }
            }
            
            if let bannerTitle = banner["title"] as? String {
                self.accessibilityLabel = bannerTitle
                bannerTitleLabel?.text = bannerTitle
            }
            
            let displayText = (banner["displayText"] as? Bool) ?? true
            let hideShadow = (banner["hideShadow"] as? Bool) ?? false
            
            darkeningView?.isHidden = !displayText || hideShadow
            bannerTitleLabel?.isHidden = !displayText
        }
    }
    
    var darkeningView: UIView?
    var highlightView: UIView?
    var bannerImageView: UIImageView?
    var bannerTitleLabel: UILabel?
    var itemSize: CGSize?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.accessibilityIgnoresInvertColors = true
        
        self.clipsToBounds = true
        
        bannerImageView = UIImageView(frame: self.bounds)
        bannerImageView?.contentMode = .scaleAspectFill
        bannerImageView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bannerImageView?.isUserInteractionEnabled = false
        self.addSubview(bannerImageView!)
        
        darkeningView = CSGradientView(frame: self.bounds)
        darkeningView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        darkeningView?.isUserInteractionEnabled = false
        self.addSubview(darkeningView!)
        
        let bannerTitleLabel = UILabel(frame: .zero)
        bannerTitleLabel.textColor = .white
        bannerTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        bannerTitleLabel.isUserInteractionEnabled = false
        bannerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(bannerTitleLabel)
        
        self.bannerTitleLabel = bannerTitleLabel
        
        bannerTitleLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 16).isActive = true
        bannerTitleLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -16).isActive = true
        bannerTitleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16).isActive = true
        
        let highlightView = UIView(frame: .zero)
        highlightView.backgroundColor = .clear
        highlightView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        highlightView.isUserInteractionEnabled = false
        self.addSubview(highlightView)
        
        self.highlightView = highlightView
        
        if #available(iOS 13, *) {
            let interactionDelegate = FeaturedBannerViewInteractionDelegate(bannerView: self)
            self.interaction = interactionDelegate
            let interaction = UIContextMenuInteraction(delegate: interactionDelegate)
            self.addInteraction(interaction)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                highlightView?.backgroundColor = UIColor(white: 0, alpha: 0.2)
            } else {
                highlightView?.backgroundColor = .clear
            }
        }
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        self.previewDelegate?.viewController(bannerView: self)
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.previewDelegate?.previewingContext(previewingContext, commit: viewControllerToCommit)
    }
}

@available (iOS 13, *)
class FeaturedBannerViewInteractionDelegate: NSObject, UIContextMenuInteractionDelegate {
    weak var bannerView: FeaturedBannerView!
    
    init(bannerView: FeaturedBannerView) {
        self.bannerView = bannerView
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        if let viewController = bannerView.previewDelegate?.viewController(bannerView: bannerView) {
            let actions = (viewController as? PackageViewController)?.actions() ?? []
            
            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                viewController
            }, actionProvider: {_ in
                UIMenu(title: "", options: .displayInline, children: actions)
            })
        }
        return nil
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        if let controller = animator.previewViewController {
            animator.addAnimations {
                self.bannerView.previewDelegate?.parentViewController?.show(controller, sender: nil)
            }
        }
    }
}
