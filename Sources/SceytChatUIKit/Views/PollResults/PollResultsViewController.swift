//
//  PollResultsViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine
import SceytChat

open class PollResultsViewController: ViewController,
                                       UITableViewDelegate,
                                       UITableViewDataSource {

    open var viewModel: PollResultsViewModel!
    open lazy var router = Components.pollResultsRouter.init(rootViewController: self)
    private var subscriptions = Set<AnyCancellable>()

    open lazy var tableView = UITableView(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension

    open lazy var closeButton: UIButton = {
        $0.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton(type: .system))

    open override func setup() {
        super.setup()

        title = appearance.titleText

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.contentInset = .init(top: 20, left: 0, bottom: 0, right: 0)
        tableView.register(QuestionCell.self)
        tableView.register(AnswerCell.self)
        tableView.register(VoterCell.self)
        tableView.register(ShowMoreCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollResults.tableView

        let footer = UIView()
        footer.frame.size.height = .leastNormalMagnitude
        tableView.tableFooterView = footer

        setupNavigationBarItems()
        setupBindings()
        viewModel.startDatabaseObserver()
    }

    deinit {
        viewModel.stopDatabaseObserver()
    }

    private func setupNavigationBarItems() {
        closeButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollResults.closeButton
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: closeButton)
    }

    private func setupBindings() {
        // Handle loading state
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                loader.isLoading = isLoading
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

        // Handle view model events
        viewModel.$event
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.onEvent(event)
            }
            .store(in: &subscriptions)

        // Reload table when poll results change
        viewModel.$pollResults
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

        // Close button appearance
        closeButton.setImage(.closeIcon, for: .normal)
        closeButton.tintColor = appearance.closeButtonTintColor
        closeButton.backgroundColor = appearance.closeButtonBackgroundColor
        closeButton.layer.cornerRadius = 14
        closeButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
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
        // Section 0: Question cell
        // Sections 1+: Voter cells for each option (one section per option)
        return 1 + viewModel.numberOfOptions
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // First section shows the question
            return 1
        } else {
            // Other sections show answer cell + voters for that option
            let optionIndex = section - 1
            let voterCount = viewModel.numberOfVoters(for: optionIndex)
            let showMoreCount = viewModel.shouldShowMoreButton(for: optionIndex) ? 1 : 0
            return 1 + voterCount + showMoreCount
        }
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            // Question cell
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: QuestionCell.self)
            cell.parentAppearance = appearance.questionCellAppearance
            cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollResults.questionCell
            cell.configure(questionText: viewModel.pollResults.name)
            return cell
        } else {
            let optionIndex = indexPath.section - 1
            let voterCount = viewModel.numberOfVoters(for: optionIndex)

            if indexPath.row == 0 {
                // Answer cell (first row of each option section)
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: AnswerCell.self)
                cell.parentAppearance = appearance.answerCellAppearance
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollResults.answerCell

                if let option = viewModel.option(at: optionIndex) {
                    let voteCount = viewModel.pollResults.votesPerOption[option.id] ?? 0
                    cell.configure(answerText: option.text, voteCount: voteCount, totalVotes: voteCount)
                }

                return cell
            } else if indexPath.row <= voterCount {
                // Voter cells
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: VoterCell.self)
                cell.parentAppearance = appearance.voterCellAppearance
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollResults.voterCell

                if let option = viewModel.option(at: optionIndex) {
                    let voterIndex = indexPath.row - 1
                    let voters = viewModel.voters(for: optionIndex)
                    if voterIndex < voters.count {
                        cell.data = voters[voterIndex]
                    }
                }

                return cell
            } else {
                // Show More cell (last row when there are more voters)
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: ShowMoreCell.self)
                cell.parentAppearance = appearance.showMoreCellAppearance
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.PollResults.showMoreCell
                cell.configure(text: appearance.showMoreText)
                cell.onShowMoreTapped = { [weak self] in
                    self?.viewModel.showMoreVoters(for: optionIndex)
                }
                return cell
            }
        }
    }

    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Handle "Show More" cell tap
        guard indexPath.section > 0 else { return }

        let optionIndex = indexPath.section - 1
        let voterCount = viewModel.numberOfVoters(for: optionIndex)

        // Check if this is the "Show More" cell
        if indexPath.row == voterCount + 1 {
            viewModel.showMoreVoters(for: optionIndex)
        } else if indexPath.row > 0 && indexPath.row <= voterCount {
            // This is a voter cell, show user profile
            let voterIndex = indexPath.row - 1
            let voters = viewModel.voters(for: optionIndex)
            if voterIndex < voters.count, let user = voters[voterIndex].user {
                router.showProfile(user: user)
            }
        }
    }

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // All sections have minimal header
        return .leastNormalMagnitude
    }

    open func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // No headers needed, everything is shown as cells
        return nil
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
            layer.borderWidth = Layouts.cellSeparatorWidth

            // Calculate separator inset
            let separatorWidthInset: CGFloat = Layouts.cellHorizontalPadding + 16

            layer.frame = CGRect(
                x: separatorWidthInset,
                y: cell.height - layer.borderWidth,
                width: cell.width - separatorWidthInset * 2,
                height: layer.borderWidth
            )
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

    @objc open func closeButtonTapped() {
        dismiss(animated: true)
    }

    // MARK: - ViewModel Events

    open func onEvent(_ event: PollResultsViewModel.Event) {
        switch event {
        case .reloadData:
            tableView.reloadData()
        case .showOptionDetail(let option, let pollDetails, let messageID):
            showOptionDetail(option: option, pollDetails: pollDetails, messageID: messageID)
        case .messageDeleted:
            dismiss(animated: true)
        }
    }

    open func showOptionDetail(option: PollOption, pollDetails: PollDetails, messageID: MessageId) {
        router.showPollOptionDetail(option: option, pollDetails: pollDetails, messageID: messageID)
    }
}

public extension PollResultsViewController {
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
