//
//  SearchHistoryCollectionViewCell.swift
//  Sileo
//
//  Created by Serena on 23/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.

import Foundation
import SwipeCellKit

class SearchHistoryCollectionViewCell: SwipeCollectionViewCell {
    let label = {
        let label = UILabel()
        label.textColor = .tintColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        
        if #available(iOS 13, *) {
            let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal))
            imageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 5),
                imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                
                label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 5),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 5),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        self.delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        label.text = nil
    }
}

extension SearchHistoryCollectionViewCell: SwipeCollectionViewCellDelegate {
    func collectionView(_ collectionView: UICollectionView, editActionsForItemAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
        let deleteAction = SwipeAction(style: .destructive, title: String(localizationKey: "Remove")) {  _, _ in
            searchHistory.remove(at: indexPath.row)
            
            if searchHistory.isEmpty {
                collectionView.performBatchUpdates({
                    collectionView.deleteSections(.init(integer: 0))
                }, completion: nil)
            }
            else {
                collectionView.deleteItems(at: [indexPath])
            }
        }
        
        return [deleteAction]
    }
    
    func collectionView(_ collectionView: UICollectionView, editActionsOptionsForItemAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        var options = SwipeOptions()
        options.expansionStyle = .selection
        return options
    }
}
