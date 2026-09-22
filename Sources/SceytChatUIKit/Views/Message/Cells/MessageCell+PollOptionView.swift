//
//  MessageCell+PollOptionView.swift
//  SceytChatUIKit
//
//  Created by Vahagn Manasyan on 02.11.25.
//

import UIKit

extension MessageCell {
    open class PollOptionView: View, MessageCellMeasurable {

        /// `accessibilityValue` of an option the current user's vote sits on.
        public static let votedAccessibilityValue = "voted"
        /// `accessibilityValue` of an option the current user has not voted for.
        public static let notVotedAccessibilityValue = "not_voted"

        // MARK: - UI Components
        open lazy var checkboxView = {
            $0.contentInsets = .zero
            return $0.withoutAutoresizingMask
        }(Components.checkBoxView.init())
        
        open lazy var optionLabel: UILabel = {
            let label = UILabel()
            label.textColor = .label
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            return label.withoutAutoresizingMask
        }()
        
        open lazy var votersContainerView: UIView = {
            let view = UIView()
            view.isUserInteractionEnabled = true
            return view.withoutAutoresizingMask
        }()
        
        open lazy var votersStackView: UIStackView = {
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.distribution = .fillEqually
            stack.spacing = -8.0
            return stack.withoutAutoresizingMask
        }()
        
        open lazy var voteCountLabel: UILabel = {
            let label = UILabel()
            label.textColor = .label
            label.textAlignment = .right
            return label.withoutAutoresizingMask
        }()
        
        open lazy var progressBar: UIProgressView = {
            let progress = UIProgressView(progressViewStyle: .default)
            progress.layer.cornerRadius = 3
            progress.clipsToBounds = true
            return progress.withoutAutoresizingMask
        }()
        
        private var optionLabelLeadingConstraint: NSLayoutConstraint?
        private var avatarViews: [UIView] = []
        /// Set by `updateViewModel` for the single `configure()` pass it triggers,
        /// so a freshly-added voter's avatar pops in instead of appearing abruptly.
        private var animatesVoterAvatarsOnNextConfigure = false
        /// Identifies the in-flight vote-count animation, so the completion of a
        /// superseded one leaves the label to whichever update owns it now.
        private var voteCountAnimation = 0

        open var onAvatarsTapped: (() -> Void)?
        open var onOptionTapped: (() -> Void)?

        open var viewModel: PollOptionViewModel? {
            didSet {
                configure()
            }
        }

        open lazy var appearance: PollViewAppearance = Components.messageCell.appearance.pollViewAppearance {
            didSet {
                setupAppearance()
            }
        }
        
        private var currentBorderColor: UIColor {
            let messageApperance = Components.messageCell.appearance
            return viewModel?.isIncoming == true ? messageApperance.incomingBubbleColor : messageApperance.outgoingBubbleColor
        }
        
        // MARK: Setup
        
        open override func setup() {
            super.setup()
            // `CheckBoxView` toggles its own `isSelected` on touch, and nothing here
            // listens for that — a tap landing on the radio would fill it in without
            // a vote being cast, which then sticks for as long as the app has no
            // reason to re-render the row (a rejected or in-flight vote). The row's
            // tap gesture is the only thing allowed to move this state, exactly as
            // in the other model-driven check boxes (`SelectableUserCell`,
            // `SelectableChannelCell`, the media picker cell). Taps still reach the
            // row, so the radio remains a valid place to press.
            checkboxView.isUserInteractionEnabled = false
            addSubview(checkboxView)
            addSubview(optionLabel)
            addSubview(votersContainerView)
            votersContainerView.addSubview(votersStackView)
            votersContainerView.addSubview(voteCountLabel)
            addSubview(progressBar)
            
//            let cornerRadius = appearance.progressBarCornerRadius
            progressBar.layer.cornerRadius = 3.0
            progressBar.clipsToBounds = true
            progressBar.subviews.forEach { subview in
//                subview.layer.cornerRadius = cornerRadius
                subview.clipsToBounds = true
            }

            // Add tap gesture to voters container view
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarsTapped(_:)))
            votersContainerView.addGestureRecognizer(tapGesture)
        }
        
        open override func setupLayout() {
            checkboxView.leadingAnchor.pin(to: leadingAnchor)
            checkboxView.topAnchor.pin(to: topAnchor)
            checkboxView.resize(anchors: [.width(appearance.checkboxStyle.size), .height(appearance.checkboxStyle.size)])
            
            optionLabel.topAnchor.pin(to: topAnchor)
            optionLabelLeadingConstraint = optionLabel.leadingAnchor.pin(to: checkboxView.trailingAnchor, constant: 8.0)
            optionLabel.trailingAnchor.pin(to: votersContainerView.leadingAnchor, constant: -8.0)

            votersContainerView.trailingAnchor.pin(to: trailingAnchor)
            votersContainerView.topAnchor.pin(to: topAnchor)
            votersContainerView.widthAnchor.pin(constant: 50.0)
            votersContainerView.heightAnchor.pin(greaterThanOrEqualToConstant: appearance.voterAvatarStyle.size)

            votersStackView.centerYAnchor.pin(to: votersContainerView.centerYAnchor)
            votersStackView.trailingAnchor.pin(lessThanOrEqualTo: voteCountLabel.leadingAnchor, constant: -1.5)

            voteCountLabel.trailingAnchor.pin(to: votersContainerView.trailingAnchor)
            voteCountLabel.centerYAnchor.pin(to: votersContainerView.centerYAnchor)
            voteCountLabel.widthAnchor.pin(greaterThanOrEqualToConstant: 10.0)
            voteCountLabel.contentHuggingPriorityH(.required)

            progressBar.leadingAnchor.pin(to: optionLabel.leadingAnchor)
            progressBar.trailingAnchor.pin(to: trailingAnchor)
            progressBar.topAnchor.pin(to: optionLabel.bottomAnchor, constant: 8.0)
            progressBar.heightAnchor.pin(constant: 6.0)
            progressBar.bottomAnchor.pin(to: bottomAnchor)
        }

        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = .clear
            votersContainerView.backgroundColor = .clear
            
            optionLabel.font = appearance.optionTextStyle.font
            optionLabel.textColor = appearance.optionTextStyle.foregroundColor
            
            voteCountLabel.font = appearance.voteCountTextStyle.font
            voteCountLabel.textColor = appearance.voteCountTextStyle.foregroundColor

            progressBar.trackTintColor = appearance.progressBarForeground
            progressBar.progressTintColor = appearance.progressBarBackground
        }

        @objc private func avatarsTapped(_ sender: UITapGestureRecognizer) {
            guard let viewModel = viewModel else {
                return
            }

            if viewModel.isAnonymous {
                // For anonymous polls, treat avatar tap like option tap (vote/unvote)
                onOptionTapped?()
            } else {
                // For non-anonymous polls, show results
                onAvatarsTapped?()
            }
        }

        // MARK: Configuration
        func configure() {
            guard let viewModel else {
                return
            }

            voteCountLabel.text = String(viewModel.voteCount)
            optionLabel.text = viewModel.text
            progressBar.setProgress(viewModel.progress, animated: false)
            checkboxView.isSelected = viewModel.isSelected
            checkboxView.isHidden = viewModel.isClosed
            // Exposes the rendered vote state to assistive tech and to UI tests.
            // Deliberately assigned right next to `checkboxView.isSelected`, so it
            // travels the same code path the user-visible checkbox does — a test
            // reading it sees exactly what is on screen, stale updates included.
            accessibilityValue = viewModel.isSelected
                ? PollOptionView.votedAccessibilityValue
                : PollOptionView.notVotedAccessibilityValue
            votersStackView.isHidden = viewModel.isAnonymous

            // Update option label leading constraint when checkbox is hidden
            optionLabelLeadingConstraint?.isActive = false
            if viewModel.isClosed {
                optionLabelLeadingConstraint = optionLabel.leadingAnchor.pin(to: leadingAnchor)
            } else {
                optionLabelLeadingConstraint = optionLabel.leadingAnchor.pin(to: checkboxView.trailingAnchor, constant: 8.0)
            }

            votersStackView.removeArrangedSubviews()
            avatarViews.removeAll()
            if !viewModel.isAnonymous {
                createVoterAvatars(voters: viewModel.voters,
                                   appearance: appearance,
                                   animated: animatesVoterAvatarsOnNextConfigure)
            }
            animatesVoterAvatarsOnNextConfigure = false
        }

        /// Animate progress bar with a nice scale effect
        func animateProgressBarOnVote() {
            // Scale up animation
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut], animations: {
                self.progressBar.transform = CGAffineTransform(scaleX: 1.0, y: 1.3)
            }) { _ in
                // Scale back to normal
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseInOut]) {
                    self.progressBar.transform = .identity
                }
            }
        }

        /// Update view model with animations.
        ///
        /// The new model is adopted *before* anything animates, so `configure()`
        /// renders it in full right away. Nothing that runs later may write state
        /// derived from `newViewModel`: an animation started here can still be in
        /// flight when the next update lands (voting, then changing that vote a
        /// moment later, is a couple of hundred milliseconds of work), and a
        /// completion block holding the older model would put the row back to a
        /// state the user has already moved on from — e.g. re-checking the option
        /// they just switched away from, so a single-choice poll ends up showing
        /// two votes. Completions below therefore only ever read the *current*
        /// `viewModel`, and each animation is superseded by the next one.
        func updateViewModel(_ newViewModel: PollOptionViewModel) {
            guard let oldViewModel = viewModel else {
                viewModel = newViewModel
                return
            }

            let oldVoteCount = oldViewModel.voteCount
            let oldProgress = oldViewModel.progress
            // Animate the avatar in only when this option gains exactly one vote
            // (0->1, 1->2, …); `configure()` consumes the flag as it rebuilds them.
            animatesVoterAvatarsOnNextConfigure =
                (newViewModel.voteCount == oldVoteCount + 1) && !newViewModel.isAnonymous

            viewModel = newViewModel

            if oldVoteCount != newViewModel.voteCount {
                animateVoteCountChange(increasing: newViewModel.voteCount > oldVoteCount,
                                       from: oldVoteCount)
            }
            if oldProgress != newViewModel.progress {
                animateProgressChange(from: oldProgress, to: newViewModel.progress)
            }
        }

        /// Slides the old vote count out and the new one in. `configure()` has
        /// already put the new count on screen, so the label is rewound to
        /// `oldCount` for the exit leg; the entering text is read back from the
        /// current view model, which may by then be newer than the count that
        /// started this animation.
        private func animateVoteCountChange(increasing: Bool, from oldCount: Int) {
            let translationDistance: CGFloat = 12.0
            let exitTransform = CGAffineTransform(translationX: 0, y: increasing ? -translationDistance : translationDistance)
            let enterTransform = CGAffineTransform(translationX: 0, y: increasing ? translationDistance : -translationDistance)

            voteCountAnimation += 1
            let animation = voteCountAnimation

            voteCountLabel.text = String(oldCount)
            voteCountLabel.transform = .identity
            voteCountLabel.alpha = 1.0

            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
                self.voteCountLabel.transform = exitTransform
                self.voteCountLabel.alpha = 0.0
            }) { _ in
                // A newer update already owns the label; it will finish the job.
                guard animation == self.voteCountAnimation else { return }

                self.voteCountLabel.text = String(self.viewModel?.voteCount ?? oldCount)
                self.voteCountLabel.transform = enterTransform
                self.voteCountLabel.alpha = 0.0

                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: [.curveEaseOut]) {
                    self.voteCountLabel.transform = .identity
                    self.voteCountLabel.alpha = 1.0
                }
            }
        }

        /// Fills the bar from the previous share of the votes to the new one.
        /// `configure()` has already set the new progress, so the bar is rewound
        /// (outside the animation) and then animated forward again.
        private func animateProgressChange(from oldProgress: Float, to newProgress: Float) {
            progressBar.setProgress(oldProgress, animated: false)
            progressBar.layoutIfNeeded()

            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
                self.progressBar.setProgress(newProgress, animated: false)
                self.progressBar.layoutIfNeeded()
            }
        }

        private func createVoterAvatars(voters: [ChatUser], appearance: PollViewAppearance, animated: Bool = false) {
            votersStackView.spacing = appearance.voterAvatarStyle.spacing

            // Sort voters: current user first, then others
            guard let currentUserId = SceytChatUIKit.shared.currentUserId else {
                return
            }

            let sortedVoters = voters.sorted { voter1, voter2 in
                let isCurrent1 = voter1.id == currentUserId
                let isCurrent2 = voter2.id == currentUserId
                if isCurrent1 && !isCurrent2 {
                    return true
                } else if !isCurrent1 && isCurrent2 {
                    return false
                }
                return false
            }

            // Add voter avatars (limit to 3 for display)
            let avatarCount = min(sortedVoters.count, 3)
            let scale = UIScreen.main.traitCollection.displayScale
            let avatarSize = CGSize(
                width: appearance.voterAvatarStyle.size * scale,
                height: appearance.voterAvatarStyle.size * scale
            )

            let borderColor = currentBorderColor
            for voter in sortedVoters.suffix(avatarCount).reversed() {
                // Create container view for border effect
                let containerView = UIView()
                containerView.backgroundColor = borderColor
                containerView.layer.cornerRadius = appearance.voterAvatarStyle.size / 2
                containerView.clipsToBounds = true
                containerView.translatesAutoresizingMaskIntoConstraints = false
                containerView.widthAnchor.constraint(equalToConstant: appearance.voterAvatarStyle.size).isActive = true
                containerView.heightAnchor.constraint(equalToConstant: appearance.voterAvatarStyle.size).isActive = true
                
                // Create avatar view inside container
                let avatarView = SceytImageView()
                avatarView.contentMode = .scaleAspectFill
                avatarView.backgroundColor = UIColor.background
                avatarView.clipsToBounds = true
                avatarView.translatesAutoresizingMaskIntoConstraints = false
                
                let avatarInset = appearance.voterAvatarStyle.borderWidth
                let innerSize = appearance.voterAvatarStyle.size - (avatarInset * 2)
                avatarView.layer.cornerRadius = innerSize / 2
                
                containerView.addSubview(avatarView)
                avatarView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
                avatarView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
                avatarView.widthAnchor.constraint(equalToConstant: innerSize).isActive = true
                avatarView.heightAnchor.constraint(equalToConstant: innerSize).isActive = true

                // Get avatar appearance from user avatar provider
                let avatarRepresentation = SceytChatUIKit.shared.visualProviders.userAvatarProvider.provideVisual(for: voter)
                let initialsAppearance: InitialsBuilderAppearance? = {
                    if case .initialsAppearance(let appearance) = avatarRepresentation {
                        return appearance
                    }
                    return nil
                }()
                let defaultImage: UIImage? = {
                    if case .image(let image) = avatarRepresentation {
                        return image
                    }
                    return nil
                }()

                // Load avatar using AvatarBuilder
                _ = Components.avatarBuilder.loadAvatar(
                    into: avatarView,
                    for: voter,
                    appearance: initialsAppearance,
                    defaultImage: defaultImage,
                    size: avatarSize
                )
                votersStackView.addArrangedSubview(containerView)
                avatarViews.append(containerView)

                // Animate avatar appearance if requested
                if animated {
                    // Start with small scale and invisible
                    containerView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                    containerView.alpha = 0.0

                    // Animate to full size with spring effect
                    UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
                        containerView.transform = .identity
                        containerView.alpha = 1.0
                    }
                }
            }
        }
        
        // MARK: - Measurement
        
        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            // This method is required by MessageCellMeasurable but not used directly
            // Use measure(option:appearance:maxWidth:) instead
            return .zero
        }
        
        open class func measure(
            option: PollOptionViewModel,
            appearance: PollViewAppearance,
            maxWidth: CGFloat,
            isClosed: Bool
        ) -> CGSize {
            let pollAppearance = appearance
            var height: CGFloat = 0

            // Checkbox height (if not closed)
            if !isClosed {
                height = max(height, pollAppearance.checkboxStyle.size)
            }

            // Calculate option text width
            // Available width: maxWidth - checkbox (if visible) - spacing - spacing - voters container
            let checkboxWidth: CGFloat = isClosed ? 0 : pollAppearance.checkboxStyle.size
            let spacingAfterCheckbox: CGFloat = 8.0
            let spacingBeforeVoters: CGFloat = 8.0
            let votersContainerWidth = 50.0
            let availableTextWidth = maxWidth - checkboxWidth - spacingAfterCheckbox - spacingBeforeVoters - votersContainerWidth

            // Option text height
            let optionConfig = TextSizeMeasure.Config(
                restrictingWidth: availableTextWidth,
                maximumNumberOfLines: 0,
                font: pollAppearance.optionTextStyle.font,
                lastFragmentUsedRect: false
            )

            let optionTextSize = TextSizeMeasure.calculateSize(of: option.text, config: optionConfig).textSize
            let textHeight = ceil(optionTextSize.height)

            // Total option height: max of checkbox height or text height, plus spacing and progress bar
            let spacingBetweenTextAndProgress: CGFloat = textHeight > checkboxWidth ? 8.0 : 4.0
            let progressBarHeight: CGFloat = 6
            let minHeight = max(checkboxWidth > 0 ? pollAppearance.checkboxStyle.size : 0, textHeight) + spacingBetweenTextAndProgress + progressBarHeight
            return CGSize(width: maxWidth, height: minHeight)
        }
    }
}
