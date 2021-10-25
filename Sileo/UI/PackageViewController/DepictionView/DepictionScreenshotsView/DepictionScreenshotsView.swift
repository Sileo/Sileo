//
//  DepictionScreenshotsView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander
import AVKit

class DepictionScreenshotsView: DepictionBaseView, UIScrollViewDelegate {
    private let depiction: [String: Any]
    private let scrollView: UIScrollView = UIScrollView(frame: .zero)

    private let itemSize: CGSize
    private let itemCornerRadius: CGFloat

    private var screenshotViews: [UIView] = []

    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?

    private let isPaging: Bool

    convenience required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        self.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isPaging: false, isActionable: isActionable)
    }

    @objc required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isPaging: Bool, isActionable: Bool) {
        var dictionary = dictionary

        let deviceName = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        if let specificDict = dictionary[deviceName] as? [String: Any] {
            dictionary = specificDict
        }

        guard let rawItemSize = dictionary["itemSize"] as? String else {
            return nil
        }
        let itemSize = NSCoder.cgSize(for: rawItemSize)
        if itemSize == .zero {
            return nil
        }
        self.itemSize = itemSize

        guard let itemCornerRadius = dictionary["itemCornerRadius"] as? CGFloat else {
            return nil
        }
        self.itemCornerRadius = itemCornerRadius
        self.isPaging = isPaging

        guard let screenshots = dictionary["screenshots"] as? [[String: Any]] else {
            return nil
        }

        depiction = dictionary

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        scrollView.delegate = self
        scrollView.decelerationRate = .fast
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = isPaging
        if (viewController as? DepictionScreenshotsViewController) != nil {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        self.addSubview(scrollView)

        var idx = 0
        for screenshot in screenshots {
            guard let urlStr = screenshot["url"] as? String else {
                continue
            }
            guard let url = URL(string: urlStr) else {
                continue
            }
            guard let accessibilityText = screenshot["accessibilityText"] as? String else {
                continue
            }

            let isVideoView = (screenshot["video"] as? Bool) ?? false

            if isVideoView {
                player = AVPlayer(url: url)
                player?.isMuted = true

                playerViewController = AVPlayerViewController()
                playerViewController?.player = player

                let videoView = playerViewController?.view
                if itemCornerRadius > 0 {
                    videoView?.layer.cornerRadius = itemCornerRadius
                    videoView?.clipsToBounds = true
                }
                if let videoView = videoView {
                    screenshotViews.append(videoView)
                    scrollView.addSubview(videoView)
                }
            } else {
                let screenshotView = UIButton(frame: .zero)
                if (viewController as? DepictionScreenshotsViewController) != nil && screenshot["fullSizeURL"] as? String != nil {
                    if let fullSizeURL = screenshot["fullSizeURL"] as? String {
                        if let image = EvanderNetworking.shared.image(fullSizeURL, size: itemSize, { [weak self] refresh, image in
                            if refresh,
                               let strong = self,
                               let image = image {
                                DispatchQueue.main.async {
                                    screenshotView.setBackgroundImage(image, for: .normal)
                                    strong.layoutSubviews()
                                }
                            }
                        }) {
                            screenshotView.setBackgroundImage(image, for: .normal)
                            self.layoutSubviews()
                        }
                    }
                } else {
                    if let image = EvanderNetworking.shared.image(url, size: itemSize, { [weak self] refresh, image in
                        if refresh,
                           let strong = self,
                           let image = image {
                            DispatchQueue.main.async {
                                screenshotView.setBackgroundImage(image, for: .normal)
                                strong.layoutSubviews()
                            }
                        }
                    }) {
                        screenshotView.setBackgroundImage(image, for: .normal)
                        self.layoutSubviews()
                    }
                }
                screenshotView.accessibilityLabel = accessibilityText
                if (viewController as? DepictionScreenshotsViewController) != nil {
                    screenshotView.isUserInteractionEnabled = false
                } else {
                    screenshotView.addTarget(self, action: #selector(DepictionScreenshotsView.fullScreenImage), for: .touchUpInside)
                }
                screenshotView.accessibilityIgnoresInvertColors = true
                screenshotView.layer.cornerRadius = itemCornerRadius
                screenshotView.clipsToBounds = true
                screenshotView.tag = idx

                screenshotViews.append(screenshotView)
                scrollView.addSubview(screenshotView)
            }
            idx+=1
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        (isPaging ? self.fullViewHeight() : itemSize.height) + 32
    }

    func fullViewHeight() -> CGFloat {
        guard let parentViewController = self.parentViewController else {
            return 0
        }
        let verticalInsets = parentViewController.view.safeAreaInsets.top + parentViewController.view.safeAreaInsets.bottom
        return parentViewController.view.bounds.height - 32 - verticalInsets
    }

    @objc func fullScreenImage(_ :Any) {
        let viewcontroller = DepictionScreenshotsViewController()
        viewcontroller.tintColor = self.tintColor
        viewcontroller.depiction = depiction
        let navController = UINavigationController(rootViewController: viewcontroller)
        self.parentViewController?.present(navController, animated: true, completion: nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let oldSize = itemSize
        let spacing = CGFloat(16)
        var x = spacing
        var viewHeight = itemSize.height

        if isPaging {
            let viewWidth = (self.parentViewController?.view.bounds.width ?? 0) - (spacing * 4)
            x *= 2

            viewHeight = self.fullViewHeight()

            var scale = viewWidth / oldSize.width
            if oldSize.height * scale > viewHeight {
                scale = viewHeight / oldSize.height
            }
            let imageSize = CGSize(width: oldSize.width * scale, height: oldSize.height * scale)

            for screenshotView in screenshotViews {
                var size = imageSize
                if let screenshotViewButton = screenshotView as? UIButton {
                    if let backgroundImage = screenshotViewButton.currentBackgroundImage {
                        size = backgroundImage.size
                    }
                }

                size.height = size.height * imageSize.width / size.width
                size.width = imageSize.width

                if viewWidth/size.width < viewHeight/size.width {
                    scale = viewWidth / size.width
                } else {
                    scale = viewHeight / size.height
                }

                size.height *= scale
                size.width *= scale

                screenshotView.frame = CGRect(origin: CGPoint(x: x + (viewWidth / 2 - size.width / 2),
                                                              y: 16 + (viewHeight / 2 - size.height / 2)),
                                              size: size)
                screenshotView.layer.cornerRadius = itemCornerRadius * scale
                x += viewWidth + spacing
            }

            if x < self.parentViewController?.view.bounds.width ?? 0 {
                x = self.parentViewController?.view.bounds.width ?? 0
            } else {
                x += spacing
            }
        } else {
            for screenshotView in screenshotViews {
                var size = itemSize
                if let screenshotViewButton = screenshotView as? UIButton {
                    if let backgroundImage = screenshotViewButton.currentBackgroundImage {
                        size = backgroundImage.size
                    }
                }

                let rawImageSize = size

                size.width = size.width * itemSize.height / size.height
                size.height = itemSize.height

                var scaling = CGFloat(1)
                var yOffset = CGFloat(0)
                let maxWidth = self.bounds.width - (spacing * 2)

                if size.width > maxWidth {
                    scaling = maxWidth / size.width
                    size.width *= scaling

                    let scaledHeight = size.width * rawImageSize.height/rawImageSize.width

                    yOffset = (itemSize.height - scaledHeight)/2
                    size.height *= scaling
                }

                screenshotView.frame = CGRect(origin: CGPoint(x: x, y: 16 + yOffset), size: size)
                screenshotView.layer.cornerRadius = itemCornerRadius * scaling
                x += size.width + spacing
            }
        }

        scrollView.contentSize = CGSize(width: x, height: viewHeight + 32)
        if x < self.bounds.width && !isPaging {
            scrollView.frame = CGRect(x: (self.bounds.width - x)/2, y: 0, width: x, height: self.bounds.height)
        } else {
            scrollView.frame = self.bounds
        }

        if itemSize != oldSize || isPaging {
            self.subviewHeightChanged()
        }
    }

    func viewSegmentWidth() -> CGFloat {
        let spacing = CGFloat(16)
        guard let parentViewController = self.parentViewController else {
            return 0
        }
        return parentViewController.view.bounds.width - (spacing * 3)
    }

    func pageIndex(contentOffset: CGFloat) -> Int {
        let endX = Float(contentOffset)
        return Int(min(10, max(0, round(endX / Float(self.viewSegmentWidth())))))
    }

    func currentPageIndex() -> Int {
        pageIndex(contentOffset: scrollView.contentOffset.x)
    }

    func contentOffset(pageIndex: Int) -> CGFloat {
        CGFloat(pageIndex) * viewSegmentWidth()
    }

    func scrollToPageIndex(_ pageIndex: Int, animated: Bool) {
        scrollView.setContentOffset(CGPoint(x: self.contentOffset(pageIndex: pageIndex), y: 0), animated: animated)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if !isPaging {
            return
        }

        let targetIndex = self.pageIndex(contentOffset: targetContentOffset.pointee.x)
        targetContentOffset.pointee.x = self.contentOffset(pageIndex: targetIndex)
    }
}
