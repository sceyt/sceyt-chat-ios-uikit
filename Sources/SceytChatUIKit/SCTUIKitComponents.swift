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
    public static var channelListVC: ChannelListVC.Type = ChannelListVC.self
    public static var channelListVM: ChannelListVM.Type = ChannelListVM.self
    public static var channelListRouter: ChannelListRouter.Type = ChannelListRouter.self
    public static var channelCell: ChannelCell.Type = ChannelCell.self
    public static var channelListEmptyStateView: ChannelListVC.EmptyStateView.Type = ChannelListVC.EmptyStateView.self
    public static var noDataView: NoDataView.Type = NoDataView.self
    public static var channelCreatedView: ChannelCreatedView.Type = ChannelCreatedView.self
    public static var channelVC: ChannelVC.Type = ChannelVC.self
    public static var channelVM: ChannelVM.Type = ChannelVM.self
    public static var channelRouter: ChannelRouter.Type = ChannelRouter.self
    public static var channelMessagesCollectionView: ChannelVC.MessagesCollectionView.Type = ChannelVC.MessagesCollectionView.self
    public static var channelMessagesCollectionViewLayout: ChannelVC.MessagesCollectionViewLayout.Type = ChannelVC.MessagesCollectionViewLayout.self
    public static var channelScrollDownView: ChannelVC.ScrollDownView.Type = ChannelVC.ScrollDownView.self
    public static var channelHeaderView: ChannelVC.HeaderView.Type = ChannelVC.HeaderView.self
    public static var inputCoverView: InputVC.CoverView.Type = InputVC.CoverView.self
    public static var channelDisplayedTimer: ChannelVC.DisplayedTimer.Type = ChannelVC.DisplayedTimer.self
    public static var inputMessageSearchControlsView: InputVC.MessageSearchControlsView.Type = InputVC.MessageSearchControlsView.self

    public static var channelInfoVC: ChannelInfoVC.Type = ChannelInfoVC.self
    public static var simultaneousGestureTableView: SimultaneousGestureTableView.Type = SimultaneousGestureTableView.self
    public static var channelProfileVM: ChannelProfileVM.Type = ChannelProfileVM.self
    public static var channelProfileRouter: ChannelProfileRouter.Type = ChannelProfileRouter.self
    
    public static var channelInfoDetailsCell: ChannelInfoVC.DetailsCell.Type = ChannelInfoVC.DetailsCell.self
    public static var channelInfoDescriptionCell: ChannelInfoVC.DescriptionCell.Type = ChannelInfoVC.DescriptionCell.self
    public static var channelInfoOptionCell: ChannelInfoVC.OptionCell.Type = ChannelInfoVC.OptionCell.self
    public static var channelInfoContainerCell: ChannelInfoVC.ContainerCell.Type = ChannelInfoVC.ContainerCell.self
    
    public static var editChannelVC: EditChannelVC.Type = EditChannelVC.self
    public static var editChannelAvatarCell: EditChannelVC.AvatarCell.Type = EditChannelVC.AvatarCell.self
    public static var editChannelTextFieldCell: EditChannelVC.TextFieldCell.Type = EditChannelVC.TextFieldCell.self
    public static var editChannelURICell: EditChannelVC.URICell.Type = EditChannelVC.URICell.self

    public static var channelProfileEditVM: ChannelProfileEditVM.Type = ChannelProfileEditVM.self

    public static var channelMemberListVC: ChannelMemberListVC.Type = ChannelMemberListVC.self
    public static var channelMemberListVM: ChannelMemberListVM.Type = ChannelMemberListVM.self
    public static var channelMemberListRouter: ChannelMemberListRouter.Type = ChannelMemberListRouter.self
    public static var channelMemberCell: ChannelMemberCell.Type = ChannelMemberCell.self
    public static var channelMemberAddCell: ChannelMemberAddCell.Type = ChannelMemberAddCell.self
    public static var inputSelectedMessagesActionsView: InputVC.SelectedMessagesActionsView.Type = InputVC.SelectedMessagesActionsView.self
    
    public static var channelInfoMediaCollectionView: ChannelInfoVC.MediaCollectionView.Type = ChannelInfoVC.MediaCollectionView.self
    public static var channelInfoFileCollectionView: ChannelInfoVC.FileCollectionView.Type = ChannelInfoVC.FileCollectionView.self
    public static var channelInfoLinkCollectionView: ChannelInfoVC.LinkCollectionView.Type = ChannelInfoVC.LinkCollectionView.self
    public static var channelInfoVoiceCollectionView: ChannelInfoVC.VoiceCollectionView.Type = ChannelInfoVC.VoiceCollectionView.self
    public static var channelInfoImageAttachmentCell: ChannelInfoVC.ImageAttachmentCell.Type = ChannelInfoVC.ImageAttachmentCell.self
    public static var channelInfoVideoAttachmentCell: ChannelInfoVC.VideoAttachmentCell.Type = ChannelInfoVC.VideoAttachmentCell.self
    public static var channelInfoAttachmentHeaderView: ChannelInfoVC.AttachmentHeaderView.Type = ChannelInfoVC.AttachmentHeaderView.self
    public static var channelInfoFileCell: ChannelInfoVC.FileCell.Type = ChannelInfoVC.FileCell.self
    public static var channelInfoLinkCell: ChannelInfoVC.LinkCell.Type = ChannelInfoVC.LinkCell.self
    public static var channelInfoVoiceCell: ChannelInfoVC.VoiceCell.Type = ChannelInfoVC.VoiceCell.self
    public static var imagePreviewVC: ImagePreviewVC.Type = ImagePreviewVC.self
    public static var channelAvatarVM: ChannelAvatarVM.Type = ChannelAvatarVM.self

    
    public static var channelAttachmentListVM: ChannelAttachmentListVM.Type = ChannelAttachmentListVM.self
    
    public static var segmentedControlView: SegmentedControlView.Type = SegmentedControlView.self
    
    public static var inputVC: InputVC.Type = InputVC.self
    public static var inputRouter: InputRouter.Type = InputRouter.self
    public static var inputMediaView: InputVC.MediaView.Type = InputVC.MediaView.self
    public static var inputTextView: InputVC.InputTextView.Type = InputVC.InputTextView.self
    public static var inputMessageActionsView: InputVC.MessageActionsView.Type = InputVC.MessageActionsView.self
    public static var inputVoiceRecorderView: InputVC.VoiceRecorderView.Type = InputVC.VoiceRecorderView.self
    public static var inputVoiceRecordPlaybackView: InputVC.VoiceRecordPlaybackView.Type = InputVC.VoiceRecordPlaybackView.self
    public static var inputVoiceRecordPlaybackPlayerView: InputVC.VoiceRecordPlaybackView.PlayerView.Type = InputVC.VoiceRecordPlaybackView.PlayerView.self
    public static var inputThumbnailView: InputVC.ThumbnailView.Type = InputVC.ThumbnailView.self
    public static var inputThumbnailViewMediaView: InputVC.ThumbnailView.MediaView.Type = InputVC.ThumbnailView.MediaView.self
    public static var inputThumbnailViewFileView: InputVC.ThumbnailView.FileView.Type = InputVC.ThumbnailView.FileView.self
    public static var inputThumbnailViewTimeLabel: InputVC.ThumbnailView.TimeLabel.Type = InputVC.ThumbnailView.TimeLabel.self
    
    public static var inputMentionUsersListVC: InputVC.MentionUsersListVC.Type = InputVC.MentionUsersListVC.self
    public static var mentioningUserListVM: MentioningUserListVM.Type = MentioningUserListVM.self
    public static var inputMentionUsersCell: InputVC.MentionUsersListVC.MentionUserCell.Type = InputVC.MentionUsersListVC.MentionUserCell.self
    
    public static var channelOutgoingMessageCell: ChannelVC.OutgoingMessageCell.Type = ChannelVC.OutgoingMessageCell.self
    public static var channelIncomingMessageCell: ChannelVC.IncomingMessageCell.Type = ChannelVC.IncomingMessageCell.self
    public static var channelDateSeparatorView: ChannelVC.DateSeparatorView.Type = ChannelVC.DateSeparatorView.self
    
    public static var messageInfoVC: MessageInfoVC.Type = MessageInfoVC.self
    public static var messageInfoVM: MessageInfoVM.Type = MessageInfoVM.self
    public static var messageInfoHeaderView: MessageInfoVC.HeaderView.Type = MessageInfoVC.HeaderView.self
    public static var messageInfoMessageCell: MessageInfoVC.MessageCell.Type = MessageInfoVC.MessageCell.self
    public static var messageInfoMarkerCell: MessageInfoVC.MarkerCell.Type = MessageInfoVC.MarkerCell.self
    
    public static var forwardVC: ForwardVC.Type = ForwardVC.self
    public static var channelForwardVM: ChannelForwardVM.Type = ChannelForwardVM.self
    public static var channelForwardRouter: ChannelForwardRouter.Type = ChannelForwardRouter.self

    public static var channelSearchController: ChannelSearchController.Type = ChannelSearchController.self
    public static var channelSearchResultsVC: ChannelSearchResultsVC.Type = ChannelSearchResultsVC.self

    public static var mediaPickerVC: MediaPickerVC.Type = MediaPickerVC.self
    public static var mediaPickerFooterView: MediaPickerVC.FooterView.Type = MediaPickerVC.FooterView.self
    public static var mediaPickerAttachButton: MediaPickerVC.AttachButton.Type = MediaPickerVC.AttachButton.self
    
    public static var mediaPickerCell: MediaPickerVC.MediaCell.Type = MediaPickerVC.MediaCell.self
    public static var mediaPickerCollectionView: MediaPickerVC.MediaPickerCollectionView.Type = MediaPickerVC.MediaPickerCollectionView.self
    public static var mediaPickerCollectionViewLayout: MediaPickerVC.MediaPickerCollectionViewLayout.Type = MediaPickerVC.MediaPickerCollectionViewLayout.self
    
    public static var imageCropperVC: ImageCropperVC.Type = ImageCropperVC.self
    public static var imageCropperVM: ImageCropperVM.Type = ImageCropperVM.self

    public static var circularProgressView: CircularProgressView.Type = CircularProgressView.self
    public static var playerView: PlayerView.Type = PlayerView.self
    public static var typingView: TypingView.Type = TypingView.self
    public static var timeLabel: TimeLabel.Type = TimeLabel.self
    public static var checkBoxView: CheckBoxView.Type = CheckBoxView.self
    public static var circleImageView: CircleImageView.Type = CircleImageView.self
    
    public static var mediaPreviewerNavigationController: MediaPreviewerNavigationController.Type = MediaPreviewerNavigationController.self
    public static var mediaPreviewerCarouselVC: MediaPreviewerCarouselVC.Type = MediaPreviewerCarouselVC.self
    
    public static var mediaPreviewerVC: MediaPreviewerVC.Type = MediaPreviewerVC.self
    public static var previewerRouter: PreviewerRouter.Type = PreviewerRouter.self
    public static var previewerVM: PreviewerVM.Type = PreviewerVM.self
    public static var mediaPreviewerImageView: MediaPreviewerImageView.Type = MediaPreviewerImageView.self
    public static var mediaPreviewerScrollView: MediaPreviewerScrollView.Type = MediaPreviewerScrollView.self
    
    public static var emojiVC: EmojiVC.Type = EmojiVC.self // reactions popup
    public static var emojiListVC: EmojiListVC.Type = EmojiListVC.self
    public static var emojiListVM: EmojiListVM.Type = EmojiListVM.self
    public static var emojiListCollectionViewCell: EmojiListCollectionViewCell.Type = EmojiListCollectionViewCell.self
    public static var emojiListSectionHeaderView: EmojiListSectionHeaderView.Type = EmojiListSectionHeaderView.self
    
    public static var userReactionListVC: UserReactionListVC.Type = UserReactionListVC.self
    public static var userReactionCell: UserReactionCell.Type = UserReactionCell.self
    public static var reactionPageVC: ReactionVC.Type = ReactionVC.self
    public static var reactionScoreCell: ReactionScoreCell.Type = ReactionScoreCell.self
    
    public static var startChatVC: StartChatVC.Type = StartChatVC.self
    public static var createNewChannelVM: CreateNewChannelVM.Type = CreateNewChannelVM.self
    public static var startChatActionsView: StartChatVC.ActionsView.Type = StartChatVC.ActionsView.self
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
    public static var sheetVC: SheetVC.Type = SheetVC.self
    
    public static var badgeView: BadgeView.Type = BadgeView.self
    public static var circleButton: CircleButton.Type = CircleButton.self
    public static var connectionStateView: ConnectionStateView.Type = ConnectionStateView.self
    public static var documentPickerController: DocumentPickerController.Type = DocumentPickerController.self
    public static var filePreviewController: FilePreviewController.Type = FilePreviewController.self
    public static var imagePickerController: ImagePickerController.Type = ImagePickerController.self
    public static var markableTextField: MarkableTextField.Type = MarkableTextField.self
    public static var searchController: SearchController.Type = SearchController.self
    public static var waveformView: WaveformView.Type = WaveformView.self
    
    public static var channelAddMembersVC: ChannelAddMembersVC.Type = ChannelAddMembersVC.self
    public static var createGroupProfileView: CreateGroupVC.ProfileView.Type = CreateGroupVC.ProfileView.self
    public static var createGroupVC: CreateGroupVC.Type = CreateGroupVC.self
    public static var createChannelProfileView: CreateChannelVC.ProfileView.Type = CreateChannelVC.ProfileView.self
    public static var createChannelVC: CreateChannelVC.Type = CreateChannelVC.self
    public static var selectChannelMembersVC: SelectChannelMembersVC.Type = SelectChannelMembersVC.self
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
    
    
    
    
    public static var hud: HUD.Type = KitHUD.self
    
    public static var logger: SCTUIKitLog.Type = SCTUIKitLog.self
}
