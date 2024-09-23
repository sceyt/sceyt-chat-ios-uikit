//
//  MessageInputViewController+MessageSearchControlsView.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagayn on 16.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController {
    
    open class MessageSearchControlsView: View {
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        open lazy var nextResultButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var prevResultButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var resultsCounterLabel = UILabel()
            .withoutAutoresizingMask
        
        open var onAction: ((Action) -> Void)?
        
        open override func setup() {
            super.setup()
            
            nextResultButton.setImage(.chevronUp.withRenderingMode(.alwaysTemplate), for: .normal)
            prevResultButton.setImage(.chevronDown.withRenderingMode(.alwaysTemplate), for: .normal)
            
            nextResultButton.addTarget(self, action: #selector(onNext), for: .touchUpInside)
            prevResultButton.addTarget(self, action: #selector(onPrevious), for: .touchUpInside)
            prevResultButton.isEnabled = false
            nextResultButton.isEnabled = false
        }
        
        open override func setupLayout() {
            super.setupLayout()
            
            addSubview(separatorView)
            addSubview(nextResultButton)
            addSubview(prevResultButton)
            addSubview(resultsCounterLabel)
            
            nextResultButton.resize(anchors: [.height(28), .width(28)])
            prevResultButton.resize(anchors: [.height(28), .width(28)])
            
            separatorView.resize(anchors: [.height(1)])
            separatorView.pin(to: self, anchors: [.leading, .top, .trailing])
            
            nextResultButton.pin(
                to: self,
                anchors: [.leading(12), .top(12), .bottom(-12)]
            )
            nextResultButton.trailingAnchor.pin(to: prevResultButton.leadingAnchor, constant: -12)
            
            prevResultButton.pin(
                to: self,
                anchors: [.top(12), .bottom(-12)]
            )
            prevResultButton.trailingAnchor.pin(lessThanOrEqualTo: resultsCounterLabel.leadingAnchor, constant: -12)
            
            resultsCounterLabel.pin(
                to: self,
                anchors: [.top(12), .bottom(-12), .trailing(-16)]
            )
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            separatorView.backgroundColor = appearance.separatorColor
            nextResultButton.tintColor = appearance.buttonTintColor
            prevResultButton.tintColor = appearance.buttonTintColor
            resultsCounterLabel.textColor = appearance.textColor
            resultsCounterLabel.font = appearance.textFont
        }
        
        open func update(with searchResult: MessageSearchCoordinator, query: String) {
            nextResultButton.isEnabled = searchResult.hasNext
            prevResultButton.isEnabled = searchResult.hasPrev
            if (query.isEmpty || searchResult.state == .loadFailed),
               !searchResult.hasNext,
               !searchResult.hasPrev {
                resultsCounterLabel.text = nil
            } else if searchResult.cacheCount == 0 {
                setNotFoundCounterText()
            } else {
                setCounterText(currentIndex: searchResult.currentIndex + 1, resultsCount: searchResult.cacheCount)
            }
        }
        
        open func setCounterText(currentIndex: Int, resultsCount: Int) {
            resultsCounterLabel.text = L10n.Channel.Search.foundIndex(
                currentIndex,
                resultsCount
            )
        }
        
        open func setNotFoundCounterText() {
            resultsCounterLabel.text = L10n.Channel.Search.notFound
        }
        
        @objc open func onPrevious() {
            onAction?(.previousResult)
        }
        
        @objc open func onNext() {
            onAction?(.nextResult)
        }
    }
}

public extension MessageInputViewController.MessageSearchControlsView {
    enum Action {
        case previousResult
        case nextResult
    }
}
