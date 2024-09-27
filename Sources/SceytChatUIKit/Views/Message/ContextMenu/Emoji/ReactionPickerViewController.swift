//
//  ReactionPickerViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol ReactionPickerViewControllerDataSource: AnyObject {
    
    var emojis: [String] { get }
    var selectedEmojis: [String] { get }
    var showPlusAfterEmojis: Bool { get }
}

public protocol ReactionPickerViewControllerDelegate: AnyObject {
    
    func didSelect(emoji: String)
    func didDeselect(emoji: String)
    func didSelectMoreAction()
}

open class ReactionPickerViewController: ViewController {
   
    open lazy var containerView = UIView()
        .withoutAutoresizingMask
        
    open lazy var containerStackView = UIStackView()
        .withoutAutoresizingMask
    
    open lazy var backedStackView = UIStackView()
        .withoutAutoresizingMask
            
    open weak var dataSource: ReactionPickerViewControllerDataSource? {
        didSet {
            containerStackView.removeArrangedSubviews()
            setupData()
        }
    }
    open weak var delegate: ReactionPickerViewControllerDelegate?
    
    override open func setup() {
        super.setup()
        view.clipsToBounds = false
        containerView.clipsToBounds = false
        containerView.layer.cornerRadius = Layouts.containerHeight / 2

        containerStackView.spacing = 4
        
        backedStackView.spacing = 4
    }

    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(containerView)
        containerView.pin(to: view)
        containerView.resize(anchors: [.height(Layouts.containerHeight)])
        containerView.addSubview(backedStackView)
        containerView.addSubview(containerStackView)
        containerStackView.pin(to: containerView, anchors: [.leading(6), .centerX, .centerY])
        backedStackView.pin(to: containerStackView, anchors: [.leading, .trailing, .centerY])
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .clear
        containerView.backgroundColor = appearance.backgroundColor
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShow(start: .zero, duration: 0.02, relativeDuration: 1.0)
    }
    
    open func focusEmoji(at point: CGPoint?) {
        guard let point else {
            containerStackView.arrangedSubviews
                .compactMap { $0 as? UIControl }
                .filter { $0.isHighlighted }
                .forEach { updateEmoji(control: $0, isScaled: false) }
            return
        }
        let converted = view.convert(point, to: containerStackView)
        var buttons = containerStackView.arrangedSubviews.compactMap { $0 as? UIControl }
        if let index = buttons.firstIndex(where: { $0.frame.contains(converted) }) {
            let highlighting = buttons.remove(at: index)
            if !highlighting.isHighlighted {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                updateEmoji(control: highlighting, isScaled: true)
            }
            buttons
                .filter { $0.isHighlighted }
                .forEach { updateEmoji(control: $0, isScaled: false) }
        }
    }
    
    open func selectHighlightedIfNeeded() {
        if let highlighted = containerStackView.arrangedSubviews
            .compactMap({ $0 as? UIControl })
            .filter({ $0.isHighlighted })
            .first {
            if let highlighted = highlighted as? Button {
                didSelectEmoji(sender: highlighted)
            } else {
                didTapMoreControl()
            }
        }
    }
    
    open func cancelHighlightedIfNeeded() {
        if let highlighted = containerStackView.arrangedSubviews
            .compactMap({ $0 as? UIControl })
            .filter({ $0.isHighlighted })
            .first {
            if let highlighted = highlighted as? Button {
                didCancelEmoji(sender: highlighted)
            }
        }
    }
    
    open func setupForAnimation() {
        view.alpha = 0
        containerStackView.arrangedSubviews.forEach {
            $0.alpha = 0
            $0.transform = .init(scaleX: 0.0, y: 0.0)
        }
        backedStackView.arrangedSubviews.forEach { $0.alpha = 0 }
    }
    
    open func animateShow(start: TimeInterval, duration: TimeInterval, relativeDuration: TimeInterval) {
        UIView.animateKeyframes(withDuration: 0.5, delay: 0) { [self] in
            UIView.addKeyframe(withRelativeStartTime: start, relativeDuration: duration) {
                self.view.alpha = 1
            }
            var emojiStart: TimeInterval = start + duration
            let emojiDuration = (relativeDuration - emojiStart) / Double(self.containerStackView.arrangedSubviews.count)
            let zipped = zip(containerStackView.arrangedSubviews, backedStackView.arrangedSubviews)
            zipped.forEach { button, backgroundView in
                UIView.addKeyframe(withRelativeStartTime: emojiStart, relativeDuration: emojiDuration) {
                    button.alpha = 1
                    button.transform = .identity
                    backgroundView.alpha = 1
                }
                emojiStart += emojiDuration
            }
        }
    }

}

public extension ReactionPickerViewController {
    enum Layouts {
        public static let containerHeight: CGFloat = 48
        public static let emojiSize: CGFloat = 40
        public static let emojiFont: CGFloat = 30
    }
}

private extension ReactionPickerViewController {
    
    func setupData() {
        func backgroundView() -> UIView {
            let backgroundView = UIView()
            backgroundView.resize(anchors: [.width(Layouts.emojiSize), .height(Layouts.emojiSize)])
            backgroundView.layer.cornerRadius = Layouts.emojiSize / 2
            return backgroundView
        }
        guard let dataSource
        else { return }
        let selectedEmojis = dataSource.selectedEmojis
        for (index, emoji) in dataSource.emojis.enumerated() {
            let button = Button()
            button.addTarget(self, action: #selector(didTapDownEmoji(sender:)), for: .touchDown)
            button.addTarget(self, action: #selector(didSelectEmoji(sender:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(didCancelEmoji(sender:)), for: .touchCancel)
            button.setAttributedTitle(.init(
                string: emoji,
                attributes: [.font: UIFont.systemFont(ofSize: Layouts.emojiFont)]
            ), for: .normal)
            button.sizeToFit()
            button.tag = index
            button.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
            button.resize(anchors: [.height(Layouts.emojiSize), .width(Layouts.emojiSize)])
            
            containerStackView.addArrangedSubview(button)
            let backgroundView = backgroundView()
            if selectedEmojis.contains(emoji) {
                button.isSelected = true
                backgroundView.backgroundColor = appearance.selectedBackgroundColor
            }
            backedStackView.addArrangedSubview(backgroundView)
        }
        if dataSource.showPlusAfterEmojis == true {
            let imageView = UIImageView(image: appearance.moreIcon)
                .withoutAutoresizingMask
            imageView.contentMode = .center
            
//            imageView.backgroundColor = appearance.moreButtonBackgroundColor
//            imageView.layer.cornerRadius = Layouts.emojiFont / 2
            
            let moreControl = UIControl().withoutAutoresizingMask
            moreControl.tag = dataSource.emojis.count
            moreControl.addTarget(self, action: #selector(didTapMoreControl), for: .touchUpInside)
            moreControl.backgroundColor = .clear
            moreControl.addSubview(imageView)
            
            imageView.centerXAnchor.pin(to: moreControl.centerXAnchor)
            imageView.centerYAnchor.pin(to: moreControl.centerYAnchor)
            imageView.widthAnchor.pin(constant: Layouts.emojiFont)
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
            moreControl.widthAnchor.pin(constant: Layouts.emojiSize)
            moreControl.heightAnchor.pin(to: moreControl.widthAnchor)
            containerStackView.addArrangedSubview(moreControl)
            let backgroundView = backgroundView()
            backedStackView.addArrangedSubview(backgroundView)
        }
    }
    
    func updateEmoji(control: UIControl, isScaled: Bool) {
        control.isHighlighted = isScaled
        UIView.animate(withDuration: 0.12) {
            control.transform = isScaled ? .init(scaleX: 1.6, y: 1.6).translatedBy(x: 0, y: -13): .identity
        }
    }
}
private extension ReactionPickerViewController {
    
    @objc
    func didSelectEmoji(sender: UIButton) {
        if let emoji = sender.attributedTitle(for: .normal)?.string {
            sender.isSelected ? delegate?.didDeselect(emoji: emoji) : delegate?.didSelect(emoji: emoji)
        }
    }
    
    @objc
    func didTapDownEmoji(sender: UIButton) {
        updateEmoji(control: sender, isScaled: true)
    }

    @objc
    func didCancelEmoji(sender: UIButton) {
        updateEmoji(control: sender, isScaled: false)
    }

    @objc
    func didTapMoreControl() {
        delegate?.didSelectMoreAction()
    }

}
