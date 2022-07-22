//
//  NewsPlaceholderCollectionViewCell.swift
//  Sileo
//
//  Created by CoolStar on 9/2/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

class NewsPlaceholderCollectionViewCell: UICollectionViewCell {

    @IBOutlet var headlineLabel: SileoLabelView?
    @IBOutlet var subtitleLabel: SileoLabelView?
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        headlineLabel?.text = String(localizationKey: "No_New_Packages")
        subtitleLabel?.text = String(localizationKey: "News_Check_Later")
    }
}
