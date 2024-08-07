//
//  ImageBuilder.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import Accelerate

open class ImageBuilder {
    
    open class func build(
        from view: UIView,
        opaque: Bool = false,
        scale: CGFloat = SceytChatUIKit.shared.config.displayScale
    ) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.frame.size, opaque, scale)
        guard let context = UIGraphicsGetCurrentContext()
        else { return nil }
        view.layer.render(in: context)
        guard let image = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = image.cgImage
        else { return nil }
        UIGraphicsEndImageContext()
        return UIImage(cgImage: cgImage)
    }
    
    open class func build(size: CGSize = .init(width: 60, height: 60),
                          backgroundColor: UIColor = .white,
                          opaque: Bool = false,
                          scale: CGFloat = SceytChatUIKit.shared.config.displayScale,
                          content: (UILabel) -> Void
    ) -> UIImage? {
        
        func createImage() -> UIImage? {
            let v = UIView(frame: CGRect(origin: .zero, size: size))
            v.backgroundColor = backgroundColor
            let l = UILabel()
            l.textAlignment = .center
            l.adjustsFontSizeToFitWidth = true
            l.frame = v.bounds
            content(l)
            v.addSubview(l)
            return build(
                from: v,
                opaque: opaque,
                scale: scale
            )
        }
        if Thread.isMainThread {
            return createImage()
        }
        var image: UIImage?
        DispatchQueue.main.sync {
            image = createImage()
        }
        return image
    }
    
    open class func build(
        fillColor: UIColor,
        size: CGSize = .init(width: 60, height: 60)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image {
            $0.cgContext.setFillColor(fillColor.cgColor)
            $0.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    public private(set) var cgImage: CGImage?
    public private(set) var uiImage: UIImage?
    
    public var imageSize: CGSize {
        if let uiImage {
            return uiImage.size
        } else if let cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return .nan
    }
    
    public var imageOrientation: UIImage.Orientation {
        if let uiImage {
            return uiImage.imageOrientation
        } else {
            return .up
        }
    }
   
    required public init(image: CGImage) {
        cgImage = image
        uiImage = UIImage(cgImage: image)
    }
    
    required public init(image: UIImage) {
        uiImage = image
        if let cgImage = image.cgImage {
            self.cgImage = cgImage
        } else if let ciImage = image.ciImage {
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                self.cgImage = cgImage
            } else {
                self.cgImage = nil
            }
        } else {
            self.cgImage = nil
        }
    }
    
    required public convenience init?(imageUrl: URL) {
        guard let image = UIImage(contentsOfFile: imageUrl.path)
        else { return nil }
        self.init(image: image)
    }
    
    @discardableResult
    open func resize(max: CGFloat) throws -> ImageBuilder {
        guard let image = cgImage
        else { throw ImageError.cgImageIsNil }
                
        var newSize = imageSize.scaleProportionally(smallSide: max)
        
        switch imageOrientation {
        case .right, .rightMirrored, .left, .leftMirrored:
            newSize = .init(width: newSize.height, height: newSize.width)
        default: break
        }
        
        guard image.width != Int(newSize.width),
              image.height != Int(newSize.height)
        else { return self }
        
        guard let colorSpace = image.colorSpace
        else { throw ImageError.colorSpaceIsNil }
        
        var format = vImage_CGImageFormat(bitsPerComponent: 8,
                                          bitsPerPixel: 32,
                                          colorSpace: Unmanaged.passUnretained(colorSpace),
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                          version: 0,
                                          decode: nil,
                                          renderingIntent: .defaultIntent)
        var sourceBuffer = vImage_Buffer()
        defer { sourceBuffer.data?.deallocate() }
        
        var error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                                 &format,
                                                 nil,
                                                 image,
                                                 numericCast(kvImageNoFlags))
        guard error == kvImageNoError
        else { throw ImageError.resizeFiled(error) }
        
        let destinationWidth = Int(newSize.width)
        let destinationHeight = Int(newSize.height)
        let bytesPerPixel = image.bitsPerPixel
        let destinationBytesPerRow = destinationWidth * bytesPerPixel
        let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationHeight * destinationBytesPerRow)
        defer { destData.deallocate() }
        var destBuffer = vImage_Buffer(data: destData,
                                       height: vImagePixelCount(destinationHeight),
                                       width: vImagePixelCount(destinationWidth),
                                       rowBytes: destinationBytesPerRow)
        
        error = vImageScale_ARGB8888(&sourceBuffer,
                                     &destBuffer,
                                     nil,
                                     numericCast(kvImageHighQualityResampling))
        guard error == kvImageNoError
        else { throw ImageError.resizeFiled(error) }
        
        guard let resultCGImage = vImageCreateCGImageFromBuffer(&destBuffer,
                                                                &format,
                                                                nil,
                                                                nil,
                                                                numericCast(kvImageNoFlags),
                                                                &error)?.takeRetainedValue()
        else { throw ImageError.resizeFiled(error) }
        cgImage = resultCGImage
        uiImage = UIImage(cgImage: resultCGImage, scale: 0.0, orientation: imageOrientation)
        return self
    }
    
    @discardableResult
    open func flattened(
        isOpaque: Bool = true
    ) throws -> ImageBuilder {
        guard let image = uiImage
        else { throw ImageError.uiImageIsNil }
        if image.imageOrientation == .up { return self }
        let format = image.imageRendererFormat
        format.opaque = isOpaque
        let result = UIGraphicsImageRenderer(
            size: image.size,
            format: format)
        .image {
            _ in image.draw(at: .zero)
        }
        uiImage = result
        cgImage = result.cgImage
        return self
    }
    
    
    open func jpegData(compressionQuality: CGFloat = SceytChatUIKit.shared.config.jpegDataCompressionQuality) -> Data? {
        uiImage?.jpegData(compressionQuality: compressionQuality)
    }
//    
//    open func jpegBase64(compressionQuality: CGFloat = SCTUIKitConfig.jpegDataCompressionQuality) -> String? {
//        jpegData(compressionQuality: compressionQuality)?.base64EncodedString()
//    }
    
    open class func image(from base64: String) -> UIImage? {
        if let decodedData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
            return UIImage(data: decodedData)
        }
        return nil
    }
    
    open func thumbHash() -> Data? {
        if let uiImage {
            return imageToThumbHash(image: uiImage)
        }
        return nil
    }
    
    open func thumbHashBase64() -> String? {
        thumbHash()?.base64EncodedString()
    }
    
    open class func image(thumbHash: Data) -> UIImage? {
        return thumbHashToImage(hash: thumbHash)
    }
    
    open class func image(thumbHash base64: String) -> UIImage? {
        if let decodedData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
            return image(thumbHash: decodedData)
        }
        return nil
    }
    
    open class func image(from data: Data) -> UIImage? {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            let image = UIImage(cgImage: cgImage)
            return image
        }
        return nil
    }
    
    open class func lowMemory_resizeImage(fileUrl: URL, maxPixelSize: CGFloat) -> ImageBuilder? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let downsampleOptions =  [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                  kCGImageSourceShouldCacheImmediately: true,
                                  kCGImageSourceCreateThumbnailWithTransform: true,
                                           kCGImageSourceThumbnailMaxPixelSize: maxPixelSize] as [CFString : Any] as CFDictionary

        guard let imageSource = CGImageSourceCreateWithURL(fileUrl as CFURL, imageSourceOptions),
                let downsampledImage =  CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        let image = UIImage(cgImage: downsampledImage)
        return .init(image: image)
    }

    open class func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        UIGraphicsBeginImageContext(image.size)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? image
    }
    
    open class func addShadow(to image: UIImage,
                              blur: CGFloat = 8,
                              offset: CGSize = .init(width: 0, height: 2),
                              color: UIColor = UIColor(rgb: 0x111539, alpha: 0.08)) -> UIImage
    {
        func addShadow(to image: UIImage) -> UIImage {
            let shadowRect = CGRect(
                x: offset.width - blur,
                y: offset.height - blur,
                width: image.size.width + blur * 2,
                height: image.size.height + blur * 2
            )
            
            UIGraphicsBeginImageContextWithOptions(
                CGSize(
                    width: max(shadowRect.maxX, image.size.width) - min(shadowRect.minX, 0),
                    height: max(shadowRect.maxY, image.size.height) - min(shadowRect.minY, 0)
                ),
                false, image.scale
            )
            
            let context = UIGraphicsGetCurrentContext()!
            
            context.setShadow(
                offset: offset,
                blur: blur,
                color: color.cgColor
            )
            
            image.draw(
                in: CGRect(
                    x: max(0, -shadowRect.origin.x),
                    y: max(0, -shadowRect.origin.y),
                    width: image.size.width,
                    height: image.size.height
                )
            )
            let shadowImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return shadowImage
        }
        if let imageAsset = image.imageAsset {
            return dynamic(
                light: addShadow(to: imageAsset.image(with: .init(userInterfaceStyle: .light))),
                dark: addShadow(to: imageAsset.image(with: .init(userInterfaceStyle: .dark)))
            )
        } else {
            return addShadow(to: image)
        }
    }
    
    open class func dynamic(light: UIImage,
                            dark: UIImage) -> UIImage
    {
        let imageAsset = UIImageAsset()
        
        let lightMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .light), .init(displayScale: light.scale)])
        imageAsset.register(light, with: lightMode)
        
        let darkMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .dark), .init(displayScale: dark.scale)])
        imageAsset.register(dark, with: darkMode)
        
        return imageAsset.image(with: .current)
    }
}


extension ImageBuilder {
    
    public enum ImageError: Error {
        case cgImageIsNil
        case uiImageIsNil
        case colorSpaceIsNil
        case resizeFiled(Int)
    }
}
