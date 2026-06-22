//
//  AudioWaveformView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class AudioWaveformView: View {

    open var lineWidth: CGFloat = 1.2 {
        didSet { setNeedsDisplay() }
    }
    
    open var data: [Float]? {
        didSet { setNeedsDisplay() }
    }
    
    private var _progress: Double = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    open var progress: Double {
        set { _progress = min(max(newValue, 0), 1) }
        get { _progress }
    }
    
    open override func setup() {
        super.setup()

        // This view paints in draw(rect:). With the default .scaleToFill contentMode a paint at one
        // width is just stretched when the width later changes, so a first paint at zero width (before
        // Auto Layout sizes the row) would never repaint into a real waveform. .redraw forces a repaint
        // on every bounds change.
        contentMode = .redraw
    }

    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = .clear
    }
    
    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let targetCount = Int(rect.width / lineWidth / 2)
        
        guard targetCount > 0,
              let data, !data.isEmpty,
              let context: CGContext = UIGraphicsGetCurrentContext()
        else { return }
        
        let samples = data.chunked(into: Int(ceil(Float(data.count) / Float(targetCount)))).map { $0.reduce(0, +) / Float($0.count) }
        let max = max(abs(samples.min() ?? 0), abs(samples.max() ?? 0))
        let middleY = rect.height / 2
        
        context.setAlpha(1.0)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        if max == 0 {
            // Draw flat line when all samples are zero
            let widthNormalizationFactor = rect.width / CGFloat(samples.count)
            for index in 0 ..< samples.count {
                let x = lineWidth / 2 + CGFloat(index) * widthNormalizationFactor
                context.move(to: CGPoint(x: x, y: middleY))
                context.addLine(to: CGPoint(x: x, y: middleY))
                if Double(index) / Double(samples.count) < progress {
                    context.setStrokeColor(appearance.progressColor.cgColor)
                } else {
                    context.setStrokeColor(appearance.trackColor.cgColor)
                }
                context.strokePath()
            }
            return
        }

        let heightNormalizationFactor = rect.height / CGFloat(max) / 2
        let widthNormalizationFactor = rect.width / CGFloat(samples.count)
        for index in 0 ..< samples.count {
            let pixel = CGFloat(samples[index]) * heightNormalizationFactor
            let x = lineWidth / 2 + CGFloat(index) * widthNormalizationFactor
            context.move(to: CGPoint(x: x, y: middleY - pixel))
            context.addLine(to: CGPoint(x: x, y: middleY + pixel))
            if Double(index) / Double(samples.count) < progress {
                context.setStrokeColor(appearance.progressColor.cgColor)
            } else {
                context.setStrokeColor(appearance.trackColor.cgColor)
            }
            context.strokePath()
        }
    }
}
