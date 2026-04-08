//
//  GlobalSearchUserBarView.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 07.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine
import SceytChat

// MARK: - GlobalSearchUserBarCell

open class GlobalSearchUserBarCell: CollectionViewCell {

    open lazy var avatarView = ImageView()
        .withoutAutoresizingMask

    open lazy var titleLabel: UILabel = {
        let label = UILabel().withoutAutoresizingMask
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    open var imageTask: Cancellable?

    open var userData: ChatUser! {
        didSet {
            titleLabel.text = appearance.titleFormatter.format(userData)
            imageTask = appearance.avatarRenderer.render(
                userData,
                with: appearance.avatarAppearance,
                into: avatarView
            )
        }
    }

    override open func setup() {
        super.setup()
        avatarView.clipsToBounds = true
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)

        avatarView.pin(to: contentView, anchors: [
            .leading(Layouts.horizontalPadding),
            .top(Layouts.verticalPadding),
            .bottom(-Layouts.verticalPadding)
        ])
        avatarView.resize(anchors: [
            .height(Layouts.avatarSize),
            .width(Layouts.avatarSize)
        ])
        titleLabel.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: Layouts.avatarToLabelSpacing)
        titleLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -Layouts.trailingPadding)
        titleLabel.centerYAnchor.pin(to: contentView.centerYAnchor)
    }

    override open func setupAppearance() {
        super.setupAppearance()
        contentView.backgroundColor = appearance.backgroundColor
        contentView.layer.cornerRadius = Layouts.cornerRadius
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = appearance.borderColor.cgColor
        contentView.clipsToBounds = true
        backgroundColor = .clear
        avatarView.layer.cornerRadius = Layouts.avatarSize / 2
        avatarView.clipsToBounds = true
        titleLabel.font = appearance.titleLabelAppearance.font
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }
}

public extension GlobalSearchUserBarCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 28
        public static var cornerRadius: CGFloat = 22
        public static var horizontalPadding: CGFloat = 8
        public static var verticalPadding: CGFloat = 8
        public static var avatarToLabelSpacing: CGFloat = 8
        public static var trailingPadding: CGFloat = 12
    }
}

// MARK: - GlobalSearchUserBarView

open class GlobalSearchUserBarView: View, UICollectionViewDataSource, UICollectionViewDelegate {

    open lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return layout
    }()

    open lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        .withoutAutoresizingMask

    open lazy var separatorLine = UIView()
        .withoutAutoresizingMask

    open lazy var viewModel: GlobalSearchUserBarViewModel = Components.globalSearchUserBarViewModel.init()

    public var onSelect: ((ChatUser) -> Void)?

    // MARK: - Lifecycle

    override open func setup() {
        super.setup()
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(Components.globalSearchUserBarCell.self)
    }

    override open func setupLayout() {
        super.setupLayout()
        addSubview(separatorLine)
        addSubview(collectionView)

        separatorLine.pin(to: self, anchors: [.top(), .leading(), .trailing()])
        separatorLine.heightAnchor.pin(constant: 1)
        collectionView.topAnchor.pin(to: separatorLine.bottomAnchor)
        collectionView.pin(to: self, anchors: [.leading(), .trailing(), .bottom()])
    }

    override open func setupAppearance() {
        super.setupAppearance()
//        backgroundColor = appearance.backgroundColor
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        separatorLine.backgroundColor = appearance.separatorColor
    }

    override open func setupDone() {
        super.setupDone()
        viewModel.startDatabaseObserver()
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &subscriptions)
    }

    // MARK: - UICollectionViewDataSource

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.users.count
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.globalSearchUserBarCell.self)
        cell.parentAppearance = appearance.cellAppearance
        cell.userData = viewModel.users[indexPath.item]
        return cell
    }

    // MARK: - UICollectionViewDelegate

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let user = viewModel.users[indexPath.item]
        onSelect?(user)
    }
}

public extension GlobalSearchUserBarView {
    enum Layouts {
        /// Total height: 1 (separator) + 8 (top inset) + 44 (cell) + 8 (bottom inset) = 61
        public static var height: CGFloat = 61
    }
}
