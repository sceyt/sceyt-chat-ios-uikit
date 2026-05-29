//
//  AssetComposer.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.08.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class AssetComposer {
    
    public static let shared = AssetComposer()
    
    private let anchorCalculator: AnchorCalculating
    
    private let lightTrait = UITraitCollection(userInterfaceStyle: .light)
    private let darkTrait = UITraitCollection(userInterfaceStyle: .dark)
    private let scale = UITraitCollection(displayScale: UIScreen.main.scale)
    
    public init(anchorCalculator: AnchorCalculating = DefaultAnchorCalculator()) {
        self.anchorCalculator = anchorCalculator
    }
    
    open func compose(from assets: Asset..., maxSize: CGSize? = nil) -> UIImage? {
        let maxSize = maxSize ?? assets.map(\.image.size).max
        
        guard maxSize != .zero else { return nil }
        
        let lightImage = renderImage(in: maxSize, assets: assets, userInterfaceStyle: .light)
        let darkImage = renderImage(in: maxSize, assets: assets, userInterfaceStyle: .dark)
        
        lightImage.imageAsset?.register(lightImage, with: UITraitCollection(traitsFrom: [lightTrait, scale]))
        lightImage.imageAsset?.register(darkImage, with: UITraitCollection(traitsFrom: [darkTrait, scale]))
        return lightImage
    }
    
    open func renderImage(in maxSize: CGSize, assets: [Asset], userInterfaceStyle: UIUserInterfaceStyle) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: maxSize)
        let traitCollection = UITraitCollection(userInterfaceStyle: userInterfaceStyle)

        return renderer.image { context in
            for asset in assets {
                var image = asset.image
                let rect = CGRect(origin: calculate(asset.anchor,
                                                    for: image.size,
                                                    inMaxSize: maxSize),
                                  size: image.size)

                switch asset.renderingMode {
                case .original:
                    // Resolve the source asset for the target style so light/dark
                    // variants render distinctly (mirrors the .template branch).
                    if let imageAsset = image.imageAsset {
                        image = imageAsset.image(with: traitCollection)
                    }
                    image = image.withRenderingMode(.alwaysOriginal)
                case .template(let color):
                    image = image.withTintColor(color.resolvedColor(with: traitCollection))
                    image = image.withRenderingMode(.alwaysTemplate)
                }

                image.draw(in: rect)
            }
        }
    }
    
    open func calculate(_ anchor: Anchor, for size: CGSize, inMaxSize maxSize: CGSize) -> CGPoint {
        anchorCalculator.calculate(anchor: anchor, for: size, inMaxSize: maxSize)
    }
}

public extension AssetComposer {
    public enum Anchor {
        case top(CGPoint = .zero)
        case topLeading(CGPoint = .zero)
        case topTrailing(CGPoint = .zero)
        case center(CGPoint = .zero)
        case bottom(CGPoint = .zero)
        case bottomLeading(CGPoint = .zero)
        case bottomTrailing(CGPoint = .zero)
        case leading(CGPoint = .zero)
        case trailing(CGPoint = .zero)
    }
    
    public enum RenderingMode {
        case template(UIColor)
        case original
    }
    
    public struct Asset {
        let image: UIImage
        let renderingMode: RenderingMode
        var anchor: Anchor
        
        public init(
            image: UIImage,
            renderingMode: RenderingMode,
            anchor: Anchor = .center()
        ) {
            self.image = image
            self.renderingMode = renderingMode
            self.anchor = anchor
        }
    }
}

extension [CGSize] {
    
    var max: CGSize {
        reduce(CGSize.zero) { maxSize, size in
            CGSize(width: Swift.max(maxSize.width, size.width),
                   height: Swift.max(maxSize.height, size.height))
        }
    }
}
