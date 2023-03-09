//
//  TypingView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class TypingView: View {

    open lazy var indicator = IndicatorView
        .init()
        .withoutAutoresizingMask

    open var hold = L10n.Channel.Member.typing

    open lazy var label = UILabel()
        .withoutAutoresizingMask

    open private(set) var typers = [String]()
    
    open var timer: Timer?

    func update(typer: String, typing: Bool) {
        let view = Self.display(typer: typer)
        if !typing {
            typers.removeAll { $0 == view }
        } else if !typers.contains(view) {
            typers.insert(view, at: 0)
        }

        guard typers.count > 0 else {
            stop()
            return
        }

        if timer == nil {
            updateTyping()
            start()
        }
    }

    open override func setupLayout() {
        super.setupLayout()
        addSubview(label)
        addSubview(indicator)

        label.leadingAnchor.pin(to: leadingAnchor)
        label.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor)
        label.bottomAnchor.pin(to: bottomAnchor)
        label.topAnchor.pin(to: topAnchor)
        indicator.leadingAnchor.pin(to: label.trailingAnchor, constant: 6)
        indicator.topAnchor.pin(to: centerYAnchor)
        indicator.resize(anchors: [.height(indicator.ellipseSize),
            .width(3 * indicator.ellipseSize + 2 * indicator.ellipseDistance)])
    }

    open override func setupAppearance() {
        super.setupAppearance()
        label.lineBreakMode = .byCharWrapping
        label.font = Fonts.regular.withSize(13)
        label.textColor = .textGray
    }

    open override var isHidden: Bool {
        didSet {
            if isHidden {
                stop()
            } else if superview != nil, !typers.isEmpty {
                start()
            }
        }
    }

    open func updateTyping() {
        print("[TypingView]", "updateTyping", Unmanaged.passUnretained(self).toOpaque(), typers)
        if typers.count > 0 {
            let m = typers.removeFirst()
            typers.append(m)
            label.text = m.isEmpty ? hold : m + " " + hold
            label.setNeedsDisplay()
        } else {
            stop()
        }
    }

    open func start() {
        if timer?.isValid == true {
            return
        }
        timer = Timer
            .scheduledTimer(
                withTimeInterval: 2,
                repeats: true,
                block: { [weak self] _ in
            self?.updateTyping()
        })
        indicator.start()
    }

    open func stop() {
        if timer?.isValid == true {
            timer?.invalidate()
            timer = nil
        }
        indicator.stop()
    }

    open class func display(typer: String) -> String {
        let sub = String(typer.split(separator: " ").first ?? "\(typer)")
        if sub.count < 10 {
            return sub
        }
        return String(sub.substring(toIndex: 10))
    }
    
    deinit {
        stop()
    }
}

extension TypingView {

    open class IndicatorView: View {

        open override func setup() {
            super.setup()
            isOpaque = false
        }

        open lazy var colors = [UIColor.textGray.withAlphaComponent(1).cgColor,
                                UIColor.textGray.withAlphaComponent(0.7).cgColor,
                                UIColor.textGray.withAlphaComponent(0.5).cgColor]

        open var ellipseSize: CGFloat = 4 {
            didSet { setNeedsDisplay() }
        }

        open var ellipseDistance: CGFloat = 3 {
            didSet { setNeedsDisplay() }
        }

        open func fillColor(pos: Int) -> CGColor {
            guard 0 ..< colors.count ~= pos else {
                return colors[0]
            }
            return colors[pos]
        }

        open func ellipseRect(pos: Int) -> CGRect {
            let x = CGFloat(pos) * ellipseSize + CGFloat(pos) * ellipseDistance
            return CGRect(x: x, y: 0, width: ellipseSize, height: ellipseSize)
        }

        open override func draw(_ rect: CGRect) {
            let ctx = UIGraphicsGetCurrentContext()
            for index in 0 ..< colors.count {
                ctx?.setFillColor(fillColor(pos: index))
                ctx?.fillEllipse(in: ellipseRect(pos: index))
            }
            colors.insert(colors.removeLast(), at: 0)
        }

        open var timer: Timer?
        open func start() {
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: {[weak self] (_) in
                self?.setNeedsDisplay()
            })
        }

        open func stop() {
            if timer?.isValid == true {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}
