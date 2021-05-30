//
//  SourcesTableViewFooter.swift
//  Sileo
//
//  Created by Andromeda on 30/05/2021.
//  Copyright © 2021 Amy. All rights reserved.
//

import UIKit

class SourcesTableViewFooter: UITableViewHeaderFooterView {
    private let label = UILabel(frame: CGRect(x: 15, y: 5.5, width: 320, height: 20))
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        self.backgroundView = UIView()
        
        label.autoresizingMask = .flexibleWidth
        label.textColor = UIColor(red: 145.0/255.0, green: 155.0/255.0, blue: 162.0/255.0, alpha: 1)
        label.font = UIFont.systemFont(ofSize: 12)
        self.addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setCount(_ count: Int) {
        let key = count > 1 ? "Sources_Page" : "Sources_Page_Singular"
        let suffix = String(localizationKey: key).localizedLowercase
        label.text = "\(count) \(suffix)"
    }
}
