import Foundation
import SceytChatUIKit

final class MessagesObserverMock: LazyMessagesObserver {

    var onLoaded: (([MessageDTO]) -> Void)?

    override func startObserver(
        fetchOffset: Int = 0,
        fetchLimit: Int = 0,
        fetchPredicate: NSPredicate? = nil,
        completion: (() -> Void)? = nil
    ) {
        super.startObserver(
            fetchOffset: fetchOffset,
            fetchLimit: fetchLimit,
            fetchPredicate: fetchPredicate,
            completion: {
                self.perform {
                    let request = MessageDTO.fetchRequest()
                    request.sortDescriptors = self.sortDescriptors
                    request.predicate = fetchPredicate ?? self.fetchPredicate
                    request.fetchLimit = fetchLimit
                    request.fetchOffset = fetchOffset

                    let loaded = MessageDTO.fetch(request: request, context: self.context)
                    self.onLoaded?(loaded)
                    completion?()
                }
            }
        )
    }

    override func load(
        from offset: Int,
        limit: Int,
        predicate: NSPredicate? = nil,
        done: (() -> Void)? = nil
    ) {
        self.perform {
            let request = MessageDTO.fetchRequest()
            request.sortDescriptors = self.sortDescriptors
            request.predicate = predicate ?? self.fetchPredicate
            request.fetchLimit = limit
            request.fetchOffset = offset

            let loaded = MessageDTO.fetch(request: request, context: self.context)
            self.onLoaded?(loaded)
            done?()
        }
    }

    func setObserverStarted(_ value: Bool) {

    }

    private func queue( _ block: @escaping () -> Void) {
        if Thread.isMainThread {
            if eventQueue.label == "com.apple.main-thread" {
                block()
                return
            }
        }
        eventQueue.async {
            block()
        }
    }

    private func perform( _ block: @escaping () -> Void) {
        if Thread.isMainThread {
            if context === viewContext {
                context.performAndWait {
                    block()
                }
                return
            }
        }
        context.perform {
            block()
        }
    }

}
