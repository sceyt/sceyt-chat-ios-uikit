//
//  SceytChatUIKit+Components.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

typealias Components = SceytChatUIKit.Components

extension SceytChatUIKit {
    public enum Components {
        
        public static var navigationController: NavigationController.Type = NavigationController.self
        public static var channelListViewController: ChannelListViewController.Type = ChannelListViewController.self
        public static var channelListViewModel: ChannelListViewModel.Type = ChannelListViewModel.self
        public static var channelListRouter: ChannelListRouter.Type = ChannelListRouter.self
        public static var channelCell: ChannelListViewController.ChannelCell.Type = ChannelListViewController.ChannelCell.self
        public static var emptyStateView: EmptyStateView.Type = EmptyStateView.self
        public static var channelViewController: ChannelViewController.Type = ChannelViewController.self
        public static var channelViewModel: ChannelViewModel.Type = ChannelViewModel.self
        public static var channelRouter: ChannelRouter.Type = ChannelRouter.self
        public static var channelMessagesCollectionView: ChannelViewController.MessagesCollectionView.Type = ChannelViewController.MessagesCollectionView.self
        public static var channelMessagesCollectionViewLayout: ChannelViewController.MessagesCollectionViewLayout.Type = ChannelViewController.MessagesCollectionViewLayout.self
        public static var channelScrollDownView: ChannelViewController.ScrollDownView.Type = ChannelViewController.ScrollDownView.self
        public static var channelHeaderView: ChannelViewController.HeaderView.Type = ChannelViewController.HeaderView.self
        public static var messageInputCoverView: MessageInputViewController.CoverView.Type = MessageInputViewController.CoverView.self
        public static var channelDisplayedTimer: ChannelViewController.DisplayedTimer.Type = ChannelViewController.DisplayedTimer.self
        public static var messageInputMessageSearchControlsView: MessageInputViewController.MessageSearchControlsView.Type = MessageInputViewController.MessageSearchControlsView.self
        
        public static var channelInfoViewController: ChannelInfoViewController.Type = ChannelInfoViewController.self
        public static var simultaneousGestureTableView: SimultaneousGestureTableView.Type = SimultaneousGestureTableView.self
        public static var channelProfileViewModel: ChannelProfileViewModel.Type = ChannelProfileViewModel.self
        public static var channelProfileRouter: ChannelProfileRouter.Type = ChannelProfileRouter.self
        
        public static var channelInfoDetailsCell: ChannelInfoViewController.DetailsCell.Type = ChannelInfoViewController.DetailsCell.self
        public static var channelInfoDescriptionCell: ChannelInfoViewController.DescriptionCell.Type = ChannelInfoViewController.DescriptionCell.self
        public static var channelInfoOptionCell: ChannelInfoViewController.OptionCell.Type = ChannelInfoViewController.OptionCell.self
        public static var channelInfoContainerCell: ChannelInfoViewController.ContainerCell.Type = ChannelInfoViewController.ContainerCell.self
        
        public static var editChannelViewController: EditChannelViewController.Type = EditChannelViewController.self
        public static var channelEditAvatarCell: EditChannelViewController.AvatarCell.Type = EditChannelViewController.AvatarCell.self
        public static var channelEditTextFieldCell: EditChannelViewController.TextFieldCell.Type = EditChannelViewController.TextFieldCell.self
        public static var channelEditURICell: EditChannelViewController.URICell.Type = EditChannelViewController.URICell.self
        
        public static var channelProfileEditViewModel: ChannelProfileEditViewModel.Type = ChannelProfileEditViewModel.self
        
        public static var channelMemberListViewController: ChannelMemberListViewController.Type = ChannelMemberListViewController.self
        public static var channelMemberListViewModel: ChannelMemberListViewModel.Type = ChannelMemberListViewModel.self
        public static var channelMemberListRouter: ChannelMemberListRouter.Type = ChannelMemberListRouter.self
        public static var channelMemberCell: ChannelMemberListViewController.MemberCell.Type = ChannelMemberListViewController.MemberCell.self
        public static var channelAddMemberCell: ChannelMemberListViewController.AddMemberCell.Type = ChannelMemberListViewController.AddMemberCell.self
        public static var messageInputSelectedMessagesActionsView: MessageInputViewController.SelectedMessagesActionsView.Type = MessageInputViewController.SelectedMessagesActionsView.self
        
        public static var channelInfoMediaCollectionView: ChannelInfoViewController.MediaCollectionView.Type = ChannelInfoViewController.MediaCollectionView.self
        public static var channelInfoFileCollectionView: ChannelInfoViewController.FileCollectionView.Type = ChannelInfoViewController.FileCollectionView.self
        public static var channelInfoLinkCollectionView: ChannelInfoViewController.LinkCollectionView.Type = ChannelInfoViewController.LinkCollectionView.self
        public static var channelInfoVoiceCollectionView: ChannelInfoViewController.VoiceCollectionView.Type = ChannelInfoViewController.VoiceCollectionView.self
        public static var channelInfoImageAttachmentCell: ChannelInfoViewController.ImageAttachmentCell.Type = ChannelInfoViewController.ImageAttachmentCell.self
        public static var channelInfoVideoAttachmentCell: ChannelInfoViewController.VideoAttachmentCell.Type = ChannelInfoViewController.VideoAttachmentCell.self
        public static var channelInfoDateSeparatorView: ChannelInfoViewController.DateSeparatorView.Type = ChannelInfoViewController.DateSeparatorView.self
        public static var channelInfoFileCell: ChannelInfoViewController.FileCell.Type = ChannelInfoViewController.FileCell.self
        public static var channelInfoLinkCell: ChannelInfoViewController.LinkCell.Type = ChannelInfoViewController.LinkCell.self
        public static var channelInfoVoiceCell: ChannelInfoViewController.VoiceCell.Type = ChannelInfoViewController.VoiceCell.self
        public static var imagePreviewViewController: ImagePreviewViewController.Type = ImagePreviewViewController.self
        public static var channelAvatarViewModel: ChannelAvatarViewModel.Type = ChannelAvatarViewModel.self
        
        
        public static var channelAttachmentListViewModel: ChannelAttachmentListViewModel.Type = ChannelAttachmentListViewModel.self
        
        public static var segmentedControlView: SegmentedControlView.Type = SegmentedControlView.self
        public static var segmentedControl: SegmentedControl.Type = SegmentedControl.self

        public static var messageInputViewController: MessageInputViewController.Type = MessageInputViewController.self
        public static var inputRouter: InputRouter.Type = InputRouter.self
        public static var messageInputSelectedMediaView: MessageInputViewController.SelectedMediaView.Type = MessageInputViewController.SelectedMediaView.self
        public static var messageInputTextView: MessageInputViewController.InputTextView.Type = MessageInputViewController.InputTextView.self
        public static var messageInputMessageActionsView: MessageInputViewController.MessageActionsView.Type = MessageInputViewController.MessageActionsView.self
        public static var messageInputVoiceRecorderView: MessageInputViewController.VoiceRecorderView.Type = MessageInputViewController.VoiceRecorderView.self
        public static var messageInputVoiceRecordPlaybackView: MessageInputViewController.VoiceRecordPlaybackView.Type = MessageInputViewController.VoiceRecordPlaybackView.self
        public static var messageInputVoiceRecordPlaybackPlayerView: MessageInputViewController.VoiceRecordPlaybackView.PlayerView.Type = MessageInputViewController.VoiceRecordPlaybackView.PlayerView.self
        
        public static var messageInputThumbnailView: MessageInputViewController.ThumbnailView.Type = MessageInputViewController.ThumbnailView.self
        public static var messageInputThumbnailViewMediaView: MessageInputViewController.ThumbnailView.MediaView.Type = MessageInputViewController.ThumbnailView.MediaView.self
        public static var messageInputThumbnailViewFileView: MessageInputViewController.ThumbnailView.FileView.Type = MessageInputViewController.ThumbnailView.FileView.self
        public static var messageInputThumbnailViewTimeLabel: MessageInputViewController.ThumbnailView.TimeLabel.Type = MessageInputViewController.ThumbnailView.TimeLabel.self
        
        public static var messageInputMentionUsersListViewController: MessageInputViewController.MentionUsersListViewController.Type = MessageInputViewController.MentionUsersListViewController.self
        public static var mentioningUserListViewModel: MentioningUserListViewModel.Type = MentioningUserListViewModel.self
        public static var messageInputMentionUsersCell: MessageInputViewController.MentionUsersListViewController.MentionUserCell.Type = MessageInputViewController.MentionUsersListViewController.MentionUserCell.self
        
        public static var channelOutgoingMessageCell: ChannelViewController.OutgoingMessageCell.Type = ChannelViewController.OutgoingMessageCell.self
        public static var channelIncomingMessageCell: ChannelViewController.IncomingMessageCell.Type = ChannelViewController.IncomingMessageCell.self
        public static var channelDateSeparatorView: ChannelViewController.DateSeparatorView.Type = ChannelViewController.DateSeparatorView.self
        
        public static var messageInfoViewController: MessageInfoViewController.Type = MessageInfoViewController.self
        public static var messageInfoViewModel: MessageInfoViewModel.Type = MessageInfoViewModel.self
        public static var messageInfoHeaderView: MessageInfoViewController.HeaderView.Type = MessageInfoViewController.HeaderView.self
        public static var messageInfoMessageCell: MessageInfoViewController.MessageCell.Type = MessageInfoViewController.MessageCell.self
        public static var messageInfoMarkerCell: MessageInfoViewController.MarkerCell.Type = MessageInfoViewController.MarkerCell.self
        
        public static var forwardViewController: ForwardViewController.Type = ForwardViewController.self
        public static var channelForwardViewModel: ChannelForwardViewModel.Type = ChannelForwardViewModel.self
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
        public static var imageCropperViewModel: ImageCropperViewModel.Type = ImageCropperViewModel.self
        
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
        public static var previewerViewModel: PreviewerViewModel.Type = PreviewerViewModel.self
        public static var mediaPreviewerImageView: MediaPreviewerImageView.Type = MediaPreviewerImageView.self
        public static var mediaPreviewerScrollView: MediaPreviewerScrollView.Type = MediaPreviewerScrollView.self
        
        public static var reactionPickerViewController: ReactionPickerViewController.Type = ReactionPickerViewController.self // reactions popup
        public static var emojiPickerViewController: EmojiPickerViewController.Type = EmojiPickerViewController.self
        public static var emojiListViewModel: EmojiListViewModel.Type = EmojiListViewModel.self
        public static var emojiPickerCell: EmojiPickerViewController.EmojiCell.Type = EmojiPickerViewController.EmojiCell.self
        public static var emojiPickerSectionHeaderView: EmojiPickerViewController.SectionHeaderView.Type = EmojiPickerViewController.SectionHeaderView.self
        
        public static var reactedUserListViewController: ReactedUserListViewController.Type = ReactedUserListViewController.self
        public static var reactedUserReactionCell: ReactedUserListViewController.UserReactionCell.Type = ReactedUserListViewController.UserReactionCell.self
        public static var reactionsInfoViewController: ReactionsInfoViewController.Type = ReactionsInfoViewController.self
        public static var reactionsInfoHeaderCell: ReactionsInfoViewController.HeaderCell.Type = ReactionsInfoViewController.HeaderCell.self
        
        public static var startChatViewController: StartChatViewController.Type = StartChatViewController.self
        public static var createNewChannelViewModel: CreateNewChannelViewModel.Type = CreateNewChannelViewModel.self
        public static var startChatActionsView: StartChatViewController.ActionsView.Type = StartChatViewController.ActionsView.self
        public static var searchResultChannelCell: SearchResultChannelCell.Type = SearchResultChannelCell.self
        public static var selectableChannelCell: SelectableChannelCell.Type = SelectableChannelCell.self
        
        public static var userCell: UserCell.Type = UserCell.self
        public static var selectableUserCell: SelectableUserCell.Type = SelectableUserCell.self
        public static var separatorHeaderView: SeparatorHeaderView.Type = SeparatorHeaderView.self
        
        public static var textLabel: TextLabel.Type = TextLabel.self
        
        public static var messageLayoutModel: MessageLayoutModel.Type = MessageLayoutModel.self
        public static var messageAttachmentLayoutModel: MessageLayoutModel.AttachmentLayout.Type = MessageLayoutModel.AttachmentLayout.self
        public static var messageReplyLayoutModel: MessageLayoutModel.ReplyLayout.Type = MessageLayoutModel.ReplyLayout.self
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
        public static var audioWaveformView: AudioWaveformView.Type = AudioWaveformView.self
        
        public static var addMembersViewController: AddMembersViewController.Type = AddMembersViewController.self
        public static var createGroupDetailsView: CreateGroupViewController.DetailsView.Type = CreateGroupViewController.DetailsView.self
        public static var createGroupViewController: CreateGroupViewController.Type = CreateGroupViewController.self
        public static var createChannelDetailsView: CreateChannelViewController.DetailsView.Type = CreateChannelViewController.DetailsView.self
        public static var createChannelViewController: CreateChannelViewController.Type = CreateChannelViewController.self
        public static var selectUsersViewController: SelectUsersViewController.Type = SelectUsersViewController.self
        public static var selectedUserListView: SelectedUserListView.Type = SelectedUserListView.self
        public static var selectedChannelListView: SelectedChannelListView.Type = SelectedChannelListView.self
        public static var selectedBaseCell: SelectedBaseCell.Type = SelectedBaseCell.self
        public static var selectedChannelCell: SelectedChannelCell.Type = SelectedChannelCell.self
        public static var selectedUserCell: SelectedUserCell.Type = SelectedUserCell.self
        
        
        public static var messageCell: MessageCell.Type = MessageCell.self
        public static var messageCellAttachmentAudioView: MessageCell.AttachmentAudioView.Type = MessageCell.AttachmentAudioView.self
        public static var messageCellAttachmentFileView: MessageCell.AttachmentFileView.Type = MessageCell.AttachmentFileView.self
        public static var messageCellAttachmentImageView: MessageCell.AttachmentImageView.Type = MessageCell.AttachmentImageView.self
        public static var messageCellAttachmentVideoView: MessageCell.AttachmentVideoView.Type = MessageCell.AttachmentVideoView.self
        public static var messageCellAttachmentView: MessageCell.AttachmentView.Type = MessageCell.AttachmentView.self
        public static var messageCellAttachmentStackView: MessageCell.AttachmentStackView.Type = MessageCell.AttachmentStackView.self
        public static var messageCellInfoView: MessageCell.InfoView.Type = MessageCell.InfoView.self
        public static var messageCellForwardView: MessageCell.ForwardView.Type = MessageCell.ForwardView.self
        public static var messageCellLinkStackView: MessageCell.LinkStackView.Type = MessageCell.LinkStackView.self
        public static var messageCellLinkPreviewView: MessageCell.LinkPreviewView.Type = MessageCell.LinkPreviewView.self
        public static var messageCellReactionTotalView: MessageCell.ReactionTotalView.Type = MessageCell.ReactionTotalView.self
        public static var messageCellReactionLabel: MessageCell.ReactionLabel.Type = MessageCell.ReactionLabel.self
        public static var messageCellReplyView: MessageCell.ReplyView.Type = MessageCell.ReplyView.self
        public static var messageCellReplyCountView: MessageCell.ReplyCountView.Type = MessageCell.ReplyCountView.self
        public static var messageCellReplyArrowView: MessageCell.ReplyArrowView.Type = MessageCell.ReplyArrowView.self
        public static var messageCellUnreadMessagesSeparatorView: MessageCell.UnreadMessagesSeparatorView.Type = MessageCell.UnreadMessagesSeparatorView.self
        
        
        public static var actionController: ActionController.Type = ActionController.self
        
        public static var menuCell: MenuController.MenuCell.Type = MenuController.MenuCell.self
        public static var menuController: MenuController.Type = MenuController.self
        
        public static var loader: LoaderRepresentable.Type = LoaderView.self
        
        public static var logger: SceytChatUIKit.Logger.Type = SceytChatUIKit.Logger.self
    }
}
