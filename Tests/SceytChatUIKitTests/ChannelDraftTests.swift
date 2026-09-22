//
//  ChannelDraftTests.swift
//  SceytChatUIKitTests
//
//  Covers persisting the whole message-input state per channel — composed text, reply/edit
//  target, media strip, view-once — and the invariants that keep it from leaking into the
//  channel list or outliving its channel.
//

@testable import SceytChatUIKit
import CoreData
import SceytChat
import XCTest

final class ChannelDraftTests: XCTestCase {

    private var mockDB: MockDatabase!
    private var ctx: NSManagedObjectContext { mockDB.container.viewContext }

    private let channelId: ChannelId = 42

    override func setUp() {
        super.setUp()
        mockDB = MockDatabase()
        seedChannel(id: channelId)
    }

    override func tearDown() {
        mockDB = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func seedChannel(id: ChannelId) -> ChannelDTO {
        let (channel, _) = ChannelDTO.fetchOrCreate(id: id, context: ctx)
        channel.createdAt = Date().bridgeDate
        channel.type = "group"
        try? ctx.save()
        return channel
    }

    @discardableResult
    private func seedMessage(id: MessageId, tid: Int64 = 0, channelId: ChannelId) -> MessageDTO {
        let message = MessageDTO.fetchOrCreate(id: id, tid: tid, channelId: Int64(channelId), context: ctx)
        message.id = Int64(id)
        message.tid = tid == 0 ? Int64(id) : tid
        message.channelId = Int64(channelId)
        message.createdAt = Date().bridgeDate
        message.user = UserDTO.fetchOrCreate(id: "me", context: ctx)
        try? ctx.save()
        return message
    }

    /// A draft attachment backed by a file that really exists, so `convert()` does not prune it.
    private func makeTempFileAttachment(name: String) -> AttachmentModel {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(name)-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8), attributes: nil)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return AttachmentModel(fileUrl: url)
    }

    /// A real on-disk PNG, so `AttachmentType(url:)` resolves `.image` and the preview renders
    /// "Image" rather than the generic file label.
    private func makeTempImageAttachment() -> AttachmentModel {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("draft-\(UUID().uuidString).png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        try? image.pngData()?.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return AttachmentModel(mediaUrl: url, thumbnail: nil)
    }

    /// A recorded-but-unsent voice message, as the recorder produces it: a real file in the temp
    /// directory plus amplitudes and duration.
    private func makeVoiceRecording(duration: Int = 7, amplitudes: [Int] = [1, 5, 9]) -> AttachmentModel {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recording-\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data("audio".utf8), attributes: nil)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return AttachmentModel(
            voiceUrl: url,
            metadata: .init(thumbnail: amplitudes, duration: duration)
        )
    }

    private func apply(_ draft: DraftMessage, date: Date? = Date()) {
        ctx.applyDraft(draft, date: date)
        try? ctx.save()
    }

    private func loadedDraft() -> DraftMessage? {
        ctx.draft(channelId: channelId)
    }

    private func channel() -> ChannelDTO? {
        ChannelDTO.fetch(id: channelId, context: ctx)
    }

    private func text(_ value: String) -> NSAttributedString {
        NSAttributedString(string: value)
    }

    // MARK: - Round trip

    func testDraft_roundTripsBodyTargetAndViewOnce() {
        let message = seedMessage(id: 100, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("hello"),
            target: .init(message: message.convert(), isReply: true),
            viewOnce: true
        ))

        let loaded = loadedDraft()
        XCTAssertEqual(loaded?.body?.string, "hello")
        XCTAssertEqual(loaded?.target?.message.id, 100)
        XCTAssertEqual(loaded?.target?.isReply, true)
        XCTAssertEqual(loaded?.viewOnce, true)
    }

    func testDraft_resolvesPendingTargetByTid() {
        // A message that has not been acked has `id == 0` and is reachable only by tid.
        let pending = seedMessage(id: 0, tid: 777, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("replying to unsent"),
            target: .init(message: pending.convert(), isReply: true)
        ))

        let dto = DraftMessageDTO.fetch(channelId: channelId, context: ctx)
        XCTAssertEqual(dto?.targetMessageId, 0, "a pending message has no server id to store")
        XCTAssertEqual(dto?.targetMessageTid, 777)
        XCTAssertEqual(loadedDraft()?.target?.message.tid, 777)
    }

    /// The whole point of the feature: the reply survives, so the next send still replies.
    func testDraft_keepsReplyFlagDistinctFromEdit() {
        let message = seedMessage(id: 101, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("a"),
            target: .init(message: message.convert(), isReply: false)
        ))
        XCTAssertEqual(loadedDraft()?.target?.isReply, false)
    }

    // MARK: - Channel list projection

    /// `ChannelDTO.draft`/`draftDate` stay the denormalized projection the channel list reads,
    /// so they must track the composed body on every write.
    func testApplyDraft_mirrorsBodyOntoChannelForTheList() {
        apply(DraftMessage(channelId: channelId, body: text("visible in list")))

        XCTAssertEqual(channel()?.draft?.string, "visible in list")
        XCTAssertNotNil(channel()?.draftDate, "a real draft must bump the channel's sorting date")
    }

    /// Tapping Reply and walking away without typing previews as "Draft: Reply", so it sorts as a
    /// draft too — the cell shows pending work, and it should surface like any other draft.
    func testApplyDraft_replyWithoutText_showsInTheListAsAReply() {
        let message = seedMessage(id: 102, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            target: .init(message: message.convert(), isReply: true)
        ))

        XCTAssertNotNil(loadedDraft()?.target, "the reply target is still intent worth restoring")
        XCTAssertNil(channel()?.draft, "there is no text to preview")
        XCTAssertEqual(channel()?.draftActionType, "reply")
        XCTAssertNotNil(channel()?.draftDate, "a previewable draft sorts as one")
    }

    /// The case this was asked for: reply, type nothing, leave → "Draft: Reply" on the cell.
    func testReplyOnlyDraft_previewsAsReply() {
        let message = seedMessage(id: 107, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            target: .init(message: message.convert(), isReply: true)
        ))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        XCTAssertTrue(model.hasDraftMessage, "a bare reply target is still a draft")

        let preview = model.createDraftMessageIfNeeded()?.string ?? ""
        XCTAssertTrue(preview.contains(L10n.Channel.Message.draft),
                      "the Draft prefix should still be there; was: \(preview)")
        XCTAssertTrue(preview.contains(L10n.Message.Action.Title.reply),
                      "a reply-only draft should preview as Reply; was: \(preview)")
    }

    /// The case asked for: editing a message previews the message itself, not the word "Edit".
    func testEditDraft_previewsTheEditedMessage() {
        let message = seedMessage(id: 108, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            editBody: text("the full edited message"),
            target: .init(message: message.convert(), isReply: false)
        ))

        XCTAssertEqual(channel()?.draftActionType, "edit")

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        let preview = model.createDraftMessageIfNeeded()?.string ?? ""
        XCTAssertTrue(preview.contains(L10n.Channel.Message.draft),
                      "the Draft prefix should still be there; was: \(preview)")
        XCTAssertTrue(preview.contains("the full edited message"),
                      "the edited message is what should show; was: \(preview)")
        XCTAssertFalse(preview.contains(L10n.Message.Action.Title.edit),
                       "the message replaces the bare Edit label; was: \(preview)")
    }

    /// Clearing the message text while editing leaves nothing to preview, so the label is the
    /// only thing left to say what is pending.
    func testEditDraft_withEmptiedText_fallsBackToTheEditLabel() {
        let message = seedMessage(id: 112, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            editBody: text("   "),
            target: .init(message: message.convert(), isReply: false)
        ))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        let preview = model.createDraftMessageIfNeeded()?.string ?? ""
        XCTAssertTrue(preview.contains(L10n.Message.Action.Title.edit),
                      "an emptied edit should still say something is pending; was: \(preview)")
    }

    /// Text and attachments are more informative than the bare action, so they win.
    func testReplyWithText_previewsTheTextNotTheAction() {
        let message = seedMessage(id: 109, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("my answer"),
            target: .init(message: message.convert(), isReply: true)
        ))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        let preview = model.createDraftMessageIfNeeded()?.string ?? ""
        XCTAssertTrue(preview.contains("my answer"))
        XCTAssertFalse(preview.contains(L10n.Message.Action.Title.reply),
                       "the typed text is what the user wants to see; was: \(preview)")
    }

    func testReplyWithAttachment_previewsTheAttachmentNotTheAction() {
        let message = seedMessage(id: 110, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            target: .init(message: message.convert(), isReply: true),
            attachments: [makeTempImageAttachment()]
        ))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        let preview = model.createDraftMessageIfNeeded()?.string ?? ""
        XCTAssertTrue(preview.contains(L10n.Message.Attachment.image),
                      "an attachment says more than the bare action; was: \(preview)")
    }

    func testDraftActionType_clearsWhenTheActionIsDropped() {
        let message = seedMessage(id: 111, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            target: .init(message: message.convert(), isReply: true)
        ))
        XCTAssertEqual(channel()?.draftActionType, "reply")

        apply(DraftMessage(channelId: channelId, body: text("no longer replying")))
        XCTAssertNil(channel()?.draftActionType)

        apply(DraftMessage(channelId: channelId), date: nil)
        XCTAssertNil(channel()?.draftActionType)
    }

    /// While editing, the cell previews the edit — that is what the user is working on. The draft
    /// parked behind it is still kept, just not shown, so cancelling can fall back to it.
    func testApplyDraft_pendingEdit_previewsTheEditAndKeepsTheParkedDraft() {
        let message = seedMessage(id: 103, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("my real draft"),
            editBody: text("the message I am editing"),
            target: .init(message: message.convert(), isReply: false)
        ))

        XCTAssertEqual(
            channel()?.draft?.string, "the message I am editing",
            "the list should show the message being edited"
        )

        let loaded = loadedDraft()
        XCTAssertEqual(
            loaded?.body?.string, "my real draft",
            "the parked draft must survive so cancelling an edit restores it"
        )
        XCTAssertEqual(loaded?.editBody?.string, "the message I am editing")
    }

    func testApplyDraft_whitespaceOnlyBody_countsAsNoText() {
        apply(DraftMessage(channelId: channelId, body: text("   \n  ")))
        XCTAssertNil(channel()?.draft)
        XCTAssertNil(loadedDraft(), "a blank draft with nothing else is not worth a row")
    }

    // MARK: - Content rule

    func testApplyDraft_emptyDraft_deletesTheRow() {
        apply(DraftMessage(channelId: channelId, body: text("something")))
        XCTAssertNotNil(DraftMessageDTO.fetch(channelId: channelId, context: ctx))

        apply(DraftMessage(channelId: channelId), date: nil)
        XCTAssertNil(DraftMessageDTO.fetch(channelId: channelId, context: ctx))
        XCTAssertNil(channel()?.draft)
    }

    func testApplyDraft_withoutChannelRow_doesNotCreateAnOrphan() {
        let orphanChannelId: ChannelId = 999
        ctx.applyDraft(DraftMessage(channelId: orphanChannelId, body: text("x")), date: Date())
        try? ctx.save()

        XCTAssertNil(
            DraftMessageDTO.fetch(channelId: orphanChannelId, context: ctx),
            "a channelId-keyed side table must not collect rows for channels that do not exist"
        )
    }

    // MARK: - Attachments

    func testAttachments_surviveAndKeepTheirOrder() {
        let first = makeTempFileAttachment(name: "first")
        let second = makeTempFileAttachment(name: "second")
        apply(DraftMessage(channelId: channelId, attachments: [first, second]))

        let loaded = loadedDraft()
        XCTAssertEqual(loaded?.attachments.count, 2)
        XCTAssertEqual(loaded?.attachments.first?.url, first.url)
        XCTAssertEqual(loaded?.attachments.last?.url, second.url)
    }

    func testAttachments_areReplacedWholesaleNotAccumulated() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempFileAttachment(name: "a")]))
        let replacement = makeTempFileAttachment(name: "b")
        apply(DraftMessage(channelId: channelId, attachments: [replacement]))

        XCTAssertEqual(DraftAttachmentDTO.fetch(channelId: channelId, context: ctx).count, 1)
        XCTAssertEqual(loadedDraft()?.attachments.first?.url, replacement.url)
    }

    /// A purged temp file or an expired document-picker URL must cost only that chip.
    func testAttachments_missingFileIsSkippedAndTheRestSurvive() {
        let doomed = makeTempFileAttachment(name: "doomed")
        let survivor = makeTempFileAttachment(name: "survivor")
        apply(DraftMessage(channelId: channelId, body: text("caption"), attachments: [doomed, survivor]))

        try? FileManager.default.removeItem(at: doomed.url)

        let loaded = loadedDraft()
        XCTAssertEqual(loaded?.attachments.count, 1)
        XCTAssertEqual(loaded?.attachments.first?.url, survivor.url)
        XCTAssertEqual(loaded?.body?.string, "caption", "text must not be lost with the file")
    }

    // MARK: - Attachment-only draft preview

    /// An image picked with nothing typed must still preview as "Draft: Image" in the channel
    /// list, so the channel row has to carry the attachment's type.
    func testAttachmentOnlyDraft_recordsTheTypeOnTheChannelForTheList() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempFileAttachment(name: "solo")]))

        XCTAssertEqual(channel()?.draftAttachmentType, "file")
        XCTAssertNil(channel()?.draft, "there is no text to preview")
        XCTAssertNotNil(
            channel()?.draftDate,
            "attachments are content the list shows, so they bump the sorting date like text does"
        )
    }

    func testAttachmentOnlyDraft_countsAsADraftInTheLayoutModel() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempFileAttachment(name: "solo")]))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        XCTAssertTrue(model.hasDraftMessage, "an attachments-only draft is still a draft")

        let preview = model.createDraftMessageIfNeeded()
        XCTAssertNotNil(preview, "the cell must render a preview for an attachments-only draft")
        XCTAssertTrue(
            preview?.string.contains(L10n.Message.Attachment.file) == true,
            "the preview should name the attachment type; was: \(preview?.string ?? "<nil>")"
        )
    }

    /// The case this was asked for: an image picked, nothing typed → "Draft: Image".
    func testImageOnlyDraft_previewsAsImage() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempImageAttachment()]))

        XCTAssertEqual(channel()?.draftAttachmentType, "image")

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        let preview = model.createDraftMessageIfNeeded()?.string ?? ""

        XCTAssertTrue(preview.contains(L10n.Channel.Message.draft),
                      "the preview should keep the Draft prefix; was: \(preview)")
        XCTAssertTrue(preview.contains(L10n.Message.Attachment.image),
                      "the preview should name the image; was: \(preview)")
    }

    /// Each type gets its own label, the same set the sent-message preview uses.
    func testDraftAttachmentTypes_eachPreviewWithTheirOwnName() {
        let cases: [(String, String)] = [
            ("image", L10n.Message.Attachment.image),
            ("video", L10n.Message.Attachment.video),
            ("voice", L10n.Message.Attachment.voice),
            ("file", L10n.Message.Attachment.file)
        ]

        for (type, expected) in cases {
            guard let dto = channel() else { return XCTFail("no channel") }
            dto.draft = nil
            dto.draftAttachmentType = type
            try? ctx.save()

            let model = ChannelLayoutModel(channel: dto.convert(),
                                           appearance: ChannelListViewController.ChannelCell.appearance)
            let preview = model.createDraftMessageIfNeeded()?.string ?? ""
            XCTAssertTrue(preview.contains(expected),
                          "a \(type) draft should preview as \"\(expected)\"; was: \(preview)")
        }
    }

    /// The type has to track the current attachment, or the list keeps previewing the old one.
    func testDraftAttachmentType_followsTheFirstAttachment() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempFileAttachment(name: "a")]))
        XCTAssertEqual(channel()?.draftAttachmentType, "file")

        apply(DraftMessage(channelId: channelId, body: text("now just text")))
        XCTAssertNil(channel()?.draftAttachmentType, "a text-only draft has no attachment to show")

        apply(DraftMessage(channelId: channelId), date: nil)
        XCTAssertNil(channel()?.draftAttachmentType, "clearing the draft clears the preview type")
    }

    /// A caption wins over the attachment name, matching how a sent message previews.
    func testDraftWithTextAndAttachment_previewsTheText() {
        apply(DraftMessage(
            channelId: channelId,
            body: text("look at this"),
            attachments: [makeTempFileAttachment(name: "with-caption")]
        ))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        XCTAssertTrue(model.createDraftMessageIfNeeded()?.string.contains("look at this") == true)
    }

    func testAttachmentsAlone_countAsContent() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempFileAttachment(name: "solo")]))
        XCTAssertEqual(loadedDraft()?.attachments.count, 1)
    }

    // MARK: - Voice recording

    /// A paused recording lives in the recorder's own preview, never in the media strip, so it is
    /// persisted in its own slot and must come back in that slot — not as a strip chip.
    func testPendingVoiceRecording_roundTripsInItsOwnSlot() {
        let recording = makeVoiceRecording()
        apply(DraftMessage(channelId: channelId, voiceRecording: recording))

        let loaded = loadedDraft()
        XCTAssertEqual(loaded?.voiceRecording?.url, recording.url)
        XCTAssertTrue(
            loaded?.attachments.isEmpty == true,
            "the recording belongs in the preview slot, not the media strip"
        )
    }

    func testPendingVoiceRecording_keepsDurationAndAmplitudes() {
        apply(DraftMessage(
            channelId: channelId,
            voiceRecording: makeVoiceRecording(duration: 12, amplitudes: [3, 7, 11, 4])
        ))

        let restored = loadedDraft()?.voiceRecording
        XCTAssertEqual(restored?.duration, 12)
        XCTAssertEqual(restored?.thumb, [3, 7, 11, 4], "the waveform must survive for the preview")
    }

    func testPendingVoiceRecording_countsAsContentOnItsOwn() {
        apply(DraftMessage(channelId: channelId, voiceRecording: makeVoiceRecording()))

        XCTAssertNotNil(
            DraftMessageDTO.fetch(channelId: channelId, context: ctx),
            "a recording with no text is still a draft worth keeping"
        )
        XCTAssertNotNil(channel()?.draftDate, "it is content the list shows, so it sorts like one")
        XCTAssertEqual(channel()?.draftAttachmentType, "voice")
    }

    func testVoiceOnlyDraft_previewsAsVoice() {
        apply(DraftMessage(channelId: channelId, voiceRecording: makeVoiceRecording()))

        guard let converted = channel()?.convert() else { return XCTFail("no channel") }
        let model = ChannelLayoutModel(channel: converted, appearance: ChannelListViewController.ChannelCell.appearance)
        let preview = model.createDraftMessageIfNeeded()?.string ?? ""
        XCTAssertTrue(preview.contains(L10n.Message.Attachment.voice),
                      "a recording should preview as Voice; was: \(preview)")
    }

    /// The recording lives in the temp directory until it is sent, so iOS may purge it.
    func testPendingVoiceRecording_missingFileIsDroppedButTheTextSurvives() {
        let recording = makeVoiceRecording()
        apply(DraftMessage(channelId: channelId, body: text("with a recording"), voiceRecording: recording))

        try? FileManager.default.removeItem(at: recording.url)

        let loaded = loadedDraft()
        XCTAssertNil(loaded?.voiceRecording, "a purged recording must not come back as a broken preview")
        XCTAssertEqual(loaded?.body?.string, "with a recording")
    }

    func testVoiceRecordingAndAttachments_staySeparate() {
        let recording = makeVoiceRecording()
        let media = makeTempFileAttachment(name: "doc")
        apply(DraftMessage(channelId: channelId, attachments: [media], voiceRecording: recording))

        let loaded = loadedDraft()
        XCTAssertEqual(loaded?.attachments.map(\.url), [media.url])
        XCTAssertEqual(loaded?.voiceRecording?.url, recording.url)
    }

    // MARK: - Target lifecycle

    func testDraft_deletedTargetDropsTheActionButKeepsTheText() {
        let message = seedMessage(id: 104, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("still typed"),
            target: .init(message: message.convert(), isReply: true)
        ))

        message.state = Int16(ChatMessage.State.deleted.intValue)
        try? ctx.save()

        let loaded = loadedDraft()
        XCTAssertNil(loaded?.target, "a deleted target must not come back as a reply bar")
        XCTAssertEqual(loaded?.body?.string, "still typed")
    }

    func testDraft_targetMissingFromStoreDropsTheAction() {
        let message = seedMessage(id: 105, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("orphaned reply"),
            target: .init(message: message.convert(), isReply: true)
        ))

        ctx.delete(message)
        try? ctx.save()

        XCTAssertNil(loadedDraft()?.target)
        XCTAssertEqual(loadedDraft()?.body?.string, "orphaned reply")
    }

    func testClearTarget_keepsTheTextWhenMessagesAreWiped() {
        let message = seedMessage(id: 106, channelId: channelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("survives clear history"),
            target: .init(message: message.convert(), isReply: true)
        ))

        DraftMessageDTO.clearTarget(channelId: channelId, context: ctx)
        try? ctx.save()

        let loaded = loadedDraft()
        XCTAssertNil(loaded?.target)
        XCTAssertEqual(loaded?.body?.string, "survives clear history")
    }

    // MARK: - Cleanup

    /// Exercises the purge `deleteChannel(id:)` performs. `deleteChannel(id:)` itself can't run
    /// here: it merges its changes into `SceytChatUIKit.shared.database`, whose persistent store
    /// coordinator differs from `MockDatabase`'s — same limitation as
    /// `PendingMessageDeleteTests.testDeleteAllForChannel_purgesOnlyThatChannelsPendingDeletes`.
    func testDeleteDraftForChannel_purgesOnlyThatChannelsDraft() {
        let otherChannelId: ChannelId = 43
        seedChannel(id: otherChannelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("doomed with the channel"),
            attachments: [makeTempFileAttachment(name: "att")]
        ))
        ctx.applyDraft(DraftMessage(channelId: otherChannelId, body: text("survivor")), date: Date())
        try? ctx.save()

        DraftMessageDTO.delete(channelId: channelId, context: ctx)
        try? ctx.save()

        XCTAssertNil(DraftMessageDTO.fetch(channelId: channelId, context: ctx))
        XCTAssertTrue(
            DraftAttachmentDTO.fetch(channelId: channelId, context: ctx).isEmpty,
            "the Cascade rule must take the attachment rows with the draft"
        )
        XCTAssertNotNil(
            DraftMessageDTO.fetch(channelId: otherChannelId, context: ctx),
            "other channels must be untouched"
        )
    }

    func testDeleteDraft_cascadesToAttachments() {
        apply(DraftMessage(channelId: channelId, attachments: [makeTempFileAttachment(name: "c")]))
        XCTAssertFalse(DraftAttachmentDTO.fetch(channelId: channelId, context: ctx).isEmpty)

        DraftMessageDTO.delete(channelId: channelId, context: ctx)
        try? ctx.save()

        XCTAssertTrue(DraftAttachmentDTO.fetch(channelId: channelId, context: ctx).isEmpty)
    }

    // MARK: - Channel id remap

    func testMove_carriesTheDraftToTheServerChannelId() {
        let realChannelId: ChannelId = 555
        seedChannel(id: realChannelId)
        apply(DraftMessage(
            channelId: channelId,
            body: text("written before the channel existed"),
            attachments: [makeTempFileAttachment(name: "pending")]
        ))

        DraftMessageDTO.move(fromChannelId: channelId, toChannelId: realChannelId, context: ctx)
        try? ctx.save()

        XCTAssertNil(DraftMessageDTO.fetch(channelId: channelId, context: ctx))
        let moved = ctx.draft(channelId: realChannelId)
        XCTAssertEqual(moved?.body?.string, "written before the channel existed")
        XCTAssertEqual(
            moved?.attachments.count, 1,
            "attachment rows carry their own channelId and must be remapped too"
        )
    }

    func testMove_newerDraftWins() {
        let realChannelId: ChannelId = 556
        seedChannel(id: realChannelId)

        ctx.applyDraft(
            DraftMessage(channelId: realChannelId, body: text("older"), createdAt: Date(timeIntervalSince1970: 100)),
            date: Date()
        )
        ctx.applyDraft(
            DraftMessage(channelId: channelId, body: text("newer"), createdAt: Date(timeIntervalSince1970: 200)),
            date: Date()
        )
        try? ctx.save()

        DraftMessageDTO.move(fromChannelId: channelId, toChannelId: realChannelId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(ctx.draft(channelId: realChannelId)?.body?.string, "newer")
    }

    func testMove_olderDraftIsDiscardedRatherThanClobbering() {
        let realChannelId: ChannelId = 557
        seedChannel(id: realChannelId)

        ctx.applyDraft(
            DraftMessage(channelId: realChannelId, body: text("newer"), createdAt: Date(timeIntervalSince1970: 200)),
            date: Date()
        )
        ctx.applyDraft(
            DraftMessage(channelId: channelId, body: text("older"), createdAt: Date(timeIntervalSince1970: 100)),
            date: Date()
        )
        try? ctx.save()

        DraftMessageDTO.move(fromChannelId: channelId, toChannelId: realChannelId, context: ctx)
        try? ctx.save()

        XCTAssertEqual(ctx.draft(channelId: realChannelId)?.body?.string, "newer")
        XCTAssertNil(DraftMessageDTO.fetch(channelId: channelId, context: ctx))
    }
}
