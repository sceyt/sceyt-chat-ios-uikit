import UIKit
import XCTest
@testable import SceytChatUIKit

final class MediaPreviewPresentationTests: XCTestCase {
    @MainActor
    func testRepeatedTapDoesNotUsePresentedControllerAndCanReopenAfterDismissal() {
        let owner = Presenter()
        let thumbnail = UIImageView()
        owner.view.addSubview(thumbnail)

        XCTAssertTrue(thumbnail.mediaPreviewPresenter() === owner)
        owner.activePresentation = UIViewController()
        XCTAssertNil(thumbnail.mediaPreviewPresenter())
        owner.activePresentation = nil
        XCTAssertTrue(thumbnail.mediaPreviewPresenter() === owner)
    }

    @MainActor
    func testPresentationForwardedToParentBlocksAllThumbnails() {
        let parent = Presenter()
        let child = UIViewController()
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
        let first = UIImageView()
        let second = UIImageView()
        child.view.addSubview(first)
        child.view.addSubview(second)

        XCTAssertTrue(first.mediaPreviewPresenter() === child)
        parent.activePresentation = UIViewController()
        XCTAssertNil(first.mediaPreviewPresenter())
        XCTAssertNil(second.mediaPreviewPresenter())
    }

    @MainActor
    func testExplicitPresenterIsPreservedAndChecked() {
        let presenter = Presenter()
        let thumbnail = UIImageView()
        XCTAssertTrue(thumbnail.mediaPreviewPresenter(from: presenter) === presenter)
        presenter.activePresentation = UIViewController()
        XCTAssertNil(thumbnail.mediaPreviewPresenter(from: presenter))
    }

    @MainActor
    func testPreviewCannotPresentAnotherPreview() {
        let thumbnail = UIImageView()
        XCTAssertNil(thumbnail.mediaPreviewPresenter(from: MediaPreviewerViewController()))
    }

    @MainActor
    func testDetachedThumbnailHasNoPresenter() {
        XCTAssertNil(UIImageView().mediaPreviewPresenter())
    }

    private final class Presenter: UIViewController {
        var activePresentation: UIViewController?
        override var presentedViewController: UIViewController? { activePresentation }
    }
}
