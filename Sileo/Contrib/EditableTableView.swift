//
//  EditableTableView.swift
//  Sileo
//
//  Created by CoolStar on 8/3/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class EditableTableView: UITableView {
    override var isEditing: Bool {
        get {
            super.isEditing
        }
        // swiftlint:disable:next unused_setter_value
        set {
            super.isEditing = true
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(true, animated: animated)
    }
    
    override func accessibilityPerformEscape() -> Bool {
        false
    }
}
