//
//  MessageInputViewController+VoiceRecorderView+SlidingView.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecorderView {
    open class SlidingView: View {
        public lazy var appearance = Components.messageInputVoiceRecorderView.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        public let onCancel: () -> Void
        open var duration: Double = 0.0 {
            didSet {
                durationLabel.text = appearance.durationFormatter.format(duration)
            }
        }
        
        public enum State {
            case unlock, locked, delete
        }
        
        open var state = State.unlock {
            didSet {
                UIView.performWithoutAnimation {
                    switch state {
                    case .unlock:
                        slideButton.setAttributedTitle(.init(
                            string: appearance.slideToCancelText,
                            attributes: [
                                .font: appearance.slideToCancelTextStyleLabelAppearance.font,
                                .foregroundColor: appearance.slideToCancelTextStyleLabelAppearance.foregroundColor
                            ]
                        ), for: [])
                    case .locked:
                        slideButton.setAttributedTitle(.init(
                            string: appearance.cancelText, attributes: [
                                .font: appearance.cancelLabelAppearance.font,
                                .foregroundColor: appearance.cancelLabelAppearance.foregroundColor
                            ]
                        ), for: [])
                    case .delete:
                        slideButton.setAttributedTitle(nil, for: [])
                    }
                    slideButton.layoutIfNeeded()
                }
            }
        }
        
        open lazy var line = UIView()
        
        open lazy var dotView = DotView()
        open lazy var durationLabel = {
            $0.text = "0:00"
            return $0
        }(UILabel())
        
        open lazy var slideButton = UIButton()
        
        open lazy var row = UIStackView(row: dotView, durationLabel, spacing: 8, alignment: .center)
        
        public init(frame: CGRect = .zero, onCancel: @escaping (() -> Void)) {
            self.onCancel = onCancel
            super.init(frame: frame)
            
            state = .unlock
        }
        
        @available(*, unavailable)
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            line.backgroundColor = appearance.dividerColor
            durationLabel.font = appearance.durationLabelAppearance.font
            durationLabel.textColor = appearance.durationLabelAppearance.foregroundColor
            dotView.appearance = appearance
        }
        
        open override func setup() {
            super.setup()
            
            slideButton.addTarget(self, action: #selector(onTapCancel), for: .touchUpInside)
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(line.withoutAutoresizingMask)
            
            line.pin(to: self, anchors: [.top, .leading, .trailing])
            line.resize(anchors: [.height(0.5)])
            
            addSubview(row.withoutAutoresizingMask)
            addSubview(slideButton.withoutAutoresizingMask)
            row.pin(to: self, anchors: [.leading(12), .top(16)])
            resize(anchors: [.height(52)])
            slideButton.centerXAnchor.pin(to: centerXAnchor)
            slideButton.centerYAnchor.pin(to: row.centerYAnchor)
            
            dotView.resize(anchors: [.height(8), .width(8)])
        }
        
        @objc
        open func onTapCancel() {
            onCancel()
        }
        
        open func stopAnimating() {
            dotView.stopAnimating()
        }
        
        open func startAnimating() {
            dotView.startAnimating()
        }
    }
}
