//
//  SceytChatUIKit.swift
//
//
//  Created by Arthur Avagyan on 07.08.24.
//

import Foundation
import SceytChat

public class SceytChatUIKit {
    
    private init() {}
    
    public static let shared = SceytChatUIKit()
    
    public lazy var config = SceytChatUIKit.Config()
    public var theme = SceytChatUIKit.Theme()
    public var formatters = SceytChatUIKit.Formatters()
    public var visualProviders = SceytChatUIKit.VisualProviders()
    public var avatarRenderers = SceytChatUIKit.AvatarRenderers()
    
    public var chatClient: ChatClient {
        ChatClient.shared
    }
    
    public var database: Database {
        return _database
    }

    private lazy var _database: Database = {
        if let directory = config.storageConfig.databaseFileDirectory {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("Error creating directory: \(error.localizedDescription)")
            }
            let dbUrl = directory.appendingPathComponent(config.storageConfig.databaseFilename)
            return PersistentContainer(storeType: .sqLite(databaseFileUrl: dbUrl))
        } else {
            return PersistentContainer(storeType: .inMemory)
        }
    }()

    /// Sidecar FTS5 index over message bodies, used by `GlobalSearchMessagesViewModel`.
    /// Lives beside the Core Data file (or in-memory when the main store is in-memory).
    public lazy var messageSearchStore: MessageSearchStore = {
        let store: MessageSearchStore
        if let directory = config.storageConfig.databaseFileDirectory {
            let url = directory.appendingPathComponent("\(config.storageConfig.databaseFilename)-fts.sqlite")
            store = MessageSearchStore(url: url)
        } else {
            store = MessageSearchStore.inMemory()
        }
        store.open()
        return store
    }()

    public static func initialize(apiUrl: String, appId: String, clientId: String = "", chatClientOnly: Bool = false) {
        ChatClient.initialize(apiUrl: apiUrl, appId: appId, clientId: clientId)
        if !chatClientOnly {
            SceytChatUIKit.shared.chatClient.add(delegate: Components.clientConnectionHandler.default, identifier: String(reflecting: ClientConnectionHandler.self))
            shared.channelEventHandler.startEventHandler()
            shared.runMessageSearchBackfillIfNeeded()
        }
    }
    
    public var isConnected: Bool {
        chatClient.connectionState == .connected
    }
    
    public func connect(token: String) {
        chatClient.connect(token: token)
    }
    
    public func reconnect() -> Bool {
        chatClient.reconnect()
    }
    
    public func disconnect() {
        chatClient.disconnect()
    }
    
    public func registerDevicePushToken(_ pushToken: Data, completion: ((Error?) -> Void)?) {
        chatClient.registerDevicePushToken(pushToken, completion: completion)
    }
    
    public func unregisterDevicePushToken(completion: ((Error?) -> Void)? ) {
        chatClient.unregisterDevicePushToken(completion: completion)
    }
    
    public func logout(completion: @escaping (Bool) -> Void) {
        unregisterDevicePushToken() { [weak self] error in
            if let error {
                logger.debug("Device Token: Received error while removing \(error)")
                completion(false)
            }

            logger.debug("Device Token: Removed")
            self?.disconnect()
            UserDefaults.currentUserId = nil
            UserDefaults.ftsBackfillVersion = 0
            self?.messageSearchStore.clear()
            DataProvider.database.deleteAll()
            completion(true)
        }
    }

    /// Builds (or rebuilds) the FTS index from `MessageDTO` when the on-disk
    /// schema version is older than `MessageSearchStore.schemaVersion`. Runs on
    /// a background queue so it never blocks app launch.
    private func runMessageSearchBackfillIfNeeded() {
        let target = MessageSearchStore.schemaVersion
        guard UserDefaults.ftsBackfillVersion < target else { return }

        // Touch lazy properties on the calling thread so the persistent store
        // is loaded before we move to a background queue.
        let database = self.database
        let store = messageSearchStore

        DispatchQueue.global(qos: .utility).async {
            store.clear()

            // Resolve channelId → channelType once. Needed so FTS rows can be
            // filtered by channel category without joining back to Core Data.
            var channelTypeById: [Int64: String] = [:]
            switch database.read({ context -> [Int64: String] in
                let request = ChannelDTO.fetchRequest()
                let dtos = try context.fetch(request)
                return Dictionary(uniqueKeysWithValues: dtos.map { ($0.id, $0.type) })
            }) {
            case .success(let map):
                channelTypeById = map
            case .failure(let error):
                logger.errorIfNotNil(error, "FTS backfill: channels read failed")
                return
            }

            let pageSize = 1000
            var lastId: Int64 = 0
            var didFail = false

            backfill: while true {
                let result = database.read { context -> [MessageSearchStore.Row] in
                    let request = MessageDTO.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "id > %lld", lastId),
                        NSPredicate(format: "state != 2"),
                        NSPredicate(format: "transient == NO"),
                        NSPredicate(format: "body.length > 0")
                    ])
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageDTO.id, ascending: true)]
                    request.fetchLimit = pageSize
                    let dtos = try context.fetch(request)
                    return dtos.compactMap { dto -> MessageSearchStore.Row? in
                        guard dto.id > 0,
                              let userId = dto.user?.id,
                              !userId.isEmpty
                        else { return nil }
                        return MessageSearchStore.Row(
                            messageId: dto.id,
                            channelId: dto.channelId,
                            channelType: channelTypeById[dto.channelId] ?? "",
                            userId: userId,
                            createdAt: dto.createdAt.timeIntervalSince1970,
                            body: dto.body
                        )
                    }
                }
                switch result {
                case .success(let rows):
                    if rows.isEmpty { break backfill }
                    store.index(rows: rows)
                    if let last = rows.last?.messageId, last > lastId {
                        lastId = last
                    } else {
                        break backfill
                    }
                    if rows.count < pageSize { break backfill }
                case .failure(let error):
                    logger.errorIfNotNil(error, "FTS backfill: page read failed")
                    didFail = true
                    break backfill
                }
            }

            if !didFail {
                UserDefaults.ftsBackfillVersion = target
                logger.debug("FTS backfill: completed at version \(target)")
            }
        }
    }
    
    public lazy var channelEventHandler: ChannelEventHandler = {
        Components.channelEventHandler
            .init(
                database: database,
                chatClient: chatClient
            )
    }()
    
    public var currentUserId: UserId? {
        let userId = SceytChatUIKit.shared.chatClient.user.id
        if !userId.isEmpty {
            return userId
        } else {
            return UserDefaults.currentUserId
        }
    }
    
    // MARK: - Log Level
    
    /// Configures the logging system by setting the log level for both the SDK's `ChatClient` and the UIKit's `Logger`.
    ///
    /// - Parameters:
    ///   - level: The desired log level, specified using `Logger.LogLevel`.
    ///   - callback: A closure that will be invoked every time a log message is generated by the UIKit's `Logger`.
    ///     - Logger.CallBack parameters:
    ///       - logMessage: The fully formatted log message, including timestamps and contextual information.
    ///       - logLevel: The level of the log message (`Logger.LogLevel`).
    ///       - logString: The original log string provided by the caller.
    ///       - file: The file from which the log function was called.
    ///       - function: The function from which the log function was called.
    ///       - line: The line number from which the log function was called.
    public func setLogger(with level: Logger.LogLevel, callback: @escaping Logger.CallBack) {
        // Set the log level for the SDK's ChatClient using the mapped `sceytLogLevel`.
        ChatClient.setLogLevel(level.sceytLogLevel)
        
        // Set the log level and assign the callback for the UIKit's Logger.
        Logger.setLogLevel(level, callBack: callback)
    }
}
