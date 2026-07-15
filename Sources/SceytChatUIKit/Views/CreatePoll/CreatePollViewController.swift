//
//  CreatePollViewController.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine

open class CreatePollViewController: ViewController,
                                      UITableViewDelegate,
                                      UITableViewDataSource,
                                      UIAdaptivePresentationControllerDelegate {

    open var viewModel: CreatePollViewModel!
    open var onPollCreated: ((CreatePollModel) -> Void)?
    private var subscriptions = Set<AnyCancellable>()
    
    private var shouldShowAddOptionCell: Bool {
        viewModel.canAddMoreOptions
    }

    open lazy var tableView = UITableView(frame: .zero, style: .grouped)
        .withoutAutoresizingMask
        .rowAutomaticDimension

    private lazy var questionHeaderLabel: UILabel = {
        $0.font = .systemFont(ofSize: 14, weight: .regular)
        $0.textColor = .secondaryText
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    private lazy var optionsHeaderLabel: UILabel = {
        $0.font = .systemFont(ofSize: 14, weight: .regular)
        $0.textColor = .secondaryText
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    private lazy var parametersHeaderLabel: UILabel = {
        $0.font = .systemFont(ofSize: 14, weight: .regular)
        $0.textColor = .secondaryText
        $0.numberOfLines = 0
        return $0.withoutAutoresizingMask
    }(UILabel())

    open override func setup() {
        super.setup()
        
        viewModel.maxOptionsCount = appearance.maxOptionsCount

        title = appearance.titleText
        questionHeaderLabel.text = appearance.questionDescriptionText
        optionsHeaderLabel.text = appearance.optionsHeaderText
        parametersHeaderLabel.text = appearance.parametersHeaderText

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.register(QuestionFieldCell.self)
        tableView.register(OptionFieldCell.self)
        tableView.register(SwitchOptionCell.self)
        tableView.register(AddOptionCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .interactive
        tableView.isEditing = true
        tableView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.tableView

        let footer = UIView()
        footer.frame.size.height = .leastNormalMagnitude
        tableView.tableFooterView = footer

        navigationController?.presentationController?.delegate = self
        setupNavigationBarItems()
        setupBindings()

        KeyboardObserver()
            .willShow { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }.willHide { [weak self] in
                self?.adjustTableViewToKeyboard(notification: $0)
            }
    }

    private func setupNavigationBarItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: appearance.cancelText,
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.cancelButton

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: appearance.createText,
            style: .done,
            target: self,
            action: #selector(createTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.createButton

        updateCreateButtonState()
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

        // Handle poll changes to update create button
        viewModel.$poll
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCreateButtonState()
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
        return 3
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Question field
        case 1: return viewModel.poll.options.count + (shouldShowAddOptionCell ? 1 : 0) // Options + Add button
        case 2: return 2 // 2 switch cells for parameters
        default: return 0
        }
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: QuestionFieldCell.self)
            cell.parentAppearance = appearance.questionFieldCellAppearance
            cell.textView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.questionField
            cell.textView.text = viewModel.poll.question
            cell.placeholderLabel.text = appearance.questionPlaceholderText
            cell.updatePlaceholderVisibility()
            cell.onTextChanged = { [weak self] text in
                self?.viewModel.updateQuestion(text)
            }
            cell.onHeightChanged = { [weak self] in
                self?.updateQuestionCellHeight()
            }
            cell.onReturnKeyPressed = { [weak self] in
                self?.handleQuestionReturnKeyPressed()
            }
            return cell

        case 1:
            if indexPath.row < viewModel.poll.options.count {
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: OptionFieldCell.self)
                cell.parentAppearance = appearance.optionFieldCellAppearance
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.optionCell
                cell.textView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.optionField
                cell.textView.text = viewModel.poll.options[indexPath.row]
                cell.placeholderLabel.text = appearance.optionPlaceholderText(indexPath.row + 1)
                cell.updatePlaceholderVisibility()

                // Configure return key type
                let isLastOption = indexPath.row == viewModel.poll.options.count - 1
                cell.textView.returnKeyType = (isLastOption && !viewModel.canAddMoreOptions) ? .done : .next

                cell.onTextChanged = { [weak self] text in
                    self?.viewModel.updateOption(at: indexPath.row, value: text)
                }
                cell.onHeightChanged = { [weak self] in
                    self?.updateOptionCellHeight(at: indexPath)
                }
                cell.onReturnKeyPressed = { [weak self] in
                    guard let self = self,
                          let currentIndexPath = self.tableView.indexPath(for: cell) else { return }
                    self.handleReturnKeyPressed(at: currentIndexPath)
                }
                cell.onDeleteWhenEmpty = { [weak self] in
                    guard let self = self,
                          let currentIndexPath = self.tableView.indexPath(for: cell) else { return }
                    self.handleDeleteOption(at: currentIndexPath)
                }
                cell.backgroundColor = CreatePollViewController.OptionFieldCell.appearance.containerBackgroundColor
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: AddOptionCell.self)
                cell.parentAppearance = appearance.addOptionCellAppearance
                cell.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.addOptionButton
                cell.iconView.image = .messageActionMoreReactions
                cell.titleLabel.text = appearance.addOptionText
                cell.onTapped = { [weak self] in
                    self?.addOption()
                }
                return cell
            }

        case 2:
            let cell = tableView.dequeueReusableCell(for: indexPath, cellType: SwitchOptionCell.self)
            cell.parentAppearance = appearance.switchOptionCellAppearance
            switch indexPath.row {
            case 0:
                cell.titleLabel.text = appearance.showVoterNamesText
                cell.switchControl.isOn = viewModel.poll.isAnonymous
                cell.switchControl.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.anonymousSwitch
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.viewModel.updateShowVoterNames(isOn)
                }
            case 1:
                cell.titleLabel.text = appearance.allowMultipleAnswersText
                cell.switchControl.isOn = viewModel.poll.allowMultipleAnswers
                cell.switchControl.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.CreatePoll.multipleAnswersSwitch
                cell.onSwitchChanged = { [weak self] isOn in
                    self?.viewModel.updateAllowMultipleAnswers(isOn)
                }
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
    }

    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0, 1, 2:
            return UITableView.automaticDimension
        default:
            return .leastNormalMagnitude
        }
    }

    open func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0, 1, 2:
            return 44
        default:
            return .leastNormalMagnitude
        }
    }

    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let padding = CreatePollViewController.Layouts.cellHorizontalPadding + 16
        switch section {
        case 0: // Question section
            let container = UIView()
            container.addSubview(questionHeaderLabel)
            questionHeaderLabel.pin(to: container, anchors: [.leading(padding), .trailing(-padding), .top(8), .bottom(-8)])
            return container
        case 1: // Options section
            let container = UIView()
            container.addSubview(optionsHeaderLabel)
            optionsHeaderLabel.pin(to: container, anchors: [.leading(padding), .trailing(-padding), .top(8), .bottom(-8)])
            return container
        case 2: // Parameters section
            let container = UIView()
            container.addSubview(parametersHeaderLabel)
            parametersHeaderLabel.pin(to: container, anchors: [.leading(padding), .trailing(-padding), .top(8), .bottom(-8)])
            return container
        default:
            return nil
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

    // MARK: - Reordering

    open func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        // Don't show delete button, only reorder control
        return .none
    }

    open func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        // Don't indent when editing (removes space for delete button)
        return false
    }

    open func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Only allow reordering for options section (not the "Add option" row)
        return indexPath.section == 1 && indexPath.row < viewModel.poll.options.count
    }

    open func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Only handle moves within the options section
        guard sourceIndexPath.section == 1 && destinationIndexPath.section == 1 else { return }

        // Don't allow moving to the "Add option" row
        let maxRow = viewModel.poll.options.count - 1
        let finalDestination = min(destinationIndexPath.row, maxRow)

        viewModel.moveOption(from: sourceIndexPath.row, to: finalDestination)
        
        self.tableView.reloadData()
    }

    open func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Prevent moving to other sections
        guard proposedDestinationIndexPath.section == 1 else {
            return sourceIndexPath
        }

        // Prevent moving to the "Add option" row
        if proposedDestinationIndexPath.row >= viewModel.poll.options.count {
            return IndexPath(row: viewModel.poll.options.count - 1, section: 1)
        }

        return proposedDestinationIndexPath
    }

    // MARK: Actions

    @objc open func cancelTapped() {
        dismissWithDiscardCheckIfNeeded()
    }

    @objc open func createTapped() {
        guard viewModel.canCreatePoll else { return }
        let poll = viewModel.poll
        dismiss(animated: true) { [weak self] in
            self?.onPollCreated?(poll)
        }
    }

    @objc open func addOption() {
        viewModel.addOption()
    }

    open func updateCreateButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = viewModel.canCreatePoll
    }

    open func updateQuestionCellHeight() {
        let indexPath = IndexPath(row: 0, section: 0)

        // Get the current cell to preserve text view state
        guard let cell = tableView.cellForRow(at: indexPath) as? QuestionFieldCell else {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
            return
        }

        // Store the current selection range and text
        let selectedRange = cell.textView.selectedRange
        let isFirstResponder = cell.textView.isFirstResponder

        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()

            // Manually trigger willDisplay to update the mask layer
            if let cell = tableView.cellForRow(at: indexPath) {
                tableView(tableView, willDisplay: cell, forRowAt: indexPath)
            }
        }

        // Restore text view state
        if isFirstResponder {
            cell.textView.becomeFirstResponder()
            cell.textView.selectedRange = selectedRange
        }
    }

    open func updateOptionCellHeight(at indexPath: IndexPath) {
        // Get the current cell to preserve text view state
        guard let cell = tableView.cellForRow(at: indexPath) as? OptionFieldCell else {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
            return
        }

        // Store the current selection range and text
        let selectedRange = cell.textView.selectedRange
        let isFirstResponder = cell.textView.isFirstResponder

        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()

            // Manually trigger willDisplay to update the mask layer
            if let cell = tableView.cellForRow(at: indexPath) {
                tableView(tableView, willDisplay: cell, forRowAt: indexPath)
            }
        }

        // Restore text view state
        if isFirstResponder {
            cell.textView.becomeFirstResponder()
            cell.textView.selectedRange = selectedRange
        }
    }

    open func handleQuestionReturnKeyPressed() {
        // Move focus to the first option
        let firstOptionIndexPath = IndexPath(row: 0, section: 1)
        if let firstOptionCell = tableView.cellForRow(at: firstOptionIndexPath) as? OptionFieldCell {
            firstOptionCell.textView.becomeFirstResponder()
        }
    }

    open func handleReturnKeyPressed(at indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }

        let isLastOption = indexPath.row == viewModel.poll.options.count - 1

        if isLastOption {
            // Last option - add new option if possible, otherwise dismiss keyboard
            if viewModel.canAddMoreOptions {
                addOption()
            } else {
                view.endEditing(true)
            }
        } else {
            // Move to next option
            let nextIndexPath = IndexPath(row: indexPath.row + 1, section: 1)
            if let nextCell = tableView.cellForRow(at: nextIndexPath) as? OptionFieldCell {
                nextCell.textView.becomeFirstResponder()
            }
        }
    }

    open func handleDeleteOption(at indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }

        // Only allow deletion if we have more than 2 options
        guard viewModel.poll.options.count > 2 else { return }

        // Determine which option to focus on - focus on the nearest cell
        // If not the first option, focus on the previous one
        // Otherwise, focus on the next one (which will become first after deletion)
        let targetOptionIndex: Int
        if indexPath.row > 0 {
            // Not the first option, focus on previous
            targetOptionIndex = indexPath.row - 1
        } else {
            // First option, focus on next (will become first after deletion)
            targetOptionIndex = indexPath.row + 1
        }
        let targetIndexPath = IndexPath(row: targetOptionIndex, section: 1)

        // Focus on the target cell before deletion
        if let targetCell = tableView.cellForRow(at: targetIndexPath) as? OptionFieldCell {
            targetCell.textView.becomeFirstResponder()
        }

        // Remove the option (this will trigger the .removeOption event which handles animation)
        viewModel.removeOption(at: indexPath.row)
    }

    // MARK: - Keyboard Handling

    open func adjustTableViewToKeyboard(notification: Notification) {
        tableView.adjustInsetsToKeyboard(notification: notification, container: view)
    }

    // MARK: - Content Validation

    open func hasUnsavedContent() -> Bool {
        // Check if question is not empty
        if !viewModel.poll.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        // Check if any option is not empty
        return viewModel.poll.options.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    open func dismissWithDiscardCheckIfNeeded() {
        if hasUnsavedContent() {
            showDiscardAlert { [weak self] shouldDiscard in
                if shouldDiscard {
                    self?.dismiss(animated: true)
                }
            }
        } else {
            dismiss(animated: true)
        }
    }

    open func showDiscardAlert(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: appearance.discardAlertTitle,
            message: appearance.discardAlertMessage,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: appearance.discardAlertCancelText, style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: appearance.discardAlertDiscardText, style: .destructive) { _ in
            completion(true)
        })

        self.navigationController?.present(alert, animated: true)
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    open func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // User tried to swipe down to dismiss
        dismissWithDiscardCheckIfNeeded()
    }

    open func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // Allow dismiss only if there's no unsaved content
        let unsavedContent = hasUnsavedContent()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if unsavedContent {
                self.showDiscardAlert { [weak self] shouldDiscard in
                    if shouldDiscard {
                        self?.dismiss(animated: true)
                    }
                }
            }
        }
        return !unsavedContent
    }

    // MARK: - ViewModel Events

    open func onEvent(_ event: CreatePollViewModel.Event) {
        switch event {
        case .reloadData:
            tableView.reloadData()
        case .pollCreated:
            break
        case .removeOption(let index):
            let indexPath = IndexPath(row: index, section: 1)

            // Check if we need to show the "Add Option" cell (when going below max)
            // If we now have maxOptionsCount - 1, we just went below the max and AddOption should appear
            let shouldShowAddOptionCell = viewModel.poll.options.count == viewModel.maxOptionsCount - 1

            if shouldShowAddOptionCell {
                // We need to insert the AddOption cell after deleting the option
                let addOptionIndexPath = IndexPath(row: viewModel.poll.options.count, section: 1)
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .automatic)
                tableView.insertRows(at: [addOptionIndexPath], with: .automatic)
                tableView.endUpdates()
            } else {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }

            // Update the return key type of the last cell (it might have changed from .next to .done)
            let lastOptionIndex = viewModel.poll.options.count - 1
            let lastIndexPath = IndexPath(row: lastOptionIndex, section: 1)
            if let lastCell = tableView.cellForRow(at: lastIndexPath) as? OptionFieldCell {
                lastCell.textView.returnKeyType = .done
                lastCell.textView.reloadInputViews()
            }
        case .addOption(let index):
            let indexPath = IndexPath(row: index, section: 1)

            // Update the return key type of the previous last cell (it changes from .done to .next)
            if index > 0 {
                let previousLastIndexPath = IndexPath(row: index - 1, section: 1)
                if let previousLastCell = tableView.cellForRow(at: previousLastIndexPath) as? OptionFieldCell {
                    previousLastCell.textView.returnKeyType = .next
                    previousLastCell.textView.reloadInputViews()
                }
            }

            // Check if we just reached the max and need to remove the "Add Option" cell
            // If we have exactly maxOptionsCount now, the AddOption cell was visible before and should disappear
            let shouldRemoveAddOptionCell = viewModel.poll.options.count == viewModel.maxOptionsCount

            // Insert the new row with animation
            if shouldRemoveAddOptionCell {
                // The AddOption cell is at the same index as the new option will be inserted
                // Deletions are processed before insertions, so we delete it at its current position
                let addOptionIndexPath = IndexPath(row: index, section: 1)
                tableView.beginUpdates()
                tableView.deleteRows(at: [addOptionIndexPath], with: .automatic)
                tableView.insertRows(at: [indexPath], with: .automatic)
                tableView.endUpdates()
            } else {
                tableView.insertRows(at: [indexPath], with: .automatic)
            }

            // Focus on the newly added cell
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let newCell = self.tableView.cellForRow(at: indexPath) as? OptionFieldCell {
                    newCell.textView.becomeFirstResponder()
                }
            }
        }
    }
}

public extension CreatePollViewController {
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
