//
//  FolderFinder.swift
//  Sileo
//
//  Created by Andromeda on 04/08/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation
import Evander

final class ICloudPFPHandler {
    
    final class func findSharedFolder(appName: String) -> String? {
        let dir = "/var/mobile/Containers/Shared/AppGroup/"
        return Self.findFolder(appName: appName, folder: dir)
    }
    
    final class func findDataFolder(appName: String) -> String? {
        let dir = "/var/mobile/Containers/Data/Application/"
        return Self.findFolder(appName: appName, folder: dir)
    }
    
    final class func findPrivateSharedFolder(appName: String) -> String? {
        let dir = "/private/var/mobile/Containers/Shared/AppGroup/"
        return Self.findFolder(appName: appName, folder: dir)
    }
    
    final class func findFolder(appName: String, folder: String) -> String? {
        guard let folders =  try? FileManager.default.contentsOfDirectory(atPath: folder) else { return nil }
        // swiftlint:disable identifier_name
        for _folder in folders {
            let folderPath = folder + _folder
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: folderPath) else { return nil }
            for itemPath in items {
                if let substringRange = itemPath.range(of: ".com.apple.mobile_container_manager.metadata.plist") {
                    let range = NSRange(substringRange, in: itemPath)
                    if range.location != NSNotFound {
                        let fullPath = "\(folderPath)/\(itemPath)"
                        let dict = NSDictionary(contentsOfFile: fullPath)
                        if let mcmmetdata = dict?["MCMMetadataIdentifier"] as? NSString,
                           mcmmetdata.lowercased == appName.lowercased() {
                            return folderPath
                        }
                    }
                }
            }
        }
        return nil
    }
    
    final class func refreshiCloudPicture(_ completion: @escaping (UIImage) -> Void) -> UIImage? {
        #if targetEnvironment(simulator) || TARGET_SANDBOX || targetEnvironment(macCatalyst)
        return nil
        #endif
        let scale = Int(UIScreen.main.scale)
        let filename = scale == 1 ? "AppleAccountIcon": "AppleAccountIcon@\(scale)x"
        let toPath = EvanderNetworking.shared.cacheDirectory.appendingPathComponent(filename).appendingPathExtension("png")
        
        func image() -> UIImage? {
            if let data = try? Data(contentsOf: toPath),
               let accountImage = UIImage(data: data) {
                return accountImage
            }
            return nil
        }
        
        if Thread.isMainThread {
            DispatchQueue.global(qos: .utility).async {
                _ = refreshiCloudPicture(completion)
            }
            return image()
        }
        
        let cached = image()
        if let path = Self.findDataFolder(appName: "com.apple.Preferences") {
            let url = URL(fileURLWithPath: path)
            let iconPath = url.appendingPathComponent("Library")
                .appendingPathComponent("Caches")
                .appendingPathComponent("com.apple.Preferences")
                .appendingPathComponent(filename)
                .appendingPathExtension("png")
            spawn(command: CommandPath.cp, args: [CommandPath.cp, "-f", "\(iconPath.path)", "\(toPath.path)"])
            if let image = image() {
                if cached != image {
                    completion(image)
                }
                return nil
            }
        }
        
        let iconPath = URL(fileURLWithPath: "/var/mobile/Library/Caches/com.apple.Preferences/")
            .appendingPathComponent(filename)
            .appendingPathExtension("png")
        spawn(command: CommandPath.cp, args: [CommandPath.cp, "-f", "\(iconPath.path)", "\(toPath.path)"])
        if let image = image(),
           cached != image {
            completion(image)
        }
        
        return nil
    }
}
