//
//  FeedRefreshViewController.swift
//  EssentialFeediOS
//
//  Created by Cửu Long Hoàng on 11/10/2022.
//

import UIKit

class FeedRefreshViewController: NSObject {
    
    private var viewModel: FeedRefreshViewModel
    
    init(viewModel: FeedRefreshViewModel) {
        self.viewModel = viewModel
    }
    
    private(set) lazy var view: UIRefreshControl = bind(UIRefreshControl())
    
    @objc func refresh() {
        viewModel.loadFeed()
    }
    
    private func bind(_ view: UIRefreshControl) -> UIRefreshControl {
        viewModel.onLoadingChanged = { [weak self] isLoading in
            if isLoading {
                self?.view.beginRefreshing()
            } else {
                self?.view.endRefreshing()
            }
        }
        view.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return view
    }
}
