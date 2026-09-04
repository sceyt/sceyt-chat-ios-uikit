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
    
    public static func initialize(apiUrl: String, appId: String, clientId: String = "", chatClientOnly: Bool = false) {
        ChatClient.initialize(apiUrl: apiUrl, appId: appId, clientId: clientId)
        if !chatClientOnly {
            SceytChatUIKit.shared.chatClient.add(delegate: Components.clientConnectionHandler.default, identifier: String(reflecting: ClientConnectionHandler.self))
            shared.channelEventHandler.startEventHandler()
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
            DataProvider.database.deleteAll()
            completion(true)
        }
    }
    
    public lazy var channelEventHandler: ChannelEventHandler = {
        Components.channelEventHandler
            .init(
                database: database,
                chatClient: chatClient
            )
    }()
    
    /// The id of the signed-in user.
    ///
    /// A *connected* chat client is authoritative. A disconnected one is not:
    /// it keeps reporting the user it last connected as until it reconnects, so
    /// during an account switch it still names the outgoing account for as long
    /// as the new account's login round-trip takes. In that window the value
    /// the host app declared via `setCurrentUserId(_:)` is the correct one.
    ///
    /// Falling back to the live id last keeps this self-healing: an account
    /// transition that forgets to declare is wrong only until the client
    /// connects, never permanently.
    ///
    /// The connection state is consulted *last*, and only when the two ids
    /// actually disagree. This is a fast path, not a change of meaning — the
    /// value is identical to asking first in every case:
    ///
    /// - nothing declared: the live id, either way;
    /// - declared == live: that id, either way;
    /// - declared != live (an account switch in flight, or a client that has
    ///   not reconnected as the incoming user): the connection state decides,
    ///   exactly as before.
    ///
    /// Ordering matters because `connectionState` is the one expensive term
    /// here: it crosses into the native client, which logs a line per call at
    /// `.info`. This property backs `ChatChannel.peer` and every marker,
    /// reaction and poll-vote ownership test, so it is read several times per
    /// cell bind — asking first put those reads on every frame of a list
    /// scroll, for an answer that almost never depended on them.
    public var currentUserId: UserId? {
        Self.resolveCurrentUserId(
            live: SceytChatUIKit.shared.chatClient.user.id,
            declared: UserDefaults.currentUserId,
            isConnected: SceytChatUIKit.shared.chatClient.connectionState == .connected
        )
    }

    /// The decision behind ``currentUserId``, split out so it can be tested
    /// exhaustively against the ordering it replaced.
    ///
    /// `isConnected` is an autoclosure precisely so the fast paths can skip it:
    /// evaluating it is the expensive part, and the whole point of the ordering
    /// is that the answer rarely depends on it.
    static func resolveCurrentUserId(
        live liveUserId: UserId,
        declared declaredUserId: UserId?,
        isConnected: @autoclosure () -> Bool
    ) -> UserId? {
        guard let declaredUserId, !declaredUserId.isEmpty
        else { return liveUserId.isEmpty ? nil : liveUserId }

        if declaredUserId == liveUserId {
            return liveUserId
        }

        // The ids disagree, so who is authoritative finally matters: only a
        // connected client outranks what the host app declared.
        if !liveUserId.isEmpty, isConnected() {
            return liveUserId
        }
        return declaredUserId
    }
    
    /// Declares which user the host app has bound its UI to.
    ///
    /// Call this the moment the app rebinds to a different account, *before*
    /// anything renders the new account's data — the chat client cannot be
    /// asked, because it goes on reporting the previous user until it
    /// reconnects. Everything the UIKit resolves against the signed-in user
    /// reads `currentUserId`: a direct channel's peer (and so its name and its
    /// avatar), message marker and reaction ownership, poll vote attribution,
    /// and the mention-list predicate.
    ///
    /// Pass `nil` to forget the declared id; `logout(completion:)` already does.
    public func setCurrentUserId(_ userId: UserId?) {
        UserDefaults.currentUserId = userId
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
