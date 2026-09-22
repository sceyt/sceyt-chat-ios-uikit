//
//  MessageSendTrace.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Logging for the outgoing-message failure paths — the places where a send does *not* resolve
/// normally and the local row is left saying something other than the truth.
///
/// Every line starts with `[SEND-TRACE]` so a report about a stuck or wrongly-failed message can
/// be pulled out of a device log with one filter, and carries the message `tid`, which is the only
/// identifier that exists for the whole lifetime of a message — the server id only appears with
/// the ack, and a lost ack is exactly what these lines are about.
///
/// Deliberately narrow: the happy path is already covered by the surrounding `logger` calls, and
/// anything that fires per message or per marker was removed after the investigation that
/// introduced this (see `PendingSendReconciler`).
public enum MessageSendTrace {

    /// Set to `false` to silence the trace without removing the call sites.
    public static var isEnabled = true

    // MARK: - Emitting

    public static func log(
        _ event: String,
        tid: Int64? = nil,
        channelId: ChannelId? = nil,
        messageId: MessageId? = nil,
        _ detail: @autoclosure () -> String = "",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        logger.info(
            format(event, tid: tid, channelId: channelId, messageId: messageId, detail()),
            file: file, function: function, line: line
        )
    }

    public static func error(
        _ event: String,
        tid: Int64? = nil,
        channelId: ChannelId? = nil,
        messageId: MessageId? = nil,
        _ detail: @autoclosure () -> String = "",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        logger.error(
            format(event, tid: tid, channelId: channelId, messageId: messageId, detail()),
            file: file, function: function, line: line
        )
    }

    /// Emits at the level the outcome actually deserves.
    ///
    /// A transport failure (offline, timeout — see `SceytChatError.isTransport`) is routine on a
    /// bad link: the row stays pending and either the reconnect resend or `PendingSendReconciler`
    /// picks it up, so it is informational, not an error. Anything else is a refusal the message
    /// cannot recover from on its own — and so is a non-final status with **no error at all**,
    /// which nothing will ever retry.
    public static func outcome(
        _ event: String,
        tid: Int64? = nil,
        channelId: ChannelId? = nil,
        messageId: MessageId? = nil,
        error: Error?,
        _ detail: @autoclosure () -> String = "",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        let text = format(event, tid: tid, channelId: channelId, messageId: messageId, detail())
        if error?.sceytChatCode?.isTransport == true {
            logger.info(text, file: file, function: function, line: line)
        } else {
            logger.error(text, file: file, function: function, line: line)
        }
    }

    private static func format(
        _ event: String,
        tid: Int64?,
        channelId: ChannelId?,
        messageId: MessageId?,
        _ detail: String
    ) -> String {
        var parts = ["[SEND-TRACE]", event]
        if let tid { parts.append("tid=\(tid)") }
        if let messageId, messageId != 0 { parts.append("id=\(messageId)") }
        if let channelId { parts.append("cid=\(channelId)") }
        parts.append("conn=\(SceytChatUIKit.shared.chatClient.connectionState.description)")
        if !detail.isEmpty { parts.append(detail) }
        return parts.joined(separator: " ")
    }

    // MARK: - Formatting

    /// The parts of an ack that decide what happens next: is there a message at all, what status
    /// did the SDK put on it, and did it come back with a server id. `id == 0` is the tell that
    /// the payload never came from the server.
    public static func describe(ack message: Message?) -> String {
        guard let message else { return "ack=nil" }
        return "ack=(id=\(message.id) tid=\(message.tid) status=\(message.deliveryStatus) incoming=\(message.incoming))"
    }

    /// Both error identities matter: `sceytChatCode` classifies transport failures (see
    /// `SceytChatError.isTransport`), while `sdkError.isResendable` is what the retry loop
    /// consults — and it is `nil` for anything that isn't a `SceytError`, which is what a timed-out
    /// request on a slow link produces.
    public static func describe(error: Error?) -> String {
        guard let error else { return "error=nil" }
        let nsError = error as NSError
        let sdk = error.sdkError
        return "error=(code=\(nsError.code)"
            + " domain=\(nsError.domain)"
            + " sceytCode=\(error.sceytChatCode.map { "\($0)" } ?? "unmapped")"
            + " sdkType=\(sdk?.rawValue ?? "nonSceytError")"
            + " resendable=\(sdk.map { "\($0.isResendable)" } ?? "unknown")"
            + " desc=\(error.localizedDescription))"
    }

    public static func describe(dto: MessageDTO?) -> String {
        guard let dto else { return "dto=nil" }
        let status = ChatMessage.DeliveryStatus(rawValue: Int(dto.deliveryStatus))
            .map { "\($0)" } ?? "raw(\(dto.deliveryStatus))"
        return "dto=(id=\(dto.id) tid=\(dto.tid) status=\(status) state=\(dto.state))"
    }
}
