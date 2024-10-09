//
//  MenuController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol MenuControllerDataSource: AnyObject {
    
    var menuItems: [MenuItem] { get }
}

open class MenuController: ViewController,
                           UICollectionViewDataSource,
                           UICollectionViewDelegate,
                           UICollectionViewDelegateFlowLayout {
    
    open lazy var collectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = .zero
        flowLayout.minimumLineSpacing = .zero
        return UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
            .withoutAutoresizingMask
    }()
    
    private var collectionHeightConstraint: NSLayoutConstraint?

    weak var dataSource: MenuControllerDataSource? {
        didSet {
            reloadData()
        }
    }
    
    open func reloadData() {
        collectionView.reloadData()
        collectionHeightConstraint?.constant = CGFloat(dataSource?.menuItems.count ?? 0) * Layouts.cellHeight + Layouts.verticalPadding * 2
    }
    
    open var cellData: [MenuItem] {
        dataSource?.menuItems ?? []
    }
    
    open override func setup() {
        super.setup()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(Components.menuCell.self)
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
    }

    override open func setupLayout() {
        super.setupLayout()
        view.addSubview(collectionView)
        collectionHeightConstraint = collectionView.heightAnchor.pin(constant: 0)
        collectionView.pin(to: view, anchors: [.leading, .trailing, .top, .bottom])
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        collectionView.backgroundColor = .clear
        view.backgroundColor = appearance.backgroundColor
    }
    
    open func focusOption(at point: CGPoint?) {
        guard let point else {
            collectionView.visibleCells
                .filter { $0.isHighlighted }
                .forEach { $0.isHighlighted = false }
            return
        }
        if let indexPath = collectionView.indexPathForItem(at: point),
           let cell = collectionView.cellForItem(at: indexPath),
           !cell.isHighlighted {
            cell.isHighlighted = true
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            collectionView.visibleCells
                .filter { $0 != cell }
                .forEach { $0.isHighlighted = false }
        }
    }
    
    open func selectOption(at point: CGPoint) {
        if let indexPath = collectionView.indexPathForItem(at: point) {
            selectItem(at: indexPath)
        }
    }

    open func selectHighlightedIfNeeded() {
        if let highlighted = collectionView.visibleCells
            .filter({ $0.isHighlighted }).first,
           let indexPath = collectionView.indexPath(for: highlighted) {
            selectItem(at: indexPath)
        }
    }

    //MARK: UICollectionViewDataSource
    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        cellData.count
    }

    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: Components.menuCell.self)
        cell.item = cellData[indexPath.item]
        cell.separatorView.isHidden = indexPath.item == cellData.indices.last
        cell.contentInsets.top = collectionView.isFirst(indexPath) ? Layouts.verticalPadding : 0
        cell.contentInsets.bottom = collectionView.isLast(indexPath) ? Layouts.verticalPadding : 0
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    open func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath) {
        selectItem(at: indexPath)
    }

    open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let cell = collectionView.cellForItem(at: indexPath) {
            cell.isHighlighted = true
        }
        return true
    }

    // MARK: UICollectionViewDelegateFlowLayout
    open func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        var height = Layouts.cellHeight
        if collectionView.isFirst(indexPath) {
            height += Layouts.verticalPadding
        }
        if collectionView.isLast(indexPath) {
            height += Layouts.verticalPadding
        }
        return .init(width: floor(collectionView.frame.width), height: height)
    }
}

private extension MenuController {
    
    func selectItem(at indexPath: IndexPath) {
        let item = cellData[indexPath.row]
        if item.dismissOnAction {
            dismiss(animated: true) {
                item.action(item)
            }
        } else {
            item.action(item)
        }
        
    }
}

public extension MenuController {
    enum Layouts {
        static var cellHeight: CGFloat = 40
        static var verticalPadding: CGFloat = 4
    }
}


public struct MenuItem {
    public let title: String
    public let attributedTitle: NSAttributedString?
    public let image: UIImage?
    public let imageRenderingMode: UIImage.RenderingMode
    public var destructive: Bool
    public var dismissOnAction: Bool
    public var action: (Self) -> Void
    
    public init(
        title: String,
        image: UIImage? = nil,
        destructive: Bool = false,
        imageRenderingMode: UIImage.RenderingMode = .alwaysTemplate,
        dismissOnAction: Bool = true,
        action: @escaping (Self) -> Void
    ) {
        self.title = title
        self.attributedTitle = nil
        self.image = image
        self.destructive = destructive
        self.imageRenderingMode = imageRenderingMode
        self.dismissOnAction = dismissOnAction
        self.action = action
    }
    
    public init(
        attributedTitle: NSAttributedString,
        image: UIImage? = nil,
        destructive: Bool = false,
        imageRenderingMode: UIImage.RenderingMode = .alwaysTemplate,
        dismissOnAction: Bool = true,
        action: @escaping (Self) -> Void
    ) {
        self.title = attributedTitle.string
        self.attributedTitle = attributedTitle
        self.image = image
        self.destructive = destructive
        self.imageRenderingMode = imageRenderingMode
        self.dismissOnAction = dismissOnAction
        self.action = action
    }
}

private extension UICollectionView {
    func isFirst(_ indexPath: IndexPath) -> Bool {
        indexPath.item == 0
    }
    
    func isLast(_ indexPath: IndexPath) -> Bool {
        indexPath.item == numberOfItems(inSection: indexPath.section) - 1
    }
}
