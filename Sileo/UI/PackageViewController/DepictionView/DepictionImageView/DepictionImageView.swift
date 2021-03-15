//
//  DepictionImageView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import SDWebImage

class DepictionImageView: DepictionBaseView {
    let alignment: Int

    let imageView: SDAnimatedImageView?

    var width: CGFloat
    var height: CGFloat
    let xPadding: CGFloat

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let url = dictionary["URL"] as? String else {
            return nil
        }
        let width = (dictionary["width"] as? CGFloat) ?? CGFloat(0)
        let height = (dictionary["height"] as? CGFloat) ?? CGFloat(0)
        guard width != 0 || height != 0 else {
            return nil
        }
        guard let cornerRadius = dictionary["cornerRadius"] as? CGFloat else {
            return nil
        }
        self.width = width
        self.height = height
        alignment = (dictionary["alignment"] as? Int) ?? 0
        xPadding = (dictionary["xPadding"] as? CGFloat) ?? CGFloat(0)

        imageView = SDAnimatedImageView(frame: .zero)

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        imageView?.sd_setImage(with: URL(string: url)) { image, _, _, _ in
            guard let size = image?.size else {
                return
            }
            if self.width == 0 {
                self.width = self.height * (size.width/size.height)
            }
            if self.height == 0 {
                self.height = self.width * (size.height/size.width)
            }
            self.delegate?.subviewHeightChanged()
        }
        imageView?.layer.cornerRadius = cornerRadius
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = true
        addSubview(imageView!)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        var height = self.height
        if self.width > (width - xPadding) {
            height = self.height * (width / self.width)
        }
        return height
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var width = self.width
        if width > self.bounds.width - xPadding {
            width = self.bounds.width - xPadding
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

        var height = self.height
        if width != self.width {
            height = self.height * width / self.width
        }
        imageView?.frame = CGRect(x: x, y: 0, width: width, height: height)
    }
}
