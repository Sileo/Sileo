//
//  FileNode.swift
//  Sileo
//
//  Created by CoolStar on 8/4/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import LNZTreeView

class FileNode: TreeNodeProtocol {
    var identifier: String
    var path: String

    var isExpandable: Bool {
        children != nil
    }

    var children: [FileNode]?

    init(withIdentifier identifier: String, andChildren children: [FileNode]? = nil, path: String) {
        self.identifier = identifier
        self.children = children
        self.path = path
    }
}
