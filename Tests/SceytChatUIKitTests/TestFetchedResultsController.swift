//
//  TestFetchedResultsController.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import CoreData
import Foundation

/// A test stub for `NSFetchedResultsController<ChecksumDTO>` that lets unit tests:
/// - Verify whether `performFetch()` was called (via `test_performFetchCalled`).
/// - Inject the result of `fetchedObjects` (via `test_fetchedObjects`).
///
/// `NSFetchedResultsController` is an Objective-C generic class, so the subclass must
/// bind the result type to a concrete entity — we use `ChecksumDTO` because it has no
/// required fields or relationships and is therefore the cheapest entity to instantiate
/// in tests.
///
/// Inject this type into `LazyDBObserver` by passing it as
/// `fetchedResultsControllerType:` on init.
final class TestFetchedResultsController: NSFetchedResultsController<ChecksumDTO> {
    var test_performFetchCalled = false
    var test_fetchedObjects: [ChecksumDTO]?

    override func performFetch() throws {
        test_performFetchCalled = true
    }

    override var fetchedObjects: [ChecksumDTO]? {
        test_fetchedObjects
    }
}

/// Same as `TestFetchedResultsController` but bound to `ChannelDTO`. Used by the
/// `ChannelListViewModelTests` to inject arbitrary channel snapshots (including
/// id-duplicates that the Core Data uniqueness constraint would otherwise reject
/// on save) into the observer.
final class ChannelTestFetchedResultsController: NSFetchedResultsController<ChannelDTO> {
    var test_performFetchCalled = false
    var test_fetchedObjects: [ChannelDTO]?

    override func performFetch() throws {
        test_performFetchCalled = true
    }

    override var fetchedObjects: [ChannelDTO]? {
        test_fetchedObjects
    }
}
