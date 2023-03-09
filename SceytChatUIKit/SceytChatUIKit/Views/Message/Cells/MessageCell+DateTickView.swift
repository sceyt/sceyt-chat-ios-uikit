//
//  MessageCell+InfoView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

extension MessageCell {

    open class InfoView: View {

        open lazy var stateLabel = UILabel()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
        
        open lazy var dateLabel = UILabel()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)

        open lazy var tickView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.center)
            .contentHuggingPriorityH(.required)
        
        open lazy var stackView = UIStackView()
            .withoutAutoresizingMask

        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.distribution = .fill
            stackView.spacing = 4
            stateLabel.font = appearance.infoViewStateFont
            stateLabel.textColor = appearance.infoViewStateTextColor
            stateLabel.textAlignment = .right
            dateLabel.font = appearance.infoViewDateFont
            dateLabel.textColor = appearance.infoViewDateTextColor
            dateLabel.textAlignment = .right
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(stackView)
            stackView.addArrangedSubview(stateLabel)
            stackView.addArrangedSubview(dateLabel)
            stackView.addArrangedSubview(tickView)
            stackView.pin(to: self)
        }
    }
}

extension MessageCell {
    
    open class InfoViewBackgroundView: View {
        
        open override func setup() {
            clipsToBounds = true
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
    }
}
