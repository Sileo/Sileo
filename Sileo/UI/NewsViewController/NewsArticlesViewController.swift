//
//  NewsArticlesViewController.swift
//  Sileo
//
//  Created by Skitty on 2/23/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class NewsArticlesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIViewControllerPreviewingDelegate {
    private var articles: [NewsArticle] = []
    
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var activityIndicatorView: UIActivityIndicatorView!

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

        self.loadArticles()
    }
    
    override func didMove(toParent: UIViewController?) {
        super.didMove(toParent: parent)

        // Reload in case unread states updated.
        if parent != nil {
            collectionView.reloadData()
        }
    }
}

extension NewsArticlesViewController { // Get Data
    func loadArticles() {
        isLoading = true
        //articles = NewsArticle.instancesWhere("1 ORDER BY date desc", arguments: nil) as? [NewsArticle]
        articles = []
        if !articles.isEmpty {
            isLoading = false
        }

        URLSession.shared.dataTask(with: URL(string: "https://getsileo.app/api/new.json")!) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if error != nil || data == nil {
                    return
                }
                //var jsonError
                let options = JSONSerialization.ReadingOptions.allowFragments
                let responseData: [String: Any]? = try? JSONSerialization.jsonObject(with: data ?? Data(), options: options) as? [String: Any]
                if responseData == nil {
                    return
                }
                let articlesData: [Any]? = responseData?["articles"] as? [Any]
                if articlesData == nil {
                    return
                }

                for articleData in articlesData ?? [] {
                    // Have the article added or updated in the database.
                    if let article = NewsArticle(dict: articleData as? [String: Any] ?? [:]) {
                        self.articles.append(article)
                    }
                    //NewsArticle.articleFromDictionary(articleData as? [String : Any] ?? [:])
                }

                //self.articles = NewsArticle.instancesWhere("1 ORDER BY date desc", arguments: nil) as? [NewsArticle]
                self.activityIndicatorView?.stopAnimating()
                self.collectionView.reloadData()
            }
        }.resume()
    }
}

extension NewsArticlesViewController { // UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        articles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NewsArticleCollectionViewCell",
                                                      for: indexPath) as? NewsArticleCollectionViewCell

        if cell != nil {
            cell?.article = articles[indexPath.item]
        }
        
        return cell ?? UICollectionViewCell()
    }
}

extension NewsArticlesViewController { // UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        var presentModally = false
        let viewController = URLManager.viewController(url: articles[indexPath.row].url,
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
        let viewController = URLManager.viewController(url: articles[indexPath.row].url, isExternalOpen: false, presentModally: &presentModally)
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
        let viewController = URLManager.viewController(url: articles[indexPath.row].url, isExternalOpen: false, presentModally: &presentModally)
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
