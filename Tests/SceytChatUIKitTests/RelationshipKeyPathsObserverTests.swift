//
//  RelationshipKeyPathsObserverTests.swift
//  SceytChatUIKitTests
//

@testable import SceytChatUIKit
import CoreData
import XCTest

final class RelationshipKeyPathsObserverTests: XCTestCase {

    /// Regression test for a production SIGSEGV (objc_destructInstance on a freed
    /// address, TestFlight 8.3.15): `contextDidChangeNotification` runs synchronously
    /// on whichever context queue posts NSManagedObjectContextObjectsDidChange (the
    /// observer registers with object: nil), and used to mutate `updatedObjectIDs`
    /// right there — racing both with other posting contexts and with
    /// `contextDidSaveNotification` on the FRC queue, over-releasing the Set's CoW
    /// storage. Run under Thread Sanitizer: the pre-fix code is flagged within a few
    /// iterations. The fix serializes every touch of the set on the FRC context queue.
    func test_concurrentSavesFromMultipleContexts_doNotRaceOnUpdatedObjectIDs() throws {
        let database = MockDatabase()
        let container = database.container

        let workerCount = 4
        let iterations = 100

        // One channel + lastMessage pair per worker so concurrent saves never touch
        // the same row — a merge conflict would abort the save and with it the
        // didChange/didSave notification traffic this test needs to generate.
        var messageIDs: [NSManagedObjectID] = []
        let seedContext = container.newBackgroundContext()
        seedContext.performAndWait {
            for i in 0..<workerCount {
                let channel = NSEntityDescription.insertNewObject(
                    forEntityName: "ChannelDTO", into: seedContext) as! ChannelDTO
                channel.id = Int64(i + 1)
                channel.type = "group"
                channel.subject = "channel-\(i)"
                channel.createdAt = Date().bridgeDate
                let message = NSEntityDescription.insertNewObject(
                    forEntityName: "MessageDTO", into: seedContext) as! MessageDTO
                message.id = Int64(i + 1)
                message.channelId = channel.id
                // ChannelDTO.willSave() derives sortingKey from lastMessage.createdAt,
                // and sortingKey carries its own uniqueness constraint — identical
                // message dates would collapse every channel onto one sortingKey.
                message.createdAt = Date(timeIntervalSince1970: TimeInterval(i + 1)).bridgeDate
                channel.lastMessage = message
            }
            try! seedContext.save()
            messageIDs = seedContext.registeredObjects.compactMap { ($0 as? MessageDTO)?.objectID }
        }
        XCTAssertEqual(messageIDs.count, workerCount)

        // Same setup as ChannelListViewModel: FRC on a background context observing
        // ChannelDTO, with a keypath through the lastMessage relationship.
        let frcContext = container.newBackgroundContext()
        let request = NSFetchRequest<ChannelDTO>(entityName: "ChannelDTO")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        request.entity = NSEntityDescription.entity(forEntityName: "ChannelDTO", in: frcContext)
        let frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: frcContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        let observer = try XCTUnwrap(RelationshipKeyPathsObserver(
            keyPaths: [#keyPath(ChannelDTO.lastMessage.deliveryStatus)],
            fetchedResultsController: frc
        ))
        frcContext.performAndWait { try! frc.performFetch() }

        // Hammer the observer from independent context queues the way parallel
        // channel/message sync writes do in production. Every save() posts
        // ObjectsDidChange (handler runs inline on the worker's queue, and the
        // changed deliveryStatus resolves through lastMessageChannel to a channel
        // objectID) followed by DidSave (handler runs on the FRC queue).
        let group = DispatchGroup()
        for messageID in messageIDs {
            group.enter()
            DispatchQueue.global().async {
                let ctx = container.newBackgroundContext()
                ctx.performAndWait {
                    let message = try! ctx.existingObject(with: messageID) as! MessageDTO
                    for i in 1...iterations {
                        message.deliveryStatus = Int16(i % 3)
                        try! ctx.save()
                    }
                }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 60), .success, "workers hung")

        // Drain the FRC queue so every enqueued set mutation has executed while the
        // observer is still alive.
        frcContext.performAndWait {}
        _ = observer
    }
}
