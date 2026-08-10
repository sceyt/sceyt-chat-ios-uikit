//
//  MessageCell+PollView.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {
    open class PollView: View, MessageCellMeasurable {
        
        // Layout constants
        private enum Layout {
            static let horizontalPadding: CGFloat = 12.0
            static let topPadding: CGFloat = 8.0
            static let questionTypeLabelSpacing: CGFloat = 4.0
            static let typeOptionsSpacing: CGFloat = 16.0
            static let optionSpacing: CGFloat = 20.0
        }

        open lazy var appearance: MessageCellAppearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var questionLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var typeLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var optionsStackView = UIStackView()
            .withoutAutoresizingMask

        private var optionViews: [Int: PollOptionView] = [:]
        
        // Store the current PollViewModel to pass with actions
        private(set) var pollViewModel: PollViewModel?

        open var data: MessageLayoutModel? {
            didSet {
                guard let data = data else {
                    isHidden = true
                    return
                }

                backgroundColor = data.message.incoming ? appearance.incomingBubbleColor : appearance.outgoingBubbleColor

                // Check if message has poll data and is not deleted
                guard data.contentOptions.contains(.poll), data.message.state != .deleted else {
                    isHidden = true
                    return
                }

                isHidden = false
                configure(with: data)
            }
        }

        public var onDidTapOption: ((Int, PollViewModel) -> Void)?
        public var onDidTapAvatars: (() -> Void)?
        
        override open func setup() {
            super.setup()

            layer.cornerRadius = 16
            optionsStackView.axis = .vertical
            optionsStackView.spacing = Layout.optionSpacing
            questionLabel.numberOfLines = 0
            typeLabel.numberOfLines = 0
        }

        override open func setupLayout() {
            super.setupLayout()

            addSubview(questionLabel)
            addSubview(typeLabel)
            addSubview(optionsStackView)

            questionLabel.pin(
                to: self,
                anchors: [
                    .leading(Layout.horizontalPadding),
                    .trailing(-Layout.horizontalPadding),
                    .top(Layout.topPadding)
                ]
            )

            typeLabel.pin(to: questionLabel, anchors: [.leading, .trailing])
            typeLabel.topAnchor.pin(to: questionLabel.bottomAnchor, constant: Layout.questionTypeLabelSpacing)

            optionsStackView.pin(to: self, anchors: [.leading(Layout.horizontalPadding), .trailing(-Layout.horizontalPadding)])
            optionsStackView.topAnchor.pin(to: typeLabel.bottomAnchor, constant: Layout.typeOptionsSpacing)
            optionsStackView.bottomAnchor.pin(to: bottomAnchor)
        }

        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = .clear

            questionLabel.font = appearance.pollViewAppearance.questionTextStyle.font
            questionLabel.textColor = appearance.pollViewAppearance.questionTextStyle.foregroundColor

            typeLabel.font = appearance.pollViewAppearance.pollTypeTextStyle.font
            typeLabel.textColor = appearance.pollViewAppearance.pollTypeTextStyle.foregroundColor
        }

        private func configure(with layoutModel: MessageLayoutModel) {
            let message = layoutModel.message

            guard let poll = message.poll, message.state != .deleted else {
                isHidden = true
                return
            }

            let viewModel = PollViewModel(from: poll, isIncmoing: layoutModel.message.incoming)
            // Store the current PollViewModel
            self.pollViewModel = viewModel
            
            questionLabel.text = viewModel.question
            typeLabel.text = viewModel.pollTypeText

            // Remove existing option views
            optionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            optionViews.removeAll()

            // Add option views
            for (index, option) in viewModel.options.enumerated() {
                let optionView = createOptionView(option: option, index: index)
                optionsStackView.addArrangedSubview(optionView)
                optionViews[index] = optionView
            }
        }

        private func createOptionView(
            option: PollOptionViewModel,
            index: Int,
        ) -> PollOptionView {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
            let optionView = PollOptionView()
            optionView.accessibilityIdentifier =
                "\(SceytChatUIKit.AccessibilityIdentifiers.Channel.Cell.pollOption).\(index)"
            optionView.viewModel = option
            optionView.addGestureRecognizer(tapGesture)
            optionView.tag = index
            optionView.onAvatarsTapped = { [weak self] in
                self?.onDidTapAvatars?()
            }
            optionView.onOptionTapped = { [weak self] in
                guard let self = self,
                      let currentPollViewModel = self.pollViewModel,
                      !currentPollViewModel.closed,
                      optionView.isUserInteractionEnabled else { return }

                let optionViewModel = currentPollViewModel.options[index]
                let isVoting = !optionViewModel.isSelected

                if isVoting {
                    optionView.animateProgressBarOnVote()
                }

                self.onDidTapOption?(index, currentPollViewModel)
            }
            return optionView
        }

        @objc private func optionTapped(_ sender: UITapGestureRecognizer) {
            guard let view = sender.view,
                  let pollOptionView = view as? PollOptionView,
                  let data = data,
                  let currentPollViewModel = pollViewModel,
                  !currentPollViewModel.closed else { return }
            // Check if interaction is disabled (vote in progress)
            guard view.isUserInteractionEnabled else { return }
            let index = view.tag

            // Check if this is a new vote (not unvoting)
            let optionViewModel = currentPollViewModel.options[index]
            let isVoting = !optionViewModel.isSelected

            // Trigger animation only when voting
            if isVoting {
                pollOptionView.animateProgressBarOnVote()
            }

            onDidTapOption?(index, currentPollViewModel)
        }

        open func updatePoll(poll: PollViewModel) {
            // Update stored PollViewModel
            self.pollViewModel = poll
            for (index, option) in poll.options.enumerated() {
                self.updateOption(with: option, at: index, animated: true)
            }
        }

        /// Update the UI for a specific poll option optimistically
        open func updateOption(with viewModel: PollOptionViewModel, at index: Int, animated: Bool = false) {
            guard let optionView = optionViews[index],
                  let data = data,
                  let poll = data.message.poll,
                  index >= 0 && index < poll.options.count else {
                return
            }

            if animated {
                optionView.updateViewModel(viewModel)
            } else {
                optionView.viewModel = viewModel
            }
        }

        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            guard let poll = model.message.poll, model.message.state != .deleted else {
                return .zero
            }

            let pollViewModel = PollViewModel(from: poll, isIncmoing: model.message.incoming)
            let pollAppearance = appearance.pollViewAppearance
            
            // Calculate max width using horizontal padding
            let contentMaxWidth = Components.messageLayoutModel.defaults.messageWidth - (Layout.horizontalPadding * 2)
            var height: CGFloat = 0

            // Top padding
            height += Layout.topPadding

            // Question height
            let questionConfig = TextSizeMeasure.Config(
                restrictingWidth: contentMaxWidth,
                maximumNumberOfLines: 0,
                font: pollAppearance.questionTextStyle.font,
                lastFragmentUsedRect: false
            )
            let questionSize = TextSizeMeasure.calculateSize(of: pollViewModel.question, config: questionConfig).textSize
            height += ceil(questionSize.height)

            // Spacing between question and type label
            height += Layout.questionTypeLabelSpacing
            
            // Type label height
            let typeConfig = TextSizeMeasure.Config(
                restrictingWidth: contentMaxWidth,
                maximumNumberOfLines: 0,
                font: pollAppearance.pollTypeTextStyle.font,
                lastFragmentUsedRect: false
            )
            let typeSize = TextSizeMeasure.calculateSize(of: pollViewModel.pollTypeText, config: typeConfig).textSize
            height += ceil(typeSize.height)

            // Spacing before options
            height += Layout.typeOptionsSpacing

            // Options height
            for (index, option) in pollViewModel.options.enumerated() {
                let optionSize = PollOptionView.measure(
                    option: option,
                    appearance: pollAppearance,
                    maxWidth: contentMaxWidth,
                    isClosed: pollViewModel.closed
                )
                height += optionSize.height
                if index < pollViewModel.options.count - 1 {
                    height += Layout.optionSpacing
                }
            }

            return CGSize(width: Components.messageLayoutModel.defaults.messageWidth, height: ceil(height))
        }
    }
 }
