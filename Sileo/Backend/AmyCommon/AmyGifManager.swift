//
//  GifManager.swift
//  NitrolessiOS
//
//  Created by Amy While on 16/02/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit

final class GifController: UIImage {
    var calculatedDuration: Double?
    var animatedImages: [UIImage]?

    override convenience init?(data: Data) {
        self.init()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
        let delayTime = ((metadata as NSDictionary)["{GIF}"] as? NSMutableDictionary)?["DelayTime"] as? Double else { return nil }
        var images = [UIImage]()
        let imageCount = CGImageSourceGetCount(source)
        for i in 0 ..< imageCount {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let tmpImage = UIImage(cgImage: image)
                if let downscaled = GifController.downsample(image: tmpImage, to: CGSize(width: 48, height: 48)) {
                    images.append(downscaled)
                } else {
                    images.append(tmpImage)
                }
            }
        }
        let calculatedDuration = Double(imageCount) * delayTime
        self.animatedImages = images
        self.calculatedDuration = calculatedDuration
    }
    
    public class func downsample(image: UIImage, to pointSize: CGSize? = nil, scale: CGFloat? = nil) -> UIImage? {
        let size = /*pointSize ??*/ image.size
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let data = image.pngData() as CFData?,
              let imageSource = CGImageSourceCreateWithData(data, imageSourceOptions) else { return nil }
        let maxDimentionInPixels = max(size.width, size.height) * (scale ?? UIScreen.main.scale)
        let downsampledOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceShouldCacheImmediately: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxDimentionInPixels] as CFDictionary
        guard let downScaledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampledOptions) else { return nil }
        let downsampled = UIImage(cgImage: downScaledImage)
        return downsampled
    }
}
