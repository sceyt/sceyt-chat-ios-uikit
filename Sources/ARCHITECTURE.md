# Channel message flow

This guide follows a channel's messages from the SceytChat SDK through the Core Data layer to the message list on screen. Use it to find the owner of each step and the tests that cover it.

## Ownership

| Component | Responsibility |
|---|---|
| [ChannelEventHandler][event-handler] | Registered as the SceytChat `ChannelDelegate` by `SceytChatUIKit.initialize` unless `chatClientOnly` is set. Writes every channel and message event to the database. Apps replace it through `SceytChatUIKit.Components.channelEventHandler`. |
| [ChannelMessageProvider][message-provider] | Loads pages of a channel's history with a SceytChat `MessageListQuery`, stores them, and records which message ID ranges are complete. |
| [PersistentContainer][database] | Implements `Database`. `write` runs on the one shared `backgroundPerformContext`, `performWriteTask` on a new background context per call, and both complete on the main queue by default. Message lists read from `backgroundReadOnlyObservableContext`. |
| [LazyMessagesObserver][messages-observer] on [LazyDatabaseObserver][lazy-observer] | Holds a window of a channel's `MessageDTO` rows, sorted by `createdAt` and `id` and sectioned by `daySectionIdentifier`, and reports each change as index paths. |
| [ChannelViewModel][view-model] | Owns the observer, converts each `MessageDTO` to a `ChatMessage` and its layout model, and publishes changes as `@Published var event`. |
| [ChannelViewController][view-controller] | Applies `ChannelViewModel.Event` values to the message collection view. |

## A message arrives

1. **Write the event.** `ChannelEventHandler.channel(_:didReceive:)` runs one `database.write`. It reads the stored last message ID of the channel, upserts the channel and the message, and calls `updateRanges` from that last message ID to the new one, so the new message joins the complete range at the bottom of the channel. It also advances `ChannelSyncStateDTO.lastSyncedMessageId` when the sync state ended at the previous last message.
2. **Match the stored row.** `createOrUpdate(message:channelId:changedBy:)` finds the row with `MessageDTO.fetchOrCreate`: by server ID first, then, for an outgoing message, by its `tid` in the channel. The pending row that the sender wrote is updated in place rather than duplicated.
3. **Send the received marker.** For an incoming message in a channel where the user has a role, `markReceivedMessageAsReceivedIfNeeded` calls `ChannelOperator.markMessagesAsReceived` and writes the returned markers.
4. **Merge the save.** `write` saves `backgroundPerformContext`, or rolls it back when the block throws so the next write does not save the failed changes. `PersistentContainer.didSave` merges that save into `backgroundReadOnlyObservableContext`. Saves from other contexts reach it through `automaticallyMergesChangesFromParent`.
5. **Diff the window.** On its context's `NSManagedObjectContextObjectsDidChange`, `LazyDatabaseObserver.didChangeObjects` applies the inserted, refreshed, and deleted rows that pass the fetch predicate to its working cache. It calls `onWillChange` on the context's queue and `onDidChange` on `eventQueue`, the main queue by default.
6. **Publish events.** `ChannelViewModel.onWillChangeEvent` builds the events from the working cache on the context's queue; the last one is `.update(paths:)`. `onDidChangeEvent` runs on main and assigns each to `event`. While the app is inactive it publishes one reload event instead.
7. **Update the list.** `ChannelViewController` subscribes to `$event` and handles `.update` in `onEvent`. While a batch update is running it parks the change in `pendingUpdate`. Otherwise it builds a snapshot from the observer with `buildSnapshotFromObserver()`, diffs it against `appliedSnapshot` with `computeDiff`, and applies the diff through `MessagesCollectionView.performUpdates`. That method catches an Objective-C exception from `performBatchUpdates` with `ObjCExceptionCatcher` from the `SceytChatUIKitObjCSupport` target and falls back to `reloadData()`.

The collection view shows the newest message first, while the observer's index paths are oldest first. `uiIndexPath(fromData:)` and `dataIndexPath(fromUI:)` convert between the two; observer reload paths are converted before `computeDiff`.

A change to a related object can also update a row. `LazyMessagesObserver.relationshipKeyPaths` lists one-hop key paths such as `attachments.status`, `user.avatarUrl`, and `pinDetails.isPinned`. When any context changes or inserts an object on one of these paths, the observer remembers the message. After the next save it refreshes that message in its own context, and the refresh arrives in step 5 as a reloaded row.

## Opening a channel and loading history

- **First window.** `ChannelViewModel.startDatabaseObserver` starts the observer at the replied message, the last displayed message, or the channel's last message. `LazyMessagesObserver.startObserver(initialMessageId:lastMessageId:fetchLimit:)` anchors the window at the newest stored message when the start is the last message (`.prev`), and around the start message otherwise (`.near`).
- **List rules.** `LazyMessagesObserver.listPredicate` keeps the channel's messages that are not thread replies, hidden reply-parent stubs (`replied`), `unlisted`, or auto-deleted. A shown row that breaks these rules leaves the list on refresh through `shouldRemoveCachedItem`. A row that is only outside the loaded window stays.
- **Older pages.** `ChannelViewModel.loadPrevMessages(before:)` first widens the observer from the database with `fetchPrevMessagesFromDB(before:)`, then calls `ChannelMessageProvider.loadPrevMessages(before:)`. While connected, the provider retries an empty fetch that failed with a resendable error up to `maxFetchRetryCount` times, with exponential backoff on a global queue. It returns `SceytChatError.queryInProgress` while the query is still loading.
- **Store a page.** `ChannelMessageProvider.store(messages:triggerMessage:completion:)` upserts the page with `database.write`, then merges the page's ID range into the channel's `LoadRangeDTO` rows with `performWriteTask`. It completes only after both writes, because callers such as `LazyMessagesObserver.restartToNear` read the ranges back to build the next window.
- **Restarts.** A restart requested while another is running is queued, and only the latest queued request runs.

## Regression coverage

| Behavior | Tests |
|---|---|
| A failed write completes once with its error and is rolled back | [DatabaseWriteCompletionTests][write-tests] |
| List rules remove a row on refresh, and a row outside the window stays | [LazyMessagesObserverListRuleTests][list-rule-tests], [LazyDatabaseObserverRemoveCachedItemTests][remove-tests] |
| Restarts are queued, the latest wins, and `stopObserver` clears a queued one | [LazyDatabaseObserverRestartTests][restart-tests] |
| Watched key paths are one hop and include the pin fields | [CoreDataMigrationTests][migration-tests]: `testLazyMessagesObserverKeyPaths_areAllResolvableSingleHops`, `testLazyMessagesObserver_watchesThePinDetailsKeyPaths` |
| An updated row keeps its item instance | [LazyDatabaseObserverReusableItemTests][reusable-tests] |
| Snapshot diffs are valid batch updates | [SnapshotDiffTests][diff-tests], [CanReconcileTests][reconcile-tests], [PerformBatchUpdatesIntegrationTests][batch-tests] |

No unit test covers `ChannelEventHandler.channel(_:didReceive:)`, `updateRanges`, or `ChannelMessageProvider.store`. Run one class with `-only-testing:SceytChatUIKitTests/LazyDatabaseObserverRestartTests` added to the test command in the [contributor guide](../CONTRIBUTING.md#make-and-verify-a-change), and check the executed test count.

[event-handler]: SceytChatUIKit/Data%20Providers/ChannelEventHandler.swift
[message-provider]: SceytChatUIKit/Data%20Providers/ChannelMessageProvider.swift
[database]: SceytChatUIKit/Database/Database.swift
[messages-observer]: SceytChatUIKit/Database/Observers/LazyMessagesObserver.swift
[lazy-observer]: SceytChatUIKit/Database/Observers/LazyDatabaseObserver.swift
[view-model]: SceytChatUIKit/ViewModels/Message/ChannelViewModel.swift
[view-controller]: SceytChatUIKit/Views/Message/ChannelViewController.swift
[write-tests]: ../Tests/SceytChatUIKitTests/DatabaseWriteCompletionTests.swift
[list-rule-tests]: ../Tests/SceytChatUIKitTests/LazyMessagesObserverListRuleTests.swift
[remove-tests]: ../Tests/SceytChatUIKitTests/LazyDatabaseObserverRemoveCachedItemTests.swift
[restart-tests]: ../Tests/SceytChatUIKitTests/LazyDatabaseObserverRestartTests.swift
[migration-tests]: ../Tests/SceytChatUIKitTests/CoreDataMigrationTests.swift
[reusable-tests]: ../Tests/SceytChatUIKitTests/LazyDatabaseObserverReusableItemTests.swift
[diff-tests]: ../Tests/SceytChatUIKitTests/SnapshotDiff/SnapshotDiffTests.swift
[reconcile-tests]: ../Tests/SceytChatUIKitTests/CanReconcile/CanReconcileTests.swift
[batch-tests]: ../Tests/SceytChatUIKitTests/CanReconcile/PerformBatchUpdatesIntegrationTests.swift
