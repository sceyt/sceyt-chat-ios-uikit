//
//  EmojiController.swift
//  Emoji-Custom-Transition
//
//

import UIKit

public protocol EmojiControllerDataSource: AnyObject {
    
    var emojis: [String] { get }
    var selectedEmojis: [String] { get }
}

public protocol EmojiControllerDelegate: AnyObject {
    
    func didSelect(emoji: String)
    func didDeselect(emoji: String)
    func didSelectMoreAction()
}

open class EmojiController: ViewController {
   
    open lazy var containerView = UIView()
        .withoutAutoresizingMask
        
    open lazy var containerStackView = UIStackView()
        .withoutAutoresizingMask
    
    open lazy var backedStackView = UIStackView()
        .withoutAutoresizingMask
            
    open weak var dataSource: EmojiControllerDataSource? {
        didSet {
            containerStackView.removeArrangedSubviews()
            setupData()
        }
    }
    open weak var delegate: EmojiControllerDelegate?
    
    override open func setup() {
        super.setup()
        view.clipsToBounds = false
        containerView.clipsToBounds = false
        containerView.layer.cornerRadius = 20
        
        containerStackView.spacing = 4
        
        backedStackView.spacing = 4
    }

    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(containerView)
        containerView.pin(to: view)
        containerView.resize(anchors: [.height(Constants.emojiSize)])
        containerView.addSubview(backedStackView)
        containerView.addSubview(containerStackView)
        containerStackView.pin(to: containerView, anchors: [.leading(12), .trailing(-12), .centerY])
        backedStackView.pin(to: containerStackView, anchors: [.leading, .centerY])
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .clear
        containerView.backgroundColor = appearance.backgroundColor
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
    
    open func setupForAnimation() {
        view.alpha = 0
        containerStackView.arrangedSubviews.forEach { $0.alpha = 0 }
        backedStackView.arrangedSubviews.forEach { $0.alpha = 0 }
    }
    
    open func animateShow(start: TimeInterval, relativeDuration: TimeInterval) {
        let duration = relativeDuration / 6
        UIView.addKeyframe(withRelativeStartTime: start, relativeDuration: duration) {
            self.view.alpha = 1
        }
        var emojiStart: TimeInterval = start + duration
        let emojiDuration = (relativeDuration - emojiStart) / Double(self.containerStackView.arrangedSubviews.count)
        let zipped = zip(containerStackView.arrangedSubviews, backedStackView.arrangedSubviews)
        zipped.forEach { button, backgroundView in
            UIView.addKeyframe(withRelativeStartTime: emojiStart, relativeDuration: emojiDuration) {
                button.alpha = 1
                backgroundView.alpha = 1
            }
            emojiStart += emojiDuration
        }
    }

}

public extension EmojiController {
    
    enum Constants {
        public static let emojiSize: CGFloat = 40
        public static let emojiFont: CGFloat = 28
    }
}

private extension EmojiController {
    
    func setupData() {
        func backgroundView() -> UIView {
            let backgroundView = UIView()
            backgroundView.resize(anchors: [.width(36), .height(36)])
            backgroundView.layer.cornerRadius = 18
            return backgroundView
        }
        
        for (index, emoji) in (dataSource?.emojis ?? []).enumerated() {
            let button = Button()
            button.addTarget(self, action: #selector(didTapDownEmoji(sender:)), for: .touchDown)
            button.addTarget(self, action: #selector(didSelectEmoji(sender:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(didCancelEmoji(sender:)), for: .touchCancel)
            button.setAttributedTitle(.init(
                string: emoji,
                attributes: [.font: UIFont.systemFont(ofSize: Constants.emojiFont)]
            ), for: .normal)
            button.sizeToFit()
            button.tag = index
            button.titleEdgeInsets = .init(top: 0, left: 2, bottom: 0, right: 0)
            button.resize(anchors: [.height(36), .width(36)])
            
            containerStackView.addArrangedSubview(button)
            let backgroundView = backgroundView()
            if dataSource?.selectedEmojis.contains(emoji) ?? false {
                button.isSelected = true
                backgroundView.backgroundColor = appearance.selectedBackgroundColor
            }
            backedStackView.addArrangedSubview(backgroundView)
        }
        let imageView = UIImageView(image: Images.messageActionMoreReactions)
            .withoutAutoresizingMask
        imageView.contentMode = .center
        
        imageView.backgroundColor = appearance.moreButtonBackgroundColor
        imageView.layer.cornerRadius = 14
        
        let moreControl = UIControl().withoutAutoresizingMask
        moreControl.tag = dataSource?.emojis.count ?? -1
        moreControl.addTarget(self, action: #selector(didTapMoreControl), for: .touchUpInside)
        moreControl.backgroundColor = .clear
        moreControl.addSubview(imageView)
        
        imageView.centerXAnchor.pin(to: moreControl.centerXAnchor)
        imageView.centerYAnchor.pin(to: moreControl.centerYAnchor)
        imageView.widthAnchor.pin(to: moreControl.widthAnchor)
        imageView.heightAnchor.pin(to: imageView.widthAnchor)
        moreControl.widthAnchor.pin(constant: 28)
        moreControl.heightAnchor.pin(to: moreControl.widthAnchor)
        containerStackView.addArrangedSubview(moreControl)
        let backgroundView = backgroundView()
        backedStackView.addArrangedSubview(backgroundView)
    }
    
    func updateEmoji(control: UIControl, isScaled: Bool) {
        control.isHighlighted = isScaled
        UIView.animate(withDuration: 0.12) {
            control.transform = isScaled ? .init(scaleX: 1.5, y: 1.5).translatedBy(x: 0, y: -15): .identity
        }
    }
}
private extension EmojiController {
    
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
