//
//  InstalledContentsViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/4/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import LNZTreeView

class InstalledContentsViewController: UIViewController {
   public var packageId: String = ""
    
    private var treeView: LNZTreeView?
    private var filesList: [String] = []
    
    fileprivate var rootNode = FileNode(withIdentifier: "/", path: "/")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = String(localizationKey: "Package_Installed_Files_Page")
        
        self.navigationItem.largeTitleDisplayMode = .never
        
        do {
            #if targetEnvironment(simulator) || TARGET_SANDBOX
            let dpkgURL = Bundle.main.url(forResource: "dpkg", withExtension: "list") ?? URL(fileURLWithPath: "/")
            #else
            let dpkgURL = CommandPath.dpkgDir.appendingPathComponent("info").appendingPathComponent("\(self.packageId).list")
            #endif
            filesList = try String(contentsOf: dpkgURL).components(separatedBy: CharacterSet(charactersIn: "\n"))
        } catch {
            
        }
        
        rootNode = FileNode(withIdentifier: "/", andChildren: children(path: "/"), path: "/")
        
        let treeView = LNZTreeView(frame: self.view.bounds)
        treeView.dataSource = self
        treeView.delegate = self
        treeView.backgroundColor = .clear
        treeView.register(InstalledContentsTableViewCell.self, forCellReuseIdentifier: "cell")
        treeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(treeView)
        treeView.subviews[0].backgroundColor = .clear
        
        self.view.tintColor = UINavigationBar.appearance().tintColor

        self.treeView = treeView
        treeView.expand(node: rootNode, inSection: 0)
        
        let copyPath = UIMenuItem(title: String(localizationKey: "Copy_Path"), action: #selector(InstalledContentsTableViewCell.copyPath(_:)))
        let url = URL(string: "filza:///")!
        if UIApplication.shared.canOpenURL(url) {
            let openInFilza = UIMenuItem(title: String(localizationKey: "Open_In_Filza"), action: #selector(InstalledContentsTableViewCell.openInFilza(_:)))
            UIMenuController.shared.menuItems = [copyPath, openInFilza]
        } else {
            UIMenuController.shared.menuItems = [copyPath]
        }
        
    }

    private func children(path: String) -> [FileNode]? {
        var items: [FileNode] = []
        for file in filesList {
            if file.hasPrefix(path == "/" ? path : path + "/") {
                var count = path.count
                if path != "/" {
                    count += 1
                }
                if count > file.count {
                    continue
                }
                let index = file.index(file.startIndex, offsetBy: count)
                let pathRemaining = file[index...]
                if !pathRemaining.contains("/") && !pathRemaining.isEmpty && pathRemaining != "." {
                    items.append(FileNode(withIdentifier: file, andChildren: children(path: file), path: file))
                }
            }
        }
        if items.isEmpty {
            return nil
        }
        return items
    }
}

extension InstalledContentsViewController: LNZTreeViewDataSource {
    func numberOfSections(in treeView: LNZTreeView) -> Int {
        1
    }

    func treeView(_ treeView: LNZTreeView, numberOfRowsInSection section: Int, forParentNode parentNode: TreeNodeProtocol?) -> Int {
        guard let parent = parentNode as? FileNode else {
            return 1
        }
        return parent.children?.count ?? 1
    }

    func treeView(_ treeView: LNZTreeView, nodeForRowAt indexPath: IndexPath, forParentNode parentNode: TreeNodeProtocol?) -> TreeNodeProtocol {
        guard let parent = parentNode as? FileNode,
            let children = parent.children else {
            return rootNode
        }
        return children[indexPath.row]
    }

    func treeView(_ treeView: LNZTreeView, cellForRowAt indexPath: IndexPath, forParentNode parentNode: TreeNodeProtocol?, isExpanded: Bool) -> UITableViewCell {
        let node = (self.treeView(treeView, nodeForRowAt: indexPath, forParentNode: parentNode) as? FileNode) ?? rootNode
        // swiftlint:disable force_cast
        let cell = treeView.dequeueReusableCell(withIdentifier: "cell", for: node, inSection: indexPath.section) as! InstalledContentsTableViewCell
        cell.node = node
        if node.isExpandable {
            if isExpanded {
                cell.imageView?.image = UIImage(named: "index_folder_indicator_open")?.withRenderingMode(.alwaysTemplate)
            } else {
                cell.imageView?.image = UIImage(named: "index_folder_indicator")?.withRenderingMode(.alwaysTemplate)
            }
        } else {
            cell.imageView?.image = nil
        }
        cell.imageView?.tintColor = self.view.tintColor
        cell.selectionStyle = .gray
        cell.selectedBackgroundView = SileoSelectionView()

        let text = URL(fileURLWithPath: node.identifier).lastPathComponent
        if node.isExpandable && node.identifier != "/" {
            cell.textLabel?.text = text + "/"
        } else {
            cell.textLabel?.text = text
        }

        return cell
    }
}

extension InstalledContentsViewController: LNZTreeViewDelegate {
    func treeView(_ treeView: LNZTreeView, heightForNodeAt indexPath: IndexPath, forParentNode parentNode: TreeNodeProtocol?) -> CGFloat {
        43
    }
    
    func treeView(_ treeView: LNZTreeView, didSelectNodeAt indexPath: IndexPath, forParentNode parentNode: TreeNodeProtocol?) {
        treeView.deselectRow(at: indexPath, animated: true)
    }

    func treeView(_ treeView: LNZTreeView, shouldShowMenuForRowAt indexPath: IndexPath, forParentNode parentNode: TreeNodeProtocol?) -> Bool {
        let node = (self.treeView(treeView, nodeForRowAt: indexPath, forParentNode: parentNode) as? FileNode) ?? rootNode
        
        return !node.isExpandable
    }
    
    func treeView(_ treeView: LNZTreeView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?, forParentNode parentNode: TreeNodeProtocol?) -> Bool {
        action == #selector(InstalledContentsTableViewCell.copyPath(_:)) || action == #selector(InstalledContentsTableViewCell.openInFilza(_:))
    }
    
}
