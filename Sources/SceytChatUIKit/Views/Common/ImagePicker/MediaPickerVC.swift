//
//  MediaPickerVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import PhotosUI
import UIKit

open class MediaPickerVC: ViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegate
{
    private let imageManager = PHCachingImageManager()
    public static let pageSize = 100
    
    public var onSelected: (([PHAsset], MediaPickerVC) -> Bool)?
    private var selectedIdentifiers = Set<String>()
    private var preSelectedIdentifiers = Set<String>()
    private var selectedIndexPaths = [IndexPath]()
    private var maximumAttachmentsAllowed = SceytChatUIKit.shared.config.maximumAttachmentsAllowed
    
    open lazy var collectionView = Components.mediaPickerCollectionView
        .init()
        .withoutAutoresizingMask
 
    open lazy var footerView = Components.mediaPickerFooterView.init()
        .withoutAutoresizingMask
    
    open var collectionViewLayout: MediaPickerCollectionViewLayout? {
        collectionView.collectionViewLayout as? MediaPickerCollectionViewLayout
    }

    public var allowsMultipleSelection = true {
        didSet {
            collectionView.allowsMultipleSelection = allowsMultipleSelection
        }
    }
    
    public var allowedMediaTypes: Set<PHAssetMediaType>? {
        didSet {
            updateFetchOptionPredicate()
        }
    }
    
    public var allowedMediaSubtypes: PHAssetMediaSubtype? {
        didSet {
            updateFetchOptionPredicate()
        }
    }
    
    open lazy var fetchOptions: PHFetchOptions = {
        $0.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return $0
    }(PHFetchOptions())
    
    public private(set) var assets: PHFetchResult<PHAsset> = PHFetchResult()
    
    public var fetchLimit: Int {
        get {
            return fetchOptions.fetchLimit
        }
        set {
            fetchOptions.fetchLimit = newValue
        }
    }
    
    public required init(selectedAssetIdentifiers: Set<String>? = nil, maximumAttachmentsAllowed: Int) {
        super.init(nibName: nil, bundle: nil)
        if let selectedAssetIdentifiers {
            self.maximumAttachmentsAllowed = maximumAttachmentsAllowed
            preSelectedIdentifiers = selectedAssetIdentifiers
            selectedIdentifiers = selectedAssetIdentifiers
            footerView.selectedCount = selectedAssetIdentifiers.count
        }
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override open func setup() {
        super.setup()
        
        title = L10n.ImagePicker.title
        
        collectionView.allowsMultipleSelection = allowsMultipleSelection
        collectionView.backgroundColor = .white
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionViewLayout?.minimumInteritemSpacing = 2
        collectionViewLayout?.minimumLineSpacing = 2
        collectionView.register(Components.mediaPickerCell.self)
        
        navigationItem.leftBarButtonItem =
            UIBarButtonItem(
                title: L10n.Alert.Button.cancel,
                style: .done,
                target: self,
                action: #selector(cancelAction(_:))
            )
        footerView.attachButton.addTarget(self, action: #selector(attachButtonAction(_:)), for: .touchUpInside)
        
        resetCachedAssets()
        PHPhotoLibrary.shared().register(self)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        collectionView.backgroundColor = .clear
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(collectionView)
        view.addSubview(footerView)
        
        collectionView.pin(to: view, anchors: [.leading, .trailing])
        collectionView.topAnchor.pin(to: view.safeAreaLayoutGuide.topAnchor)
        collectionView.bottomAnchor.pin(to: footerView.topAnchor)
        footerView.pin(to: view, anchors: [.leading, .trailing])
        footerView.bottomAnchor.pin(to: view.safeAreaLayoutGuide.bottomAnchor)
    }
    
    override open func setupDone() {
        super.setupDone()
        
        requestPhotoAccessIfNeeded(photoAuthorizationStatus)
        updateManageAccessView()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewWillLayoutSubviews()
        collectionViewLayout?.itemSize = itemSize()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func updateUI(for status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            fetchAssets()
        case .limited:
            fetchAssets()
        case .restricted, .denied:
            collectionView.delegate = nil
            collectionView.dataSource = nil
        case .notDetermined:
            break

        @unknown default:
            break
        }
    }

    @objc
    open func cancelAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @objc
    open func attachButtonAction(_ sender: AttachButton) {
        hud.isLoading = true
        var selectedAssets: [PHAsset] = []
        for indexPath in selectedIndexPaths {
            guard indexPath.item < assets.count else { continue }
            selectedAssets += [assets.object(at: indexPath.item)]
        }
        let shouldDismiss = onSelected?(selectedAssets, self)
        if shouldDismiss != false {
            dismiss(animated: true)
        }
    }
    
    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        hud.isLoading = false
        super.dismiss(animated: flag, completion: completion)
    }
    
    // MARK: Asset Caching
    
    fileprivate func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }
    
    fileprivate func updateCachedAssets() {
        // Update only if the view is visible.
        guard isViewLoaded && view.window != nil else { return }
        
        // The preheat window is twice the height of the visible rect.
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        
        // Compute the assets to start caching and to stop caching.
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in assets.object(at: indexPath.item) }
        let removedAssets = removedRects
            .flatMap { rect in collectionView.indexPathsForElements(in: rect) }
            .map { indexPath in assets.object(at: indexPath.item) }
        
        // Update the assets the PHCachingImageManager is caching.
        imageManager.startCachingImages(for: addedAssets,
                                        targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        
        // Store the preheat rect to compare against in the future.
        previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
    
    // MARK: CollectionViewDataSource

    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        fetchNextPageIfNeeded(indexPath: indexPath)
        let cell = collectionView.dequeueReusableCell(
            for: indexPath,
            cellType: Components.mediaPickerCell.self
        )
        cell.data = (imageManager, assets.object(at: indexPath.item), thumbnailSize)
        return cell
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        assets.count
    }
    
    open func itemSize() -> CGSize {
        let space = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? 0
        let sectionInset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let width = collectionView.bounds.width - sectionInset.left - sectionInset.right
        let height = collectionView.bounds.height - sectionInset.top - sectionInset.bottom
        let perLineCount: CGFloat = height > width ? 3 : 5
        let size = Int((width - space * (perLineCount - 1)) / perLineCount)
        return .init(width: size, height: size)
    }
    
    var thumbnailSize: CGSize {
        let itemSize = itemSize()
        return .init(width: itemSize.width * SceytChatUIKit.shared.config.displayScale, height: itemSize.height * SceytChatUIKit.shared.config.displayScale)
    }
    
    fileprivate var previousPreheatRect = CGRect.zero
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        guard let cell = collectionView.cell(for: indexPath, cellType: Components.mediaPickerCell.self),
              cell.imageView.image != nil
        else { return false }
        guard maximumAttachmentsAllowed > 0
        else { return true }
        guard maximumAttachmentsAllowed > selectedIdentifiers.count
        else {
            showAlert(message: L10n.Error.maxValueItems(maximumAttachmentsAllowed))
            return false
        }
        if indexPath.item < assets.count,
           preSelectedIdentifiers.contains(assets[indexPath.item].localIdentifier)
        {
            return false
        }
        
        return true
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            selectedIdentifiers.insert(assets[indexPath.item].localIdentifier)
            selectedIndexPaths.append(indexPath)
        }
        footerView.selectedCount = selectedIdentifiers.count
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        didDeselectItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            selectedIdentifiers.remove(assets[indexPath.item].localIdentifier)
            selectedIndexPaths.removeAll(where: { $0 == indexPath })
        }
        footerView.selectedCount = selectedIdentifiers.count
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            let isSelected = selectedIdentifiers.contains(assets[indexPath.item].localIdentifier)
            if cell.isSelected != isSelected {
                cell.isSelected = isSelected
            }
        } else if cell.isSelected {
            cell.isSelected = false
        }
    }
    
    @objc open func onTapManageAccess(_ sender: UIBarButtonItem) {
        if #available(iOS 14, *) {
            var actions = [SheetAction]()
            actions.append(.init(title: L10n.ImagePicker.ManageAccess.more, style: .default, handler: {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            }))
            actions.append(.init(title: L10n.ImagePicker.ManageAccess.change, style: .default, handler: {
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                UIApplication.shared.open(settingsUrl)
            }))
            showBottomSheet(actions: actions, withCancel: true)
        }
    }
}

private extension MediaPickerVC {
    var photoAuthorizationStatus: PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            return PHPhotoLibrary.authorizationStatus()
        }
    }

    func requestPhotoAccessIfNeeded(_ status: PHAuthorizationStatus) {
        guard status != .authorized else { return updateUI(for: status) }
        PHPhotoLibrary.requestAuthorization { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.assets = PHAsset.fetchAssets(with: self.fetchOptions)
                self.collectionView.reloadData()
                self.updateManageAccessView()
            }
        }
    }
    
    func updateManageAccessView() {
        if #available(iOS 14, *) {
            if photoAuthorizationStatus == .limited {
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: L10n.ImagePicker.ManageAccess.action,
                    style: .done,
                    target: self,
                    action: #selector(onTapManageAccess)
                )
            } else {
                navigationItem.rightBarButtonItem = nil
            }
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    func fetchAssets() {
        let selectedAssets = collectionView.indexPathsForSelectedItems?.map {
            assets.object(at: $0.item)
        } ?? []
        
        fetchOptions.fetchLimit = Self.pageSize
        assets = PHAsset.fetchAssets(with: fetchOptions)
        collectionView.reloadData()
        
        selectedAssets.forEach {
            collectionView.selectItem(at: .init(item: assets.index(of: $0), section: 0), animated: false, scrollPosition: [])
        }
        
        resetCachedAssets()
    }
    
    func updateFetchOptionPredicate() {
        var predicates: [NSPredicate] = []
        if let allowedMediaTypes = allowedMediaTypes {
            let mediaTypePredicates = allowedMediaTypes.map { NSPredicate(format: "mediaType = %d", $0.rawValue) }
            predicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates: mediaTypePredicates)
            )
        }
        
        if let allowedMediaSubtypes = allowedMediaSubtypes {
            predicates.append(
                NSPredicate(format: "(mediaSubtype & %d) == 0", allowedMediaSubtypes.rawValue)
            )
        }
        
        if predicates.count > 0 {
            fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else {
            fetchOptions.predicate = nil
        }
        fetchAssets()
    }
    
    func fetchNextPageIfNeeded(indexPath: IndexPath) {
        guard indexPath.item == fetchLimit - 1
        else { return }
        DispatchQueue.main.async {
            let oldFetchLimit = self.fetchLimit
            self.fetchLimit += Self.pageSize
            self.assets = PHAsset.fetchAssets(with: self.fetchOptions)
            
            let indexPaths = (oldFetchLimit ..< self.assets.count).map {
                IndexPath(item: $0, section: 0)
            }
            self.collectionView.insertItems(at: indexPaths)
        }
    }
}

extension MediaPickerVC: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.fetchAssets()
        }
    }
}

private extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect) ?? []
        return allLayoutAttributes.map { $0.indexPath }
    }
}
