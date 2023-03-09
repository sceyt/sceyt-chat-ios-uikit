//
//  PhotosPickerVC.swift
//  SceytChatUIKit
//

import UIKit
import Photos
import PhotosUI

open class PhotosPickerVC: ViewController,
                          UICollectionViewDataSource,
                          UICollectionViewDelegate {
    
    public static let pageSize = 100
    public static var maximumSelectionsAllowed: Int = 20
    
    public var onSelected: (([PHAsset]) -> Void)?
    private var selectedIdentifiers = Set<String>()
    private var preSelectedIdentifiers = Set<String>()
    private var selectedIndexPaths = [IndexPath]()
    
    open lazy var collectionView = Components.imagePickerCollectionView
        .init()
        .withoutAutoresizingMask
 
    open lazy var bottomToolbar = BottomToolbar()
        .withoutAutoresizingMask
    
    open var collectionViewLayout: PhotosPickerCollectionViewLayout? {
        collectionView.collectionViewLayout as? PhotosPickerCollectionViewLayout
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
    
    public required init(selectedAssetIdentifiers: Set<String>? = nil) {
        super.init(nibName: nil, bundle: nil)
        if let selectedAssetIdentifiers {
            preSelectedIdentifiers = selectedAssetIdentifiers
            selectedIdentifiers = selectedAssetIdentifiers
            bottomToolbar.selectedCount = selectedAssetIdentifiers.count
        }
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        title = L10n.ImagePicker.title
        collectionView.allowsMultipleSelection = allowsMultipleSelection
        collectionView.backgroundColor = .white
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionViewLayout?.minimumInteritemSpacing = 2
        collectionViewLayout?.minimumLineSpacing = 2
        collectionView.register(PhotosPickerCell.self)
        
        navigationItem.leftBarButtonItem =
        UIBarButtonItem(
            title: L10n.Alert.Button.cancel,
            style: .done,
            target: self,
            action: #selector(cancelAction(_:))
        )
        bottomToolbar.attachButton.addTarget(self, action: #selector(attachButtonAction), for: .touchUpInside)
        PHPhotoLibrary.shared().register(self)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = appearance.backgroundColor
    }
    
    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(collectionView)
        view.addSubview(bottomToolbar)
        collectionView.pin(to: view, anchors: [.leading(), .top(), .trailing()])
        collectionView.bottomAnchor.pin(to: bottomToolbar.topAnchor)
        bottomToolbar.pin(to: view, anchors: [.leading(), .bottom(), .trailing()])
    }
    
    open override func setupDone() {
        super.setupDone()
        if #available(iOS 14, *) {
            PHPhotoLibrary
                .requestAuthorization(for: .readWrite)
            { [unowned self] (status) in
                DispatchQueue.main.async { [weak self] in
                    self?.updateUI(for: status)
                }
            }
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    open override func viewDidLayoutSubviews() {
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
    private func cancelAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @objc
    private func attachButtonAction() {
        var selectedAssets: [PHAsset] = []
        for indexPath in selectedIndexPaths {
            guard indexPath.item < self.assets.count else { continue }
            selectedAssets += [assets.object(at: indexPath.item)]
        }
        onSelected?(selectedAssets)
        dismiss(animated: true)
    }
    
    //Mark CollectionViewDataSource
    open func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        fetchNextPageIfNeeded(indexPath: indexPath)
        let cell = collectionView.dequeueReusableCell(
            for: indexPath,
            cellType: PhotosPickerCell.self
        )
        let asset = assets.object(at: indexPath.item)
        cell.size = itemSize()
        cell.indexPath = indexPath
        cell.data = asset
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
    
    open func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        
        guard let cell = collectionView.cell(for: indexPath, cellType: PhotosPickerCell.self),
            cell.imageView.image != nil
        else { return false }
        guard Self.maximumSelectionsAllowed > 0
        else { return true }
        let selectedItems = collectionView.indexPathsForSelectedItems?.count ?? 0
        guard Self.maximumSelectionsAllowed > selectedItems
        else {
            showAlert(message: L10n.Error.max20Items)
            return false
        }
        if indexPath.item < assets.count,
           preSelectedIdentifiers.contains(assets[indexPath.item].localIdentifier) {
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
        bottomToolbar.selectedCount = selectedIdentifiers.count
    }
    
    open func collectionView(
        _ collectionView: UICollectionView,
        didDeselectItemAt indexPath: IndexPath
    ) {
        if indexPath.item < assets.count {
            selectedIdentifiers.remove(assets[indexPath.item].localIdentifier)
            selectedIndexPaths.removeAll(where: {$0 == indexPath})
        }
        bottomToolbar.selectedCount = selectedIdentifiers.count
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
}

private extension PhotosPickerVC {
    
    func requestPhotoAccessIfNeeded(_ status: PHAuthorizationStatus) {
        guard status == .notDetermined else { return }
        PHPhotoLibrary.requestAuthorization { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.assets = PHAsset.fetchAssets(with: self.fetchOptions)
                self.collectionView.reloadData()
            }
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
            collectionView.selectItem(at: .init(item: assets.index(of: $0)), animated: false, scrollPosition: [])
        }
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

extension PhotosPickerVC: PHPhotoLibraryChangeObserver {
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {[weak self] in
            self?.fetchAssets()
        }
    }
    
    
}

extension PhotosPickerVC {
    
    open class BottomToolbar: View {
        
        public lazy var appearance = PhotosPickerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        lazy var attachButton = AttachButton()
            .withoutAutoresizingMask
        
        private var heightContraint: NSLayoutConstraint?
        
        public var selectedCount: Int {
            get { Int(attachButton.selectedCountLabel.value ?? "0") ?? 0 }
            set {
                attachButton.selectedCountLabel.value = String(newValue)
                if newValue == 0 {
                    heightContraint?.constant = 0
                } else {
                    heightContraint?.constant = 80
                }
            }
        }
        
        open override func setup() {
            super.setup()
            attachButton.layer.cornerRadius = 8
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.toolbarBackgroundColor
        }
        
        open override func setupLayout() {
            super.setupLayout()
            addSubview(attachButton)
            attachButton.pin(to: self,
                             anchors: [
                                .leading(16),
                                    .trailing(-16),
                                    .centerY(),
                                    .top(0, .greaterThanOrEqual),
                                    .bottom(0, .lessThanOrEqual)]
            )
            attachButton.heightAnchor.pin(constant: 48)
            heightContraint = resize(anchors: [.height(selectedCount == 0 ? 0 : 80)])[0]
        }
    }
    
    open class AttachButton: Control {
        
        public lazy var appearance = PhotosPickerVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        lazy var selectedCountLabel = BadgeView()
            .withoutAutoresizingMask
        
        open override func setup() {
            super.setup()
            selectedCountLabel.isUserInteractionEnabled = false
            titleLabel.textAlignment = .right
            selectedCountLabel.clipsToBounds = true
            titleLabel.text = L10n.ImagePicker.Attach.Button.title
            selectedCountLabel.value = "0"
        }
        
        open override func setupLayout() {
            super.setupLayout()
            addSubview(titleLabel)
            addSubview(selectedCountLabel)
            titleLabel.pin(to: self, anchors: [.top(12), .bottom(-12), .leading(0, .greaterThanOrEqual)])
            selectedCountLabel.pin(to: self, anchors: [.top(12), .bottom(-12), .trailing(0, .lessThanOrEqual)])
            titleLabel.trailingAnchor.pin(to: self.centerXAnchor, constant: -4)
            selectedCountLabel.leadingAnchor.pin(to: self.centerXAnchor, constant: 4)
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.attachButtonBackgroundColor
            titleLabel.textColor = appearance.attachTitleColor
            titleLabel.font = appearance.attachTitleFont
            titleLabel.backgroundColor = appearance.attachTitleBackgroundColor
            selectedCountLabel.textColor = appearance.attachCountTextColor
            selectedCountLabel.font = appearance.attachCountTextFont
            selectedCountLabel.backgroundColor = appearance.attachCountBackgroundColor
            selectedCountLabel.widthAnchor.pin(greaterThanOrEqualTo: selectedCountLabel.heightAnchor)
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            selectedCountLabel.layer.cornerRadius = selectedCountLabel.bounds.height / 2
        }
    }
}


