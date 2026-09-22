//
//  ChannelInviteLinkViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

open class ChannelInviteLinkViewController: ViewController,
                                            UITableViewDelegate,
                                            UITableViewDataSource {

    open var inviteLinkViewModel: ChannelInviteLinkViewModel!
    private var subscriptions = Set<AnyCancellable>()

    open lazy var router = Components.channelInviteLinkRouter
        .init(rootViewController: self)

    open lazy var tableView = UITableView(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension
    
    private lazy var linkDescriptionLabel: UILabel = {
        $0.font = .systemFont(ofSize: 13, weight: .regular)
        $0.textColor = .secondaryText
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    private lazy var messagesDescriptionLabel: UILabel = {
        $0.font = .systemFont(ofSize: 13, weight: .regular)
        $0.textColor = .secondaryText
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open override func setup() {
        super.setup()

        title = appearance.titleText
        linkDescriptionLabel.text = appearance.linkDescriptionText
        messagesDescriptionLabel.text = appearance.messagesDescriptionText

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.register(LinkFieldCell.self)
        tableView.register(ActionCell.self)
        tableView.register(SwitchOptionCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.tableView

        let footer = UIView()
        footer.frame.size.height = .leastNormalMagnitude
        tableView.tableFooterView = footer
        
        setupBindings()
        
        // Fetch the current invite link data. `loadInviteLinkData` re-reads the channel
        // from the DB first, so it always queries with the current invite key even when
        // the channel snapshot handed in from the member list is stale (e.g. the link
        // was reset on a previous visit).
        inviteLinkViewModel.loadInviteLinkData()
    }
    
    private func setupBindings() {
        // Handle loading state
        inviteLinkViewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                loader.isLoading = isLoading
            }
            .store(in: &subscriptions)
        
        // Handle errors
        inviteLinkViewModel.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &subscriptions)
        
        // Handle showPreviousMessages changes
        inviteLinkViewModel.$showPreviousMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Reload the switch cell to update the switch state
                let switchIndexPath = IndexPath(row: 0, section: 1)
                self?.tableView.reloadRows(at: [switchIndexPath], with: .none)
            }
            .store(in: &subscriptions)
        
        // Handle view model events
        inviteLinkViewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.onEvent(event)
            }
            .store(in: &subscriptions)
    }

    open override func setupLayout() {
        super.setupLayout()

        view.addSubview(tableView)
        tableView.pin(to: view.safeAreaLayoutGuide, anchors: [.leading, .trailing])
        tableView.pin(to: view, anchors: [.top, .bottom])
    }

    open override func setupAppearance() {
        super.setupAppearance()

        view.backgroundColor = appearance.backgroundColor
        tableView.backgroundColor = .clear
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { [weak self] _ in
            guard let self else { return }
            self.tableView.reloadData()
        }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Only reload if something that actually affects row layout/appearance changed.
        let layoutAffectingChange =
            previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
            previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass ||
            (previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) ?? false) ||
            previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory

        guard layoutAffectingChange else { return }

        tableView.reloadData()
    }

    // MARK: UITableViewDataSource

    open func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Link field
        case 1: return 1 // Show Previous Messages switch
        case 2: return inviteLinkViewModel.isPublicChannel ? 2 : 3 // Share, Reset Links (if private), Open QR Code
        default: return 0
        }
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: LinkFieldCell.self)
            cell.parentAppearance = appearance.linkFieldCellAppearance
            cell.linkLabel.text = inviteLinkViewModel.inviteLink
            cell.onCopy = { [weak self] in
                self?.copyLink()
            }
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: SwitchOptionCell.self)
            cell.parentAppearance = appearance.switchOptionCellAppearance
            cell.titleLabel.text = appearance.showPreviousMessagesText
            cell.switchControl.isOn = inviteLinkViewModel.showPreviousMessages
            cell.switchControl.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.showMessagesSwitch
            cell.onSwitchChanged = { [weak self] isOn in
                self?.inviteLinkViewModel.updateShowPreviousMessages(isOn)
            }
            return cell

        case 2:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ActionCell.self)
            cell.parentAppearance = appearance.actionCellAppearance
            cell.titleLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.actionTitle
            switch indexPath.row {
            case 0:
                cell.iconView.image = .chatShare
                cell.titleLabel.text = appearance.shareText
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.shareButton
            case 1:
                if !inviteLinkViewModel.isPublicChannel {
                    cell.iconView.image = .refreshIcon
                    cell.titleLabel.text = appearance.resetLinkText
                    cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.resetButton
                } else {
                    cell.iconView.image = .channelProfileQR
                    cell.titleLabel.text = appearance.openQRCodeText
                    cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.qrButton
                }
            case 2:
                cell.iconView.image = .channelProfileQR
                cell.titleLabel.text = appearance.openQRCodeText
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.qrButton
            default:
                break
            }

            return cell

        default:
            return UITableViewCell()
        }
    }

    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 2 {
            switch indexPath.row {
            case 0:
                shareLink()
            case 1:
                if !inviteLinkViewModel.isPublicChannel {
                    showResetLinkAlert()
                } else {
                    router.showQRCode()
                }
            case 2:
                router.showQRCode()
            default:
                break
            }
        }
    }

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 16 : 24
    }

    open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 0, 1: // Link field and Show Previous Messages sections
            return UITableView.automaticDimension
        default:
            return .leastNormalMagnitude
        }
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let padding = ChannelInviteLinkViewController.Layouts.cellHorizontalPadding + 16
        switch section {
        case 0: // Link field section
            let container = UIView()
            container.addSubview(linkDescriptionLabel)
            linkDescriptionLabel.pin(to: container, anchors: [.leading(padding), .trailing(-padding), .top(8), .bottom(0)])
            return container
        case 1: // Show Previous Messages section
            let container = UIView()
            container.addSubview(messagesDescriptionLabel)
            messagesDescriptionLabel.pin(to: container, anchors: [.leading(padding), .trailing(-padding), .top(8), .bottom(0)])
            return container
        default:
            return UIView()
        }
    }

    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        let cornerRadius = Layouts.cellCornerRadius
        var corners: UIRectCorner = []

        if tableView.isFirst(indexPath) {
            corners.update(with: .topLeft)
            corners.update(with: .topRight)
        }

        if tableView.isLast(indexPath)
        {
            corners.update(with: .bottomLeft)
            corners.update(with: .bottomRight)
            cell.layer.sublayers?.first(where: { $0.name == "bottomBorder" })?.removeFromSuperlayer()
        } else {
            var layer: CALayer! = cell.layer.sublayers?.first(where: { $0.name == "bottomBorder" })
            if layer == nil {
                layer = CALayer()
                layer.name = "bottomBorder"
                cell.layer.addSublayer(layer)
            }
            layer.borderColor = appearance.separatorColor.cgColor
            layer.borderWidth = Layouts.cellSeparatorWidth
            layer.frame = CGRect(x: 0, y: cell.height - layer.borderWidth, width: cell.width, height: layer.borderWidth)
        }

        let maskLayer = CAShapeLayer()
        var rect = cell.bounds
        rect.origin.x = Layouts.cellHorizontalPadding
        rect.size.width -= Layouts.cellHorizontalPadding * 2
        maskLayer.path = UIBezierPath(roundedRect: rect,
                                      byRoundingCorners: corners,
                                      cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
        cell.layer.mask = maskLayer
    }

    // MARK: Actions

    @objc open func copyLink() {
        UIPasteboard.general.string = inviteLinkViewModel.inviteLink
        showAlert(message: appearance.linkCopiedText, actions: [.init(title: L10n.Nav.Bar.close, style: .cancel)])
    }

    @objc open func shareLink() {
        guard let link = inviteLinkViewModel.inviteLink else { return }
        let activityViewController = UIActivityViewController(activityItems: [link], applicationActivities: nil)

        // Configure popover for iPad
        if let popover = activityViewController.popoverPresentationController {
            let shareIndexPath = IndexPath(row: 0, section: 2)
            if let cell = tableView.cellForRow(at: shareIndexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                // Fallback to table view if cell is not visible
                popover.sourceView = tableView
                popover.sourceRect = tableView.bounds
                popover.permittedArrowDirections = []
            }
        }

        present(activityViewController, animated: true)
    }
    
    @objc open func showResetLinkAlert() {
        let actions: [SheetAction] = [
            .init(
                title: appearance.cancelText,
                style: .cancel
            ),
            .init(
                title: appearance.resetText,
                style: .destructive,
                handler: { [weak self] in
                    self?.resetLink()
                }
            )
        ]
        
        showAlert(
            title: appearance.resetAlertTitleText,
            message: appearance.resetAlertMessageText,
            actions: actions,
            preferredActionIndex: 1
        )
    }
    
    @objc open func resetLink() {
        inviteLinkViewModel.resetLink()
    }

    // MARK: Error Handling

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return SceytChatError.networkConnection.rawValue == nsError.code
    }

    private func handleError(_ error: Error) {
        if isNetworkError(error) {
            // Show network error alert with Try Again option
            let cancelAction = SheetAction(title: L10n.Alert.Button.cancel, icon: nil, style: .cancel)

            let tryAgainAction = SheetAction(title: L10n.Connection.tryAgain, icon: nil, style: .default) { [weak self] in
                self?.inviteLinkViewModel.loadInviteLinkData()
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
            let cancelAction = SheetAction(title: L10n.Alert.Button.cancel, icon: nil, style: .cancel)
            showAlert(title: L10n.Alert.Error.title, message: error.localizedDescription, actions: [cancelAction], preferredActionIndex: 0, completion: nil)
        }
    }

    // MARK: - ViewModel Events
    
    open func onEvent(_ event: ChannelInviteLinkViewModel.Event) {
        switch event {
        case .reloadData:
            tableView.reloadData()
        }
    }
}

public extension ChannelInviteLinkViewController {
    enum Layouts {
        public static var cellCornerRadius: CGFloat = 10
        public static var cellHorizontalPadding: CGFloat = 12
        public static var cellSeparatorWidth: CGFloat = 1
    }
}

private extension UITableView {
    func isFirst(_ indexPath: IndexPath) -> Bool {
        indexPath.item == 0
    }

    func isLast(_ indexPath: IndexPath) -> Bool {
        indexPath.item == numberOfRows(inSection: indexPath.section) - 1
    }
}
