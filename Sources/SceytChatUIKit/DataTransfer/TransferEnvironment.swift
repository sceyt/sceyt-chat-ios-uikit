//
//  TransferEnvironment.swift
//  SceytChatUIKit
//
//  What the transfer layer works with. Each `AttachmentTransfer` and `TransportDataSession`
//  holds its own, so a test (or an app) replaces a dependency on one instance instead of a
//  process-wide `Components` value.
//

import Foundation

public struct TransferEnvironment {
    /// The session attachments are sent and fetched through.
    public var dataSession: () -> SCTDataSession?
    /// Whether an upload must be encrypted.
    public var keyProvider: () -> AttachmentKeyProvider
    /// Encrypts and decrypts files (video posters; the transport has its own).
    public var fileEncryption: () -> FileEncryption
    /// Exports videos and takes their frames.
    public var videoProcessor: () -> VideoProcessor.Type
    /// Reads and resizes images.
    public var imageBuilder: () -> ImageBuilder.Type
    /// Where files are kept.
    public var storage: () -> Storage.Type
    /// Finds an earlier upload of the same bytes.
    public var checksumProvider: () -> ChannelMessageChecksumProvider.Type
    /// How images (and video posters) are resized before they are sent.
    public var imageResizeConfig: () -> SceytChatUIKit.Config.ResizeConfig
    /// Whether an upload first asks the checksum table for an object already stored.
    public var preventsDuplicateUploads: () -> Bool

    public init(
        dataSession: @escaping () -> SCTDataSession?,
        keyProvider: @escaping () -> AttachmentKeyProvider,
        fileEncryption: @escaping () -> FileEncryption,
        videoProcessor: @escaping () -> VideoProcessor.Type,
        imageBuilder: @escaping () -> ImageBuilder.Type,
        storage: @escaping () -> Storage.Type,
        checksumProvider: @escaping () -> ChannelMessageChecksumProvider.Type,
        imageResizeConfig: @escaping () -> SceytChatUIKit.Config.ResizeConfig = { SceytChatUIKit.shared.config.imageAttachmentResizeConfig },
        preventsDuplicateUploads: @escaping () -> Bool = { SceytChatUIKit.shared.config.preventDuplicateAttachmentUpload }
    ) {
        self.dataSession = dataSession
        self.keyProvider = keyProvider
        self.fileEncryption = fileEncryption
        self.videoProcessor = videoProcessor
        self.imageBuilder = imageBuilder
        self.storage = storage
        self.checksumProvider = checksumProvider
        self.imageResizeConfig = imageResizeConfig
        self.preventsDuplicateUploads = preventsDuplicateUploads
    }

    /// The app's `Components`, read at each use: a component the app replaces later is the
    /// one transfers use.
    public static var components: TransferEnvironment {
        TransferEnvironment(
            dataSession: { Components.dataSession },
            keyProvider: { Components.attachmentKeyProvider },
            fileEncryption: { Components.fileEncryption },
            videoProcessor: { Components.videoProcessor },
            imageBuilder: { Components.imageBuilder },
            storage: { Components.storage },
            checksumProvider: { Components.channelMessageChecksumProvider }
        )
    }
}
