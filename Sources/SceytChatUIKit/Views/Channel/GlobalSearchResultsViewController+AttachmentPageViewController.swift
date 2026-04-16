//
//  GlobalSearchResultsViewController+AttachmentPageViewController.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

extension GlobalSearchResultsViewController {

    open class AttachmentPageViewController: ViewController {
        open var noItemsMessage: String? {
            didSet { emptyStateView.title = noItemsMessage }
        }
        open var noItemsMessageSubTitle: String? {
            didSet { emptyStateView.message = noItemsMessageSubTitle }
        }
        open var noItemsIcon: UIImage? {
            didSet { emptyStateView.icon = noItemsIcon }
        }

        open lazy var emptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        override open func setupLayout() {
            super.setupLayout()
            view.addSubview(emptyStateView)
            emptyStateView.pin(to: view, anchors: [.centerX, .centerY, .leading(16, .greaterThanOrEqual)])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            view.backgroundColor = .background
        }

        /// Override in subclasses to return the scroll views whose bottom inset should track keyboard + user bar height.
        open var scrollViewsToAdjust: [UIScrollView] { [] }

        open func embedAttachmentView(_ attachmentView: UIView) {
            view.insertSubview(attachmentView.withoutAutoresizingMask, belowSubview: emptyStateView)
            attachmentView.pin(to: view)
            emptyStateView.isHidden = true
        }

        open func updateEmptyState() {
            // Override in subclasses if needed
        }

        override open func setupDone() {
            super.setupDone()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillChangeFrame(_:)),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
            )
        }

        override open func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let inset = ChannelTablePageViewController.currentKeyboardInset + GlobalSearchUserBarView.Layouts.height
            scrollViewsToAdjust.forEach {
                $0.contentInset.bottom = inset
                $0.verticalScrollIndicatorInsets.bottom = inset
            }
        }

        @objc private func keyboardWillChangeFrame(_ notification: Notification) {
            guard
                let info = notification.userInfo,
                let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
                isViewLoaded, let window = view.window
            else { return }

            let keyboardFrameInView = window.convert(endFrame, to: view)
            let overlap = max(0, view.bounds.maxY - keyboardFrameInView.minY)
            let safeBottom = view.safeAreaInsets.bottom
            let inset = max(0, overlap - safeBottom)

            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                let bottomInset = inset + GlobalSearchUserBarView.Layouts.height
                self.scrollViewsToAdjust.forEach {
                    $0.contentInset.bottom = bottomInset
                    $0.verticalScrollIndicatorInsets.bottom = bottomInset
                }
            }
        }
    }

}
