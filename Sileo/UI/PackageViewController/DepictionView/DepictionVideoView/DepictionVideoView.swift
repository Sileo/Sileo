//
//  DepictionVideoView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import AVKit

class DepictionVideoView: DepictionBaseView {
    let alignment: Int

    var player: AVQueuePlayer?
    var playerViewController: AVPlayerViewController?
    var playerLooper: AVPlayerLooper?

    var videoView: UIView?

    let width: CGFloat
    let height: CGFloat

    var autoPlayEnabled: Bool = false
    var showPlaybackControls: Bool = false
    var loopEnabled: Bool = false

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let urlStr = dictionary["URL"] as? String else {
            return nil
        }
        guard let width = dictionary["width"] as? CGFloat else {
            return nil
        }
        guard let height = dictionary["height"] as? CGFloat else {
            return nil
        }
        self.width = width
        self.height = height
        alignment = (dictionary["alignment"] as? Int) ?? 0

        guard let videoURL = URL(string: urlStr) else {
            return nil
        }

        autoPlayEnabled = (dictionary["autoplay"] as? Bool) ?? false
        showPlaybackControls = (dictionary["showPlaybackControls"] as? Bool) ?? true
        loopEnabled = (dictionary["loop"] as? Bool) ?? false

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        let cornerRadius = (dictionary["cornerRadius"] as? CGFloat) ?? 0

        let playerItem = AVPlayerItem(url: videoURL)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        self.player = player

        if loopEnabled {
            playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        }

        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.showsPlaybackControls = showPlaybackControls

        videoView = playerViewController?.view
        if cornerRadius > 0 {
            videoView?.layer.cornerRadius = cornerRadius
            videoView?.clipsToBounds = true
        }
        self.addSubview(videoView!)

        if autoPlayEnabled {
            player.play()
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        height
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var width = self.width
        if width > self.bounds.width {
            width = self.bounds.width
        }

        var x = CGFloat(0)
        switch alignment {
        case 2: do {
            x = self.bounds.width - width
            break
            }
        case 1: do {
            x = (self.bounds.width - width)/2.0
            break
            }
        default: do {
            x = 0
            break
            }
        }

        videoView?.frame = CGRect(x: x, y: 0, width: width, height: height)
    }
}
