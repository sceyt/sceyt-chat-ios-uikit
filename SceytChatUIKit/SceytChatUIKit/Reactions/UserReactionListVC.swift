//
//  UserReactionListVC.swift
//  SceytChatUIKit
//

import UIKit

open class UserReactionListVC: ViewController,
                           UICollectionViewDataSource,
                           UICollectionViewDelegateFlowLayout {

    open var onEvent: ((Event) -> Void)?

    open var viewModel: UserReactionViewModel!
    
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
        collectionView.register(Components.userReactionCell)
        collectionView.alwaysBounceVertical = true
    }

    open override func setupAppearance() {
        super.setupAppearance()
        collectionView.backgroundColor = Colors.background
    }

    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(collectionView)
        collectionView.pin(to: view, anchors: [.leading(), .top(), .trailing(), .bottom()])
    }

    // MARK: UICollectionViewDataSource
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfRows()
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.userReactionCell)
        cell.data = viewModel.user(at: indexPath)
        cell.reactionLabel.text = viewModel.reactionKey(at: indexPath)
        return cell
    }

    // MARK: UICollectionViewDelegate
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width, height: 56)
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let reaction = viewModel.reaction(at: indexPath)
        onEvent?(.onSelect(reaction))
    }

}
public extension UserReactionListVC {

    enum Event {
        case onSelect(ChatMessage.Reaction)
    }

}
