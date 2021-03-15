//
//  SourcesTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SourcesTableViewCell: BaseSubtitleTableViewCell {
    public var repo: Repo? = nil {
        didSet {
            if let repo = repo {
                self.title = repo.isLoaded ? repo.displayName : nil
                self.subtitle = repo.displayURL
                self.icon = repo.repoIcon
                self.progress = repo.totalProgress
            } else {
                self.title = String(localizationKey: "All_Packages.Title")
                self.subtitle = String(localizationKey: "All_Packages.Cell_Subtitle")
                self.icon = UIImage(named: "All Packages")
                self.progress = 0
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.accessoryView = UIImageView(image: UIImage(named: "Chevron"))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.repo = nil
    }
}
