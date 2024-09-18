//
//  ImageCropperViewModel.swift
//  SceytChatUIKit
//
//  Created by Duc on 08.10.2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ImageCropperViewModel {
    public var isInitial: Bool = false
    public let image: UIImage
  
    public required init(image: UIImage) {
        self.image = Components.imageBuilder.normalizeOrientation(image)
    }
    
    private var parentRect: CGRect?
    
    private var initialSize: CGSize?
    
    private var figureFrame: CGRect?
    private var panLastLocation: CGPoint?
    private var imageFrame = CGRect.zero
    
    private var cornerRadius = CGFloat(0)
    
    public var parentFrame: CGRect {
        get {
            return parentRect ?? .zero
        }
        set {
            parentRect = newValue
            
            let figureSize = maskSize(with: newValue.size)
            figureFrame = CGRect(x: (parentFrame.width - figureSize.width) / 2, y: (newValue.height - figureSize.height) / 2, width: figureSize.width, height: figureSize.height)
            cornerRadius = max(figureSize.width, figureSize.height) / 2
            
            imageFrame = imageInitialFrame
        }
    }
    
    public var imageInitialFrame: CGRect {
        let size = image.size.scale(to: parentFrame.size)
        return CGRect(x: (parentFrame.width - size.width) / 2, y: (parentFrame.height - size.height) / 2, width: size.width, height: size.height)
    }
    
    public var mask: CGPath {
        guard figureFrame != nil else {
            return UIBezierPath(rect: .zero).cgPath
        }
        let hole = UIBezierPath(cgPath: border)
        let path = UIBezierPath(roundedRect: parentFrame, cornerRadius: 0)
        path.append(hole)
        return path.cgPath
    }
    
    public var border: CGPath {
        guard let frame = figureFrame else { return UIBezierPath(rect: .zero).cgPath }
        return UIBezierPath(roundedRect: frame, cornerRadius: cornerRadius != 0 ? cornerRadius : 1.0).cgPath
    }
    
    public func draggingFrame(for point: CGPoint) -> CGRect {
        let previousLocation = panLastLocation ?? point
        let difference = CGPoint(x: point.x - previousLocation.x, y: point.y - previousLocation.y)
        
        guard let borders = figureFrame else { return imageFrame }
        
        let x = imageFrame.origin.x + difference.x
        let newX = x < borders.origin.x && x + imageFrame.width > borders.maxX ? x : imageFrame.origin.x
        
        let y = imageFrame.origin.y + difference.y
        let newY = y < borders.origin.y && y + imageFrame.height > borders.maxY ? y : imageFrame.origin.y
        
        imageFrame = CGRect(origin: CGPoint(x: newX, y: newY), size: imageFrame.size)
        panLastLocation = point
        return imageFrame
    }
    
    public func setStartedPinch() {
        initialSize = CGSize(width: imageFrame.width, height: imageFrame.height)
    }
    
    public func scalingFrame(for scale: CGFloat) -> CGRect {
        let borders = figureFrame ?? .zero
        let pinchStartSize: CGSize
        if initialSize == nil {
            pinchStartSize = CGSize(width: imageFrame.width, height: imageFrame.height)
        } else {
            pinchStartSize = initialSize!
        }
        var newSize = CGSize(width: pinchStartSize.width * scale, height: pinchStartSize.height * scale)
        
        if newSize.width < borders.width || newSize.height < borders.height {
            newSize = image.size.scale(to: borders.size)
        }
        var newX = imageFrame.origin.x - (newSize.width - imageFrame.width) / 2
        var newY = imageFrame.origin.y - (newSize.height - imageFrame.height) / 2
        
        if newX + newSize.width <= borders.maxX {
            newX = borders.maxX - newSize.width
        } else if newX >= borders.origin.x {
            newX = borders.origin.x
        }
        
        if newY + newSize.height <= borders.maxY {
            newY = borders.maxY - newSize.height
        } else if newY >= borders.origin.y {
            newY = borders.origin.y
        }
        
        if newSize.width / image.size.width < 2 || newSize.height / image.size.height < 2 {
            imageFrame = CGRect(origin: CGPoint(x: newX, y: newY), size: newSize)
        }
        
        return imageFrame
    }
    
    public func transformatingFinished() {
        panLastLocation = nil
    }
    
    public func crop() -> UIImage {
        guard let borders = figureFrame else {
            return image
        }
        let point = CGPoint(x: borders.origin.x - imageFrame.origin.x, y: borders.origin.y - imageFrame.origin.y)
        let frame = CGRect(origin: point, size: borders.size)
        let x = frame.origin.x * image.size.width / imageFrame.width
        let y = frame.origin.y * image.size.height / imageFrame.height
        let width = frame.width * image.size.width / imageFrame.width
        let height = frame.height * image.size.height / imageFrame.height
        let croppedRect = CGRect(x: x, y: y, width: width, height: height)
        guard let imageRef = image.cgImage?.cropping(to: croppedRect) else {
            return image
        }
        
        let croppedImage = UIImage(cgImage: imageRef)
        return croppedImage
    }

    public func maskSize(with parentSize: CGSize) -> CGSize {
        let parentVertical = parentSize.width < parentSize.height
        let size = (parentVertical ? parentSize.width : parentSize.height) - 16
        return CGSize(width: size, height: size)
    }
}

private extension CGSize {
    func scale(to size: CGSize) -> CGSize {
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if width > height {
            newHeight = size.height
            newWidth = newHeight * width / height
        } else if width < height {
            newWidth = size.width
            newHeight = newWidth * height / width
        } else {
            newHeight = max(size.width, size.height)
            newWidth = newHeight
        }
        
        if newHeight < size.height {
            newHeight = size.height
            newWidth = newHeight * width / height
        } else if newWidth < size.width {
            newWidth = size.width
            newHeight = newWidth * height / width
        }
        return CGSize(width: newWidth, height: newHeight)
    }
}
