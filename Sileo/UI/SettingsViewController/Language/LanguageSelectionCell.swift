//
//  LanguageSelectionCell.swift
//  Sileo
//
//  Created by Andromeda on 03/08/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

class LanguageSelectionCell: SettingsSwitchTableViewCell {
    
    public weak var delegate: LanguageSelectionCellProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.amyPogLabel.text = String(localizationKey: "Use_System_Language")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func didChange(sender: UISwitch!) {
        delegate?.didChange(state: sender.isOn)
    }

}

protocol LanguageSelectionCellProtocol: AnyObject {
    func didChange(state: Bool)
}
