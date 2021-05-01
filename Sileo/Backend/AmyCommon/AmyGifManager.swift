//
//  GifManager.swift
//  NitrolessiOS
//
//  Created by A W on 16/02/2021.
//

import UIKit

class AmyGifManager {
 
    public class func generateGif(_ data: Data) -> AmyGif? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil), 
        let delayTime = ((metadata as NSDictionary)["{GIF}"] as? NSMutableDictionary)?["DelayTime"] as? Double else { return nil }
        var images = [UIImage]()
        let imageCount = CGImageSourceGetCount(source)
        for i in 0 ..< imageCount {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(UIImage(cgImage: image))
            }
        }
        let calculatedDuration = Double(imageCount) * delayTime
        return AmyGif(image: images, duration: calculatedDuration)
    }
    
}

class AmyGif: UIImage {
    var calculatedDuration: Double!
    var image: [UIImage]!
    
    convenience init(image: [UIImage], duration: Double) {
        self.init()
        self.image = image
        self.calculatedDuration = duration
    }
}
