//
//  MessageCell+ReplyArrowView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageCell {
    
    open class ReplyArrowView: View {
        
        public lazy var appearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setupLayout() {
            super.setupLayout()
            backgroundColor = .clear
            clipsToBounds = true
            clearsContextBeforeDrawing = true
        }
        
        open var isFlipped: Bool = false {
            didSet {
                layer.setNeedsDisplay()
            }
        }
        
        open override func draw(_ layer: CALayer, in ctx: CGContext) {
            super.draw(layer, in: ctx)
            
            let strokeColor = appearance.threadReplyArrowStrokeColor.cgColor
            
            let rect = bounds.insetBy(dx: 1, dy: 1)
            let radius = CGFloat(rect.width / 2)
            
            UIGraphicsPushContext(ctx)
            if isFlipped {
                ctx.translateBy(x: rect.maxX, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }
            ctx.setStrokeColor(strokeColor)
            ctx.setLineWidth(1)
            ctx.move(to: rect.origin)
            ctx.addLine(to: CGPoint(x: rect.origin.x, y: rect.maxY - radius))
            ctx.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                       radius: radius, startAngle: radians(degrees: -180),
                       endAngle: radians(degrees: -270),
                       clockwise: true)
            ctx.strokePath()
            
            UIGraphicsPopContext()
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.setNeedsDisplay()
        }
        
        open func radians(degrees: CGFloat) -> CGFloat {
            degrees * .pi / 180.0
        }
    }
}
