//
//  SCTUIKitComponents.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

typealias Components = SCTUIKitComponents

public enum SCTUIKitComponents {
    
    public static var navigationController: NavigationController.Type = NavigationController.self
    public static var channelListViewController: ChannelListViewController.Type = ChannelListViewController.self
    public static var channelListVM: ChannelListVM.Type = ChannelListVM.self
    public static var channelListRouter: ChannelListRouter.Type = ChannelListRouter.self
    public static var channelCell: ChannelCell.Type = ChannelCell.self
    public static var channelListEmptyStateView: ChannelListViewController.EmptyStateView.Type = ChannelListViewController.EmptyStateView.self
    public static var noDataView: NoDataView.Type = NoDataView.self
    public static var channelCreatedView: ChannelCreatedView.Type = ChannelCreatedView.self
    public static var channelViewController: ChannelViewController.Type = ChannelViewController.self
    public static var channelVM: ChannelVM.Type = ChannelVM.self
    public static var channelRouter: ChannelRouter.Type = ChannelRouter.self
    public static var channelMessagesCollectionView: ChannelViewController.MessagesCollectionView.Type = ChannelViewController.MessagesCollectionView.self
    public static var channelMessagesCollectionViewLayout: ChannelViewController.MessagesCollectionViewLayout.Type = ChannelViewController.MessagesCollectionViewLayout.self
    public static var channelScrollDownView: ChannelViewController.ScrollDownView.Type = ChannelViewController.ScrollDownView.self
    public static var channelHeaderView: ChannelViewController.HeaderView.Type = ChannelViewController.HeaderView.self
    public static var inputCoverView: InputViewController.CoverView.Type = InputViewController.CoverView.self
    public static var channelDisplayedTimer: ChannelViewController.DisplayedTimer.Type = ChannelViewController.DisplayedTimer.self
    public static var inputMessageSearchControlsView: InputViewController.MessageSearchControlsView.Type = InputViewController.MessageSearchControlsView.self

    public static var channelInfoViewController: ChannelInfoViewController.Type = ChannelInfoViewController.self
    public static var simultaneousGestureTableView: SimultaneousGestureTableView.Type = SimultaneousGestureTableView.self
    public static var channelProfileVM: ChannelProfileVM.Type = ChannelProfileVM.self
    public static var channelProfileRouter: ChannelProfileRouter.Type = ChannelProfileRouter.self
    
    public static var channelInfoDetailsCell: ChannelInfoViewController.DetailsCell.Type = ChannelInfoViewController.DetailsCell.self
    public static var channelInfoDescriptionCell: ChannelInfoViewController.DescriptionCell.Type = ChannelInfoViewController.DescriptionCell.self
    public static var channelInfoOptionCell: ChannelInfoViewController.OptionCell.Type = ChannelInfoViewController.OptionCell.self
    public static var channelInfoContainerCell: ChannelInfoViewController.ContainerCell.Type = ChannelInfoViewController.ContainerCell.self
    
    public static var editChannelViewController: EditChannelViewController.Type = EditChannelViewController.self
    public static var editChannelAvatarCell: EditChannelViewController.AvatarCell.Type = EditChannelViewController.AvatarCell.self
    public static var editChannelTextFieldCell: EditChannelViewController.TextFieldCell.Type = EditChannelViewController.TextFieldCell.self
    public static var editChannelURICell: EditChannelViewController.URICell.Type = EditChannelViewController.URICell.self

    public static var channelProfileEditVM: ChannelProfileEditVM.Type = ChannelProfileEditVM.self

    public static var channelMemberListViewController: ChannelMemberListViewController.Type = ChannelMemberListViewController.self
    public static var channelMemberListVM: ChannelMemberListVM.Type = ChannelMemberListVM.self
    public static var channelMemberListRouter: ChannelMemberListRouter.Type = ChannelMemberListRouter.self
    public static var channelMemberCell: ChannelMemberCell.Type = ChannelMemberCell.self
    public static var channelMemberAddCell: ChannelMemberAddCell.Type = ChannelMemberAddCell.self
    public static var inputSelectedMessagesActionsView: InputViewController.SelectedMessagesActionsView.Type = InputViewController.SelectedMessagesActionsView.self
    
    public static var channelInfoMediaCollectionView: ChannelInfoViewController.MediaCollectionView.Type = ChannelInfoViewController.MediaCollectionView.self
    public static var channelInfoFileCollectionView: ChannelInfoViewController.FileCollectionView.Type = ChannelInfoViewController.FileCollectionView.self
    public static var channelInfoLinkCollectionView: ChannelInfoViewController.LinkCollectionView.Type = ChannelInfoViewController.LinkCollectionView.self
    public static var channelInfoVoiceCollectionView: ChannelInfoViewController.VoiceCollectionView.Type = ChannelInfoViewController.VoiceCollectionView.self
    public static var channelInfoImageAttachmentCell: ChannelInfoViewController.ImageAttachmentCell.Type = ChannelInfoViewController.ImageAttachmentCell.self
    public static var channelInfoVideoAttachmentCell: ChannelInfoViewController.VideoAttachmentCell.Type = ChannelInfoViewController.VideoAttachmentCell.self
    public static var channelInfoAttachmentHeaderView: ChannelInfoViewController.AttachmentHeaderView.Type = ChannelInfoViewController.AttachmentHeaderView.self
    public static var channelInfoFileCell: ChannelInfoViewController.FileCell.Type = ChannelInfoViewController.FileCell.self
    public static var channelInfoLinkCell: ChannelInfoViewController.LinkCell.Type = ChannelInfoViewController.LinkCell.self
    public static var channelInfoVoiceCell: ChannelInfoViewController.VoiceCell.Type = ChannelInfoViewController.VoiceCell.self
    public static var imagePreviewViewController: ImagePreviewViewController.Type = ImagePreviewViewController.self
    public static var channelAvatarVM: ChannelAvatarVM.Type = ChannelAvatarVM.self

    
    public static var channelAttachmentListVM: ChannelAttachmentListVM.Type = ChannelAttachmentListVM.self
    
    public static var segmentedControlView: SegmentedControlView.Type = SegmentedControlView.self
    
    public static var inputViewController: InputViewController.Type = InputViewController.self
    public static var inputRouter: InputRouter.Type = InputRouter.self
    public static var inputMediaView: InputViewController.MediaView.Type = InputViewController.MediaView.self
    public static var inputTextView: InputViewController.InputTextView.Type = InputViewController.InputTextView.self
    public static var inputMessageActionsView: InputViewController.MessageActionsView.Type = InputViewController.MessageActionsView.self
    public static var inputVoiceRecorderView: InputViewController.VoiceRecorderView.Type = InputViewController.VoiceRecorderView.self
    public static var inputVoiceRecordPlaybackView: InputViewController.VoiceRecordPlaybackView.Type = InputViewController.VoiceRecordPlaybackView.self
    public static var inputVoiceRecordPlaybackPlayerView: InputViewController.VoiceRecordPlaybackView.PlayerView.Type = InputViewController.VoiceRecordPlaybackView.PlayerView.self
    public static var inputThumbnailView: InputViewController.ThumbnailView.Type = InputViewController.ThumbnailView.self
    public static var inputThumbnailViewMediaView: InputViewController.ThumbnailView.MediaView.Type = InputViewController.ThumbnailView.MediaView.self
    public static var inputThumbnailViewFileView: InputViewController.ThumbnailView.FileView.Type = InputViewController.ThumbnailView.FileView.self
    public static var inputThumbnailViewTimeLabel: InputViewController.ThumbnailView.TimeLabel.Type = InputViewController.ThumbnailView.TimeLabel.self
    
    public static var inputMentionUsersListViewController: InputViewController.MentionUsersListViewController.Type = InputViewController.MentionUsersListViewController.self
    public static var mentioningUserListVM: MentioningUserListVM.Type = MentioningUserListVM.self
    public static var inputMentionUsersCell: InputViewController.MentionUsersListViewController.MentionUserCell.Type = InputViewController.MentionUsersListViewController.MentionUserCell.self
    
    public static var channelOutgoingMessageCell: ChannelViewController.OutgoingMessageCell.Type = ChannelViewController.OutgoingMessageCell.self
    public static var channelIncomingMessageCell: ChannelViewController.IncomingMessageCell.Type = ChannelViewController.IncomingMessageCell.self
    public static var channelDateSeparatorView: ChannelViewController.DateSeparatorView.Type = ChannelViewController.DateSeparatorView.self
    
    public static var messageInfoViewController: MessageInfoViewController.Type = MessageInfoViewController.self
    public static var messageInfoVM: MessageInfoVM.Type = MessageInfoVM.self
    public static var messageInfoHeaderView: MessageInfoViewController.HeaderView.Type = MessageInfoViewController.HeaderView.self
    public static var messageInfoMessageCell: MessageInfoViewController.MessageCell.Type = MessageInfoViewController.MessageCell.self
    public static var messageInfoMarkerCell: MessageInfoViewController.MarkerCell.Type = MessageInfoViewController.MarkerCell.self
    
    public static var forwardViewController: ForwardViewController.Type = ForwardViewController.self
    public static var channelForwardVM: ChannelForwardVM.Type = ChannelForwardVM.self
    public static var channelForwardRouter: ChannelForwardRouter.Type = ChannelForwardRouter.self

    public static var channelSearchController: ChannelSearchController.Type = ChannelSearchController.self
    public static var channelSearchResultsViewController: ChannelSearchResultsViewController.Type = ChannelSearchResultsViewController.self

    public static var mediaPickerViewController: MediaPickerViewController.Type = MediaPickerViewController.self
    public static var mediaPickerFooterView: MediaPickerViewController.FooterView.Type = MediaPickerViewController.FooterView.self
    public static var mediaPickerAttachButton: MediaPickerViewController.AttachButton.Type = MediaPickerViewController.AttachButton.self
    
    public static var mediaPickerCell: MediaPickerViewController.MediaCell.Type = MediaPickerViewController.MediaCell.self
    public static var mediaPickerCollectionView: MediaPickerViewController.MediaPickerCollectionView.Type = MediaPickerViewController.MediaPickerCollectionView.self
    public static var mediaPickerCollectionViewLayout: MediaPickerViewController.MediaPickerCollectionViewLayout.Type = MediaPickerViewController.MediaPickerCollectionViewLayout.self
    
    public static var imageCropperViewController: ImageCropperViewController.Type = ImageCropperViewController.self
    public static var imageCropperVM: ImageCropperVM.Type = ImageCropperVM.self

    public static var circularProgressView: CircularProgressView.Type = CircularProgressView.self
    public static var playerView: PlayerView.Type = PlayerView.self
    public static var typingView: TypingView.Type = TypingView.self
    public static var timeLabel: TimeLabel.Type = TimeLabel.self
    public static var checkBoxView: CheckBoxView.Type = CheckBoxView.self
    public static var circleImageView: CircleImageView.Type = CircleImageView.self
    
    public static var mediaPreviewerNavigationController: MediaPreviewerNavigationController.Type = MediaPreviewerNavigationController.self
    public static var mediaPreviewerCarouselViewController: MediaPreviewerCarouselViewController.Type = MediaPreviewerCarouselViewController.self
    
    public static var mediaPreviewerViewController: MediaPreviewerViewController.Type = MediaPreviewerViewController.self
    public static var previewerRouter: PreviewerRouter.Type = PreviewerRouter.self
    public static var previewerVM: PreviewerVM.Type = PreviewerVM.self
    public static var mediaPreviewerImageView: MediaPreviewerImageView.Type = MediaPreviewerImageView.self
    public static var mediaPreviewerScrollView: MediaPreviewerScrollView.Type = MediaPreviewerScrollView.self
    
    public static var reactionPickerViewController: ReactionPickerViewController.Type = ReactionPickerViewController.self // reactions popup
    public static var emojiPickerViewController: EmojiPickerViewController.Type = EmojiPickerViewController.self
    public static var emojiListVM: EmojiListVM.Type = EmojiListVM.self
    public static var emojiPickerCell: EmojiPickerViewController.EmojiCell.Type = EmojiPickerViewController.EmojiCell.self
    public static var emojiPickerSectionHeaderView: EmojiPickerViewController.SectionHeaderView.Type = EmojiPickerViewController.SectionHeaderView.self
    
    public static var reactedUserListViewController: ReactedUserListViewController.Type = ReactedUserListViewController.self
    public static var reactedUserReactionCell: ReactedUserListViewController.UserReactionCell.Type = ReactedUserListViewController.UserReactionCell.self
    public static var reactionsInfoViewController: ReactionsInfoViewController.Type = ReactionsInfoViewController.self
    public static var reactionsInfoScoreCell: ReactionsInfoViewController.ReactionScoreCell.Type = ReactionsInfoViewController.ReactionScoreCell.self
    
    public static var startChatViewController: StartChatViewController.Type = StartChatViewController.self
    public static var createNewChannelVM: CreateNewChannelVM.Type = CreateNewChannelVM.self
    public static var startChatActionsView: StartChatViewController.ActionsView.Type = StartChatViewController.ActionsView.self
    public static var channelUserCell: ChannelUserCell.Type = ChannelUserCell.self
    public static var createChannelUserCell: CreateChannelUserCell.Type = CreateChannelUserCell.self
    public static var separatorHeaderView: SeparatorHeaderView.Type = SeparatorHeaderView.self

    public static var textLabel: TextLabel.Type = TextLabel.self
    
    public static var messageLayoutModel: MessageLayoutModel.Type = MessageLayoutModel.self
    public static var channelLayoutModel: ChannelLayoutModel.Type = ChannelLayoutModel.self
    public static var initialsBuilder: InitialsBuilder.Type = InitialsBuilder.self
    public static var imageBuilder: ImageBuilder.Type = ImageBuilder.self
    public static var videoProcessor: VideoProcessor.Type = VideoProcessor.self
    public static var avatarBuilder: AvatarBuilder.Type = AvatarBuilder.self
    public static var audioSession: AudioSession.Type = AudioSession.self
    public static var storage: Storage.Type = Storage.self
    public static var dataSession: SCTDataSession? = SCTSession.default
    
    public static var channelEventHandler: ChannelEventHandler.Type = ChannelEventHandler.self
    public static var channelListProvider: ChannelListProvider.Type = ChannelListProvider.self
    public static var channelProvider: ChannelProvider.Type = ChannelProvider.self
    public static var channelCreator: ChannelCreator.Type = ChannelCreator.self
    public static var channelMessageProvider: ChannelMessageProvider.Type = ChannelMessageProvider.self
    public static var channelAttachmentProvider: ChannelAttachmentProvider.Type = ChannelAttachmentProvider.self
    public static var channelMemberListProvider: ChannelMemberListProvider.Type = ChannelMemberListProvider.self
    public static var presenceProvider: PresenceProvider.Type = PresenceProvider.self
    public static var userProvider: UserProvider.Type = UserProvider.self
    public static var channelMessageSender: ChannelMessageSender.Type = ChannelMessageSender.self
    public static var channelMessageChecksumProvider: ChannelMessageChecksumProvider.Type = ChannelMessageChecksumProvider.self
    public static var channelMessageMarkerProvider: ChannelMessageMarkerProvider.Type = ChannelMessageMarkerProvider.self
    public static var messageReactionProvider: MessageReactionProvider.Type = MessageReactionProvider.self
    public static var attachmentTransfer: AttachmentTransfer.Type = AttachmentTransfer.self
    public static var channelListSearchService: ChannelListSearchService.Type = ChannelListSearchService.self
    public static var loadRangeProvider: LoadRangeProvider.Type = LoadRangeProvider.self
    
    public static var alert: Alert.Type = Alert.self
    public static var bottomSheet: BottomSheet.Type = BottomSheet.self
    public static var sheetButton: SheetButton.Type = SheetButton.self
    public static var sheetViewController: SheetViewController.Type = SheetViewController.self
    
    public static var badgeView: BadgeView.Type = BadgeView.self
    public static var circleButton: CircleButton.Type = CircleButton.self
    public static var connectionStateView: ConnectionStateView.Type = ConnectionStateView.self
    public static var documentPickerController: DocumentPickerController.Type = DocumentPickerController.self
    public static var filePreviewController: FilePreviewController.Type = FilePreviewController.self
    public static var imagePickerController: ImagePickerController.Type = ImagePickerController.self
    public static var markableTextField: MarkableTextField.Type = MarkableTextField.self
    public static var searchController: SearchController.Type = SearchController.self
    public static var waveformView: WaveformView.Type = WaveformView.self
    
    public static var channelAddMembersViewController: ChannelAddMembersViewController.Type = ChannelAddMembersViewController.self
    public static var createGroupProfileView: CreateGroupViewController.ProfileView.Type = CreateGroupViewController.ProfileView.self
    public static var createGroupViewController: CreateGroupViewController.Type = CreateGroupViewController.self
    public static var createChannelProfileView: CreateChannelViewController.ProfileView.Type = CreateChannelViewController.ProfileView.self
    public static var createChannelViewController: CreateChannelViewController.Type = CreateChannelViewController.self
    public static var selectChannelMembersViewController: SelectChannelMembersViewController.Type = SelectChannelMembersViewController.self
    public static var selectedUserListView: SelectedUserListView.Type = SelectedUserListView.self
    public static var selectedChannelListView: SelectedChannelListView.Type = SelectedChannelListView.self
    
    
    public static var messageCell: MessageCell.Type = MessageCell.self
    public static var messageCellAttachmentAudioView: MessageCell.AttachmentAudioView.Type = MessageCell.AttachmentAudioView.self
    public static var messageCellAttachmentFileView: MessageCell.AttachmentFileView.Type = MessageCell.AttachmentFileView.self
    public static var messageCellAttachmentImageView: MessageCell.AttachmentImageView.Type = MessageCell.AttachmentImageView.self
    public static var messageCellAttachmentVideoView: MessageCell.AttachmentVideoView.Type = MessageCell.AttachmentVideoView.self
    public static var messageCellAttachmentView: MessageCell.AttachmentView.Type = MessageCell.AttachmentView.self
    public static var messageCellAttachmentStackView: MessageCell.AttachmentStackView.Type = MessageCell.AttachmentStackView.self
    public static var messageCellInfoView: MessageCell.InfoView.Type = MessageCell.InfoView.self
    public static var messageCellInfoViewBackgroundView: MessageCell.InfoViewBackgroundView.Type = MessageCell.InfoViewBackgroundView.self
    public static var messageCellForwardView: MessageCell.ForwardView.Type = MessageCell.ForwardView.self
    public static var messageCellLinkStackView: MessageCell.LinkStackView.Type = MessageCell.LinkStackView.self
    public static var messageCellLinkView: MessageCell.LinkView.Type = MessageCell.LinkView.self
    public static var messageCellReactionTotalView: MessageCell.ReactionTotalView.Type = MessageCell.ReactionTotalView.self
    public static var messageCellReactionLabel: MessageCell.ReactionLabel.Type = MessageCell.ReactionLabel.self
    public static var messageCellReplyView: MessageCell.ReplyView.Type = MessageCell.ReplyView.self
    public static var messageCellReplyCountView: MessageCell.ReplyCountView.Type = MessageCell.ReplyCountView.self
    public static var messageCellReplyArrowView: MessageCell.ReplyArrowView.Type = MessageCell.ReplyArrowView.self
    public static var messageCellUnreadMessagesSeparatorView: MessageCell.UnreadMessagesSeparatorView.Type = MessageCell.UnreadMessagesSeparatorView.self
    
    
    public static var actionController: ActionController.Type = ActionController.self
    
    public static var menuCell: MenuCell.Type = MenuCell.self
    public static var menuController: MenuController.Type = MenuController.self
    
    
    
    
    public static var loader: LoaderRepresentable.Type = LoaderView.self
    
    public static var logger: SCTUIKitLog.Type = SCTUIKitLog.self
}
