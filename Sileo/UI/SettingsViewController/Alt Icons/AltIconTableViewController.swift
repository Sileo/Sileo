//
//  AltIconTableViewController.swift
//  Sileo
//
//  Created by Amy on 21/03/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit
import Evander

struct AltIcon {
    var displayName: String
    var author: String
    var key: String?
    var image: UIImage
}

class AltIconTableViewController: UITableViewController {
    
    public static let IconUpdate = Notification.Name("AlternateIconUpdate")
    
    public class func altImage(_ name: String) -> UIImage {
        #if targetEnvironment(macCatalyst)
        let path = Bundle.main.bundleURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("AppIcon.icns")
        #else
        let path = Bundle.main.bundleURL.appendingPathComponent(name + "@2x.png")
        #endif
        return UIImage(contentsOfFile: path.path) ?? UIImage()
    }
    
    var icons = [
        AltIcon(displayName: "Stock", author: "Dennis Bednarz", key: nil, image: altImage("AppIcon60x60")),
        AltIcon(displayName: "OG", author: "Dennis Bednarz", key: "OG", image: altImage("OG")),
        AltIcon(displayName: "Pride", author: "emiyl0", key: "Pride", image: altImage("Pride")),
        AltIcon(displayName: "Flower Sileo", author: "eugolonom", key: "FlowerSileo", image: altImage("FlowerSileo")),
        AltIcon(displayName: "Cookie", author: "eugolonom", key: "Cookie", image: altImage("Cookie")),
        AltIcon(displayName: "Dopamine", author: "eugolonom", key: "Dopamine", image: altImage("Dopamine")),
        AltIcon(displayName: "palera1n", author: "eugolonom", key: "palera1n", image: altImage("palera1n")),
        AltIcon(displayName: "Cheyote", author: "eugolonom", key: "Cheyote", image: altImage("Cheyote")),
        AltIcon(displayName: "Odyssey", author: "eugolonom", key: "Odyssey", image: altImage("Odyssey")),
        AltIcon(displayName: "Electra", author: "eugolonom", key: "Electra", image: altImage("Electra")),
        AltIcon(displayName: "Mixture", author: "Eilionoir Tunnicliff", key: "Mixture", image: altImage("Mixture")),
        AltIcon(displayName: "Midnight", author: "Eilionoir Tunnicliff", key: "Midnight", image: altImage("Midnight")),
        AltIcon(displayName: "Taurine", author: "Alpha_Stream", key: "Taurine", image: altImage("Taurine")),
        AltIcon(displayName: "Chimera", author: "Korfi", key: "Chimera", image: altImage("Chimera")),
        AltIcon(displayName: "Procursus", author: "Korfi", key: "Procursus", image: altImage("Procursus")),
        AltIcon(displayName: "Dark Magic", author: "eugolonom", key: "DarkMagic", image: altImage("DarkMagic")),
        AltIcon(displayName: "Hazel", author: "eugolonom", key: "Hazel", image: altImage("Hazel")),
        AltIcon(displayName: "Stardust", author: "eugolonom", key: "Stardust", image: altImage("Stardust")),
        AltIcon(displayName: "Sugar Free", author: "Alpha_Stream", key: "SugarFree", image: altImage("SugarFree")),
        AltIcon(displayName: "Mango Crazy", author: "Alpha_Stream", key: "MangoCrazy", image: altImage("MangoCrazy")),
        AltIcon(displayName: "Cool Breeze", author: "Alpha_Stream", key: "CoolBreeze", image: altImage("CoolBreeze")),
        AltIcon(displayName: "Blue Lemonade", author: "Alpha_Stream ", key: "BlueLemonade", image: altImage("BlueLemonade")),
        AltIcon(displayName: "Cotton Candy", author: "emiyl0", key: "CottonCandy", image: altImage("CottonCandy")),
        AltIcon(displayName: "Strawberry Sunset", author: "Korfi", key: "StrawberrySunset", image: altImage("StrawberrySunset")),
        AltIcon(displayName: "Oceanic Blue", author: "Korfi", key: "OceanicBlue", image: altImage("OceanicBlue")),
        AltIcon(displayName: "Sus", author: "emiyl0", key: "Sus", image: altImage("Sus"))
    ]
    
    @objc func updateSileoColors() {
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateSileoColors()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if Bundle.main.bundleIdentifier == "org.coolstar.SileoNightly" {
            icons.insert(AltIcon(displayName: "Nightly", author: "Alpha_Stream", key: "Nightly", image: AltIconTableViewController.altImage("Nightly")), at: 1)
        }

        navigationItem.title = String(localizationKey: "Alternate_Icon_Title")
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.rowHeight = 75
                
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        icons.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = AltIconTableViewCell()
        cell.altIcon = icons[indexPath.row]
        if UIApplication.shared.alternateIconName == cell.altIcon?.key {
            cell.accessoryType = .checkmark
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let altIcon = icons[indexPath.row]
        UIApplication.shared.setAlternateIconName(altIcon.key) { error in
            print("Failed to set icon with error \(error?.localizedDescription ?? "Unknown Error")")
        }
        NotificationCenter.default.post(name: AltIconTableViewController.IconUpdate, object: nil)
        self.tableView.reloadRows(at: self.tableView.indexPathsForVisibleRows ?? [IndexPath](), with: .none)
    }

}
