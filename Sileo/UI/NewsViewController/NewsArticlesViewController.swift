//
//  NewsArticlesViewController.swift
//  Sileo
//
//  Created by Skitty on 2/23/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class NewsArticlesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIViewControllerPreviewingDelegate {
    @IBOutlet private var collectionView: UICollectionView!

    private var isLoading: Bool = false
    private var presentNextURLCommittedModally: Bool = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    convenience init() {
        self.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib(nibName: "NewsArticleCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: "NewsArticleCollectionViewCell")
        self.registerForPreviewing(with: self, sourceView: collectionView)
    }
    
    override func didMove(toParent: UIViewController?) {
        super.didMove(toParent: parent)

        // Reload in case unread states updated.
        if parent != nil {
            collectionView.reloadData()
        }
    }
}

extension NewsArticlesViewController { // UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        NewsResolver.shared.articles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NewsArticleCollectionViewCell",
                                                      for: indexPath) as? NewsArticleCollectionViewCell

        if cell != nil {
            cell?.article = NewsResolver.shared.articles[indexPath.item]
        }
        
        return cell ?? UICollectionViewCell()
    }
}

extension NewsArticlesViewController { // UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        var presentModally = false
        let viewController = URLManager.viewController(url: NewsResolver.shared.articles[indexPath.row].url,
                                                       isExternalOpen: false,
                                                       presentModally: &presentModally) ?? UIViewController()
        if presentModally {
            self.present(viewController, animated: true)
        } else {
            self.navigationController?.pushViewController(viewController, animated: true)
        }
        collectionView.reloadItems(at: [indexPath])
    }
}

extension NewsArticlesViewController { // 3D Touch
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let indexPath = collectionView.indexPathForItem(at: location) ?? IndexPath()
        var presentModally = false
        let viewController = URLManager.viewController(url: NewsResolver.shared.articles[indexPath.row].url, isExternalOpen: false, presentModally: &presentModally)
        presentNextURLCommittedModally = presentModally
        collectionView.reloadItems(at: [indexPath])
        return viewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if presentNextURLCommittedModally {
            self.navigationController?.present(viewControllerToCommit, animated: true)
        } else {
            self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
        }
    }
}

@available (iOS 13, *)
extension NewsArticlesViewController {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        var presentModally = false
        let viewController = URLManager.viewController(url: NewsResolver.shared.articles[indexPath.row].url, isExternalOpen: false, presentModally: &presentModally)
        presentNextURLCommittedModally = presentModally
        collectionView.reloadItems(at: [indexPath])
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            viewController
        }, actionProvider: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        if let controller = animator.previewViewController {
            animator.addAnimations {
                if self.presentNextURLCommittedModally {
                    self.navigationController?.present(controller, animated: true)
                } else {
                    self.navigationController?.pushViewController(controller, animated: true)
                }
            }
        }
    }
}
