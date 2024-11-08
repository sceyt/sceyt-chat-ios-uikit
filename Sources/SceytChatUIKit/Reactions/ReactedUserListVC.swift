//
//  ReactedUserListViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ReactedUserListViewController: ViewController,
                           UICollectionViewDataSource,
                           UICollectionViewDelegateFlowLayout {

    open var onEvent: ((Event) -> Void)?

    open var viewModel: UserReactionViewModel!
    
    open var appearance: ReactionsInfoViewController.Appearance = ReactionsInfoViewController.appearance
    
    open lazy var collectionViewLayout = UICollectionViewFlowLayout()

    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        .withoutAutoresizingMask

    open override func viewDidLoad() {
        super.viewDidLoad()
    }

    open override func setup() {
        super.setup()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(Components.reactedUserReactionCell)
        collectionView.alwaysBounceVertical = true
    }

    open override func setupDone() {
        super.setupDone()
        viewModel.startDatabaseObserver()
        viewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        viewModel.loadReactions()
    }

    open override func setupAppearance() {
        super.setupAppearance()
        collectionView.backgroundColor = appearance.backgroundColor
    }

    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(collectionView)
        collectionView.pin(to: view, anchors: [.leading(), .top(), .trailing(), .bottom()])
    }

    // MARK: ViewModel Events
    
    open func onEvent(_ event: UserReactionViewModel.Event) {
        switch event {
        case .reloadData:
            collectionView.reloadData()
        case .insert(let indexPaths):
            if view.superview == nil || collectionView.visibleCells.isEmpty {
                collectionView.reloadData()
            } else {
                collectionView.performBatchUpdates {
                    collectionView.insertItems(at: indexPaths)
                }
            }
        }
    }

    // MARK: UICollectionViewDataSource
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfItems(in: section)
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.reactedUserReactionCell)
        cell.parentAppearance = appearance.reactedUserCellAppearance
        if let reactionModel = viewModel.cellModel(at: indexPath) {
            cell.data = reactionModel
        }
        if indexPath.item > viewModel.numberOfItems(in: indexPath.section) - 3 {
            viewModel.loadReactions()
        }
        return cell
    }

    // MARK: UICollectionViewDelegate
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width, height: 56)
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let reaction = viewModel.reaction(at: indexPath) {
            onEvent?(.onSelect(reaction))
        }
    }

}
public extension ReactedUserListViewController {

    enum Event {
        case onSelect(ChatMessage.Reaction)
    }

}
