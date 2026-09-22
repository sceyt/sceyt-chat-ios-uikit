//
//  PollOptionDetailViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

open class PollOptionDetailViewController: ViewController,
                                            UITableViewDelegate,
                                            UITableViewDataSource {

    open var viewModel: PollOptionDetailViewModel!
    open lazy var router = Components.pollOptionDetailRouter.init(rootViewController: self)
    private var subscriptions = Set<AnyCancellable>()

    open lazy var tableView = UITableView(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension

    open lazy var loadingFooterView: UIView = {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 60))
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .gray
        activityIndicator.startAnimating()
        footerView.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
        return footerView
    }()

    open override func setup() {
        super.setup()

        title = viewModel.option.text

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.contentInset = .init(top: 20, left: 0, bottom: 0, right: 0)
        tableView.register(VoteCountInfoCell.self)
        tableView.register(PollResultsViewController.VoterCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollOptionDetail.tableView

        let footer = UIView()
        footer.frame.size.height = .leastNormalMagnitude
        tableView.tableFooterView = footer

        setupBindings()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        // Load first page of voters
        viewModel.loadNext()
    }

    private func setupBindings() {
        // Handle loading state - show/hide footer loading indicator
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.tableView.tableFooterView = self.loadingFooterView
                } else {
                    // Reset to empty footer when not loading
                    let footer = UIView()
                    footer.frame.size.height = .leastNormalMagnitude
                    self.tableView.tableFooterView = footer
                }
            }
            .store(in: &subscriptions)

        // Handle errors
        viewModel.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(error: error)
            }
            .store(in: &subscriptions)
        
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.onEvent(event)
            }
            .store(in: &subscriptions)

        // Reload table when option changes
        viewModel.$option
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &subscriptions)

        // Reload table when poll details change (new voters loaded)
        viewModel.$pollDetails
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
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
        // Section 0: All voters only
        return 1
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // First cell is vote count info, rest are voters
        return viewModel.numberOfVoters + 1
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // First cell shows vote count info
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: VoteCountInfoCell.self)
            cell.parentAppearance = appearance.voteCountInfoCellAppearance
            cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollOptionDetail.voteCountCell
            let voteCount = viewModel.pollDetails.votesPerOption[viewModel.option.id] ?? 0
            let voteCountText = SceytChatUIKit.shared.formatters.voteCountFormatter.format(voteCount)
            cell.configure(text: voteCountText)
            return cell
        }

        // Rest are voter cells
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: PollResultsViewController.VoterCell.self)
        cell.parentAppearance = appearance.voterCellAppearance
        cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollOptionDetail.voterCell

        if let voter = viewModel.voter(at: indexPath.row - 1) {
            cell.data = voter
        }

        return cell
    }

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // All sections have minimal header
        return .leastNormalMagnitude
    }

    open func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // No headers needed
        return nil
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Skip the first cell (vote count info cell)
        guard indexPath.row > 0 else { return }

        // This is a voter cell, show user profile
        let voterIndex = indexPath.row - 1
        if let voter = viewModel.voter(at: voterIndex), let user = voter.user {
            router.showProfile(user: user)
        }
    }

    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        let cornerRadius = PollResultsViewController.Layouts.cellCornerRadius
        var corners: UIRectCorner = []

        if tableView.isFirst(indexPath) {
            corners.update(with: .topLeft)
            corners.update(with: .topRight)
        }

        if tableView.isLast(indexPath) {
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
            layer.borderWidth = PollResultsViewController.Layouts.cellSeparatorWidth

            // Calculate separator inset
            let separatorWidthInset: CGFloat = PollResultsViewController.Layouts.cellHorizontalPadding + 12

            layer.frame = CGRect(
                x: separatorWidthInset,
                y: cell.height - layer.borderWidth,
                width: cell.width - separatorWidthInset * 2,
                height: layer.borderWidth
            )
        }

        let maskLayer = CAShapeLayer()
        var rect = cell.bounds
        rect.origin.x = PollResultsViewController.Layouts.cellHorizontalPadding
        rect.size.width -= PollResultsViewController.Layouts.cellHorizontalPadding * 2
        maskLayer.path = UIBezierPath(roundedRect: rect,
                                      byRoundingCorners: corners,
                                      cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
        cell.layer.mask = maskLayer

        // Load more voters when approaching the end
        // Skip the first cell (vote count info cell)
        let voterIndex = indexPath.row - 1
        if voterIndex >= 0 {
            let remainingVoters = viewModel.numberOfVoters - voterIndex
            if remainingVoters <= 5, viewModel.hasMore {
                viewModel.loadNext()
            }
        }
    }
    
    open func onEvent(_ event: PollOptionDetailViewModel.Event) {
        switch event {
        case .reloadData:
            tableView.reloadData()
        default:
            break
        }
    }

    // MARK: Actions

    @objc open func closeTapped() {
        dismiss(animated: true)
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
