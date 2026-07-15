//
//  JoinGroupViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine
import SceytChat

open class JoinGroupViewController: ViewController {
    
    public var joinGroupViewModel: JoinGroupViewModel!
    private var subscriptions = Set<AnyCancellable>()
    
    open lazy var router = Components.joinGroupRouter
        .init(rootViewController: self)
    
    open lazy var scrollView: UIScrollView = {
        $0.showsVerticalScrollIndicator = false
        $0.showsHorizontalScrollIndicator = false
        return $0.withoutAutoresizingMask
    }(UIScrollView())
    
    open lazy var contentView: UIView = {
        return $0.withoutAutoresizingMask
    }(UIView())
    
    open lazy var stackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .center
        $0.distribution = .fill
        $0.spacing = 12
        return $0.withoutAutoresizingMask
    }(UIStackView())
    
    open lazy var labelsStackView: UIStackView = {
        $0.axis = .vertical
        $0.alignment = .center
        $0.distribution = .fill
        $0.spacing = 2
        return $0.withoutAutoresizingMask
    }(UIStackView())
    
    open lazy var channelAvatarImageView: ImageView = {
        $0.contentMode = .scaleAspectFill
        $0.layer.masksToBounds = true
        $0.backgroundColor = .systemGray5
        return $0.withoutAutoresizingMask
    }(ImageView())
    
    open lazy var channelNameLabel: UILabel = {
        $0.textAlignment = .center
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    open lazy var channelDescriptionLabel: UILabel = {
        $0.textAlignment = .center
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var membersContainerView: UIView = {
        return $0.withoutAutoresizingMask
    }(UIView())

    open lazy var membersStackView: UIStackView = {
        $0.axis = .horizontal
        $0.alignment = .center
        $0.distribution = .fill
        $0.spacing = -8 // Negative spacing for overlapping avatars
        return $0.withoutAutoresizingMask
    }(UIStackView())

    open lazy var memberNamesLabel: UILabel = {
        $0.textAlignment = .center
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var joinButton: UIButton = {
        $0.addTarget(self, action: #selector(joinButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))
    
    open lazy var closeButton: UIButton = {
        $0.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))
    
    open override func setup() {
        super.setup()

        typealias AID = SceytChatUIKit.AccessibilityIdentifiers.JoinGroup
        channelAvatarImageView.accessibilityIdentifier = AID.avatar
        channelNameLabel.accessibilityIdentifier = AID.name
        channelDescriptionLabel.accessibilityIdentifier = AID.description
        joinButton.accessibilityIdentifier = AID.joinButton
        closeButton.accessibilityIdentifier = AID.closeButton

        setupBindings()

        // Update UI with pre-loaded data if available
        if let channel = joinGroupViewModel.channel {
            updateChannelInfo()
            updateMembersDisplay(members: joinGroupViewModel.members)
        }
    }

    private func setupBindings() {
        // Handle loading state and channel availability
        Publishers.CombineLatest(
            joinGroupViewModel.$isLoading,
            joinGroupViewModel.$channel.map { $0 != nil }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isLoading, hasChannel in
            self?.joinButton.isHidden = isLoading || !hasChannel
        }
        .store(in: &subscriptions)

        // Handle joining state
        joinGroupViewModel.$isJoining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isJoining in
                self?.updateJoinButtonState(isJoining: isJoining)
            }
            .store(in: &subscriptions)

        joinGroupViewModel.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &subscriptions)

        // Handle view model events
        joinGroupViewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.onEvent(event)
            }
            .store(in: &subscriptions)

        // Handle members update
        joinGroupViewModel.$members
            .dropFirst() // Skip initial value as we handle it manually in setup()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] members in
                self?.updateMembersDisplay(members: members)
            }
            .store(in: &subscriptions)

        // Handle channel updates
        joinGroupViewModel.$channel
            .compactMap { $0 }
            .dropFirst() // Skip initial value as we handle it manually in setup()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateChannelInfo()
            }
            .store(in: &subscriptions)
    }
    
    open override func setupLayout() {
        super.setupLayout()

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Add labels to labels stack view
        labelsStackView.addArrangedSubview(channelNameLabel)
        labelsStackView.addArrangedSubview(channelDescriptionLabel)

        // Setup members container
        membersContainerView.addSubview(membersStackView)

        let separator = UIView()
        separator.heightAnchor.constraint(equalToConstant: 0).isActive = true
        separator.backgroundColor = .clear
        
        // Add subviews to main stack view
        stackView.addArrangedSubview(channelAvatarImageView)
        stackView.addArrangedSubview(labelsStackView)
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(membersContainerView)
        stackView.addArrangedSubview(memberNamesLabel)

        // Add join button and close button to main view
        view.addSubview(joinButton)
        view.addSubview(closeButton)

        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 33

        // Scroll view constraints
        scrollView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing, .top])

        // Content view constraints
        contentView.pin(to: scrollView, anchors: [.leading, .trailing, .top, .bottom])
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true

        // Stack view constraints
        stackView.pin(to: contentView, anchors: [
            .leading(horizontalPadding),
            .trailing(-horizontalPadding),
            .top(verticalPadding),
            .bottom(-verticalPadding)
        ])

        // Channel avatar constraints
        channelAvatarImageView.widthAnchor.constraint(equalToConstant: 90).isActive = true
        channelAvatarImageView.heightAnchor.constraint(equalToConstant: 90).isActive = true

        // Members stack view constraints
        membersStackView.centerXAnchor.constraint(equalTo: membersContainerView.centerXAnchor).isActive = true
        membersStackView.topAnchor.constraint(equalTo: membersContainerView.topAnchor).isActive = true
        membersStackView.bottomAnchor.constraint(equalTo: membersContainerView.bottomAnchor).isActive = true
        membersStackView.leadingAnchor.constraint(greaterThanOrEqualTo: membersContainerView.leadingAnchor).isActive = true
        membersStackView.trailingAnchor.constraint(lessThanOrEqualTo: membersContainerView.trailingAnchor).isActive = true

        // Members container constraints
        membersContainerView.heightAnchor.constraint(equalToConstant: 40).isActive = true

        // Join button at bottom of view
        joinButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(horizontalPadding), .trailing(-horizontalPadding), .bottom(-horizontalPadding)])
        joinButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        // Scroll view bottom constraint (above join button)
        scrollView.bottomAnchor.constraint(equalTo: joinButton.topAnchor, constant: -horizontalPadding).isActive = true

        // Close button constraints
        closeButton.pin(to: view.safeAreaLayoutGuide, anchors: [.top(12), .trailing(-12)])
        closeButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
        
        // Channel avatar appearance
        channelAvatarImageView.layer.cornerRadius = 45 // Half of 90 for circular avatar
        channelAvatarImageView.layer.borderWidth = appearance.avatarBorderWidth
        channelAvatarImageView.layer.borderColor = appearance.avatarBorderColor?.cgColor
        
        // Channel name label appearance
        let nameAppearance = appearance.channelNameLabelAppearance
        channelNameLabel.font = nameAppearance.font
        channelNameLabel.textColor = nameAppearance.foregroundColor
        channelNameLabel.backgroundColor = nameAppearance.backgroundColor
        
        // Channel description label appearance
        let descriptionAppearance = appearance.channelDescriptionLabelAppearance
        channelDescriptionLabel.font = descriptionAppearance.font
        channelDescriptionLabel.textColor = descriptionAppearance.foregroundColor
        channelDescriptionLabel.backgroundColor = descriptionAppearance.backgroundColor

        // Member names label appearance
        let memberNamesAppearance = appearance.memberNamesLabelAppearance
        memberNamesLabel.font = memberNamesAppearance.font
        memberNamesLabel.textColor = memberNamesAppearance.foregroundColor
        memberNamesLabel.backgroundColor = memberNamesAppearance.backgroundColor

        // Join button appearance
        let buttonAppearance = appearance.joinButtonAppearance
        joinButton.setTitleColor(buttonAppearance.labelAppearance.foregroundColor, for: .normal)
        joinButton.backgroundColor = buttonAppearance.backgroundColor
        joinButton.layer.cornerRadius = buttonAppearance.cornerRadius
        joinButton.layer.cornerCurve = buttonAppearance.cornerCurve
        joinButton.titleLabel?.font = buttonAppearance.labelAppearance.font
        joinButton.tintColor = buttonAppearance.tintColor
        
        // Close button appearance
        closeButton.setImage(.closeIcon, for: .normal)
        closeButton.tintColor = appearance.closeButtonTintColor
        closeButton.backgroundColor = appearance.closeButtonBackgroundColor
        closeButton.layer.cornerRadius = 14
    }
    
    private func updateJoinButtonState(isJoining: Bool) {
        if isJoining {
            joinButton.setTitle(appearance.joiningButtonTitle, for: .normal)
            joinButton.isEnabled = false
            joinButton.alpha = 0.6
        } else {
            joinButton.setTitle(appearance.joinButtonTitle, for: .normal)
            joinButton.isEnabled = true
            joinButton.alpha = 1.0
        }
    }
    
    private func updateChannelInfo() {
        guard let channel = joinGroupViewModel.channel else { return }
        
        // Set channel name
        channelNameLabel.text = channel.subject
        
        // Set default channel description
        channelDescriptionLabel.text = appearance.defaultChannelDescription
        channelDescriptionLabel.isHidden = false
        
        // Load and set channel avatar
        loadChannelAvatar(channel: channel)
    }
    
    private func loadChannelAvatar(channel: ChatChannel) {
        // Use the appearance avatar renderer to load the channel avatar
        appearance.avatarRenderer.render(
            channel,
            with: appearance.avatarAppearance,
            into: channelAvatarImageView,
            size: CGSize(width: 90, height: 90)
        )
    }
    
    // MARK: Actions
    
    @objc open func joinButtonTapped() {
        joinGroupViewModel.joinChannel()
    }
    
    @objc open func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: Error Handling

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return SceytChatError.networkConnection.rawValue == nsError.code
    }

    private func handleError(_ error: Error) {
        if isNetworkError(error) {
            // Show network error alert with Try Again option
            let cancelAction = SheetAction(title: L10n.Alert.Button.cancel, icon: nil, style: .cancel) { [weak self] in
                self?.dismiss(animated: true)
            }

            let tryAgainAction = SheetAction(title: L10n.Connection.tryAgain, icon: nil, style: .default) { [weak self] in
                self?.joinGroupViewModel.joinChannel()
            }

            showAlert(
                title: L10n.Connection.Error.networkLost,
                message: L10n.Connection.Error.Try.again,
                actions: [cancelAction, tryAgainAction],
                preferredActionIndex: 1,
                completion: nil
            )
        } else {
            // Show default error alert
            let cancelAction = SheetAction(title: L10n.Alert.Button.cancel, icon: nil, style: .cancel) { [weak self] in
                if self?.joinGroupViewModel.shouldDismissOnError == true {
                    self?.dismiss(animated: true)
                }
            }
            showAlert(title: L10n.Alert.Error.title, message: error.localizedDescription, actions: [cancelAction], preferredActionIndex: 0, completion: nil)
        }
    }

    // MARK: ViewModel Events
    
    open func onEvent(_ event: JoinGroupViewModel.Event) {
        switch event {
        case .channelLoaded(let channel):
            updateChannelInfo()
        case .joinedChannel(let channel):
            router.showChannel(channel)
        }
    }

    // MARK: Members Display

    private func updateMembersDisplay(members: [ChatChannelMember]) {
        // Clear existing avatars
        membersStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Hide members display if no members
        guard !members.isEmpty else {
            membersContainerView.isHidden = true
            memberNamesLabel.isHidden = true
            return
        }

        membersContainerView.isHidden = false
        memberNamesLabel.isHidden = false

        // Show first 2 members' avatars
        let displayLimit = 2
        let membersToDisplay = Array(members.prefix(displayLimit))
        let membersCount = Int(joinGroupViewModel.channel?.memberCount ?? Int64(members.count))
        let remainingCount = max(0, membersCount - displayLimit)

        for member in membersToDisplay {
            let avatarView = createMemberAvatarView(for: member)
            membersStackView.addArrangedSubview(avatarView)
        }

        // Add "+X more" label if there are more members
        if remainingCount > 0 {
            let moreLabel = createMoreLabel(count: remainingCount)
            membersStackView.addArrangedSubview(moreLabel)
        }

        // Update member names label
        memberNamesLabel.text = formatMemberNames(members: members)
    }

    private func createMemberAvatarView(for member: ChatChannelMember) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let imageView = CircleImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .backgroundSecondary
        imageView.layer.borderWidth = appearance.memberAvatarBorderWidth
        imageView.layer.borderColor = appearance.memberAvatarBorderColor.cgColor

        containerView.addSubview(imageView)
        imageView.pin(to: containerView)

        // Set size constraints
        containerView.widthAnchor.constraint(equalToConstant: appearance.memberAvatarSize).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: appearance.memberAvatarSize).isActive = true

        // Load avatar using the renderer
        appearance.memberAvatarRenderer.render(
            member,
            with: appearance.memberAvatarAppearance,
            into: imageView.imageView
        )

        return containerView
    }

    private func createMoreLabel(count: Int) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = UIView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = appearance.moreLabelBackgroundColor
        backgroundView.layer.cornerRadius = appearance.memberAvatarSize / 2
        backgroundView.layer.borderWidth = appearance.memberAvatarBorderWidth
        backgroundView.layer.borderColor = appearance.memberAvatarBorderColor.cgColor

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "+\(count)"
        label.font = appearance.moreLabelAppearance.font
        label.textColor = appearance.moreLabelAppearance.foregroundColor
        label.textAlignment = .center

        containerView.addSubview(backgroundView)
        backgroundView.addSubview(label)

        backgroundView.pin(to: containerView)
        label.pin(to: backgroundView)

        containerView.widthAnchor.constraint(equalToConstant: appearance.memberAvatarSize).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: appearance.memberAvatarSize).isActive = true

        return containerView
    }

    private func formatMemberNames(members: [ChatChannelMember]) -> String {
        guard !members.isEmpty else { return "" }

        let displayLimit = 3
        let namesToDisplay = Array(members.prefix(displayLimit))
        let membersCount = Int(joinGroupViewModel.channel?.memberCount ?? Int64(members.count))
        let remainingCount = max(0, membersCount - displayLimit)

        let names = namesToDisplay.compactMap { member -> String? in
            if let firstName = member.firstName, !firstName.isEmpty {
                return firstName
            }
            return nil
        }

        var result = names.joined(separator: ", ")

        if remainingCount > 0 {
            let othersText = remainingCount == 1 ? L10n.JoinGroup.Members.oneOther : L10n.JoinGroup.Members.others(remainingCount)
            result = names.isEmpty ? othersText : L10n.JoinGroup.Members.format(result, othersText)
        }

        return result
    }
}
