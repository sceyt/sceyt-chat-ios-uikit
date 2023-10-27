//
//  Geometry+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

public extension CGRect {
    var center: CGPoint {
        .init(x: self.midX, y: midY)
    }
}

public extension CGSize {
    static var nan: CGSize {
        .init(width: CGFloat.nan, height: .nan)
    }

    var isNan: Bool {
        width.isNaN || height.isNaN
    }

    func scaleProportionally(smallSide dimension: CGFloat) -> CGSize {
        
        guard max(width, height) > dimension
        else { return self }
        
        let aspectRatio = width / height
        
        var newSize: CGSize!
        if aspectRatio > 1 {
            newSize = CGSize(width: dimension, height: dimension / aspectRatio)
        } else {
            newSize = CGSize(width: dimension * aspectRatio, height: dimension)
        }
        
        return newSize
    }

    var maxSide: CGFloat { max(width, height) }

    var minSide: CGFloat { min(width, height) }
}

public extension UIPanGestureRecognizer {

    func projectedLocation(decelerationRate: UIScrollView.DecelerationRate) -> CGPoint {
        let velocityOffset = velocity(in: view).projectedOffset(decelerationRate: .normal)
        let projectedLocation = location(in: view!) + velocityOffset
        return projectedLocation
    }

}

public extension CGPoint {

    func projectedOffset(decelerationRate: UIScrollView.DecelerationRate) -> CGPoint {
        return CGPoint(x: x.projectedOffset(decelerationRate: decelerationRate),
                       y: y.projectedOffset(decelerationRate: decelerationRate))
    }

}

public extension CGFloat {

    func projectedOffset(decelerationRate: UIScrollView.DecelerationRate) -> CGFloat {
        let multiplier = 1 / (1 - decelerationRate.rawValue) / 1000
        return self * multiplier
    }

}

public extension CGPoint {

    static func +(left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x,
                       y: left.y + right.y)
    }

}
