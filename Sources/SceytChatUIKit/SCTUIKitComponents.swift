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
    
    // Channel list VC
    public static var channelListVC: ChannelListVC.Type = ChannelListVC.self
    public static var channelListVM: ChannelListVM.Type = ChannelListVM.self
    public static var channelListRouter: ChannelListRouter.Type = ChannelListRouter.self
    
    public static var channelTableView: ChannelTableView.Type = ChannelTableView.self
    // Channel Cell (Channel list item)
    public static var channelCell: ChannelCell.Type = ChannelCell.self
    // The empty view (when there is no any channels)
    public static var channelListEmptyView: ChannelListEmptyView.Type = ChannelListEmptyView.self
    public static var noDataView: NoDataView.Type = NoDataView.self
    public static var channelCreatedView: ChannelCreatedView.Type = ChannelCreatedView.self

    // Channel VC
    public static var channelVC: ChannelVC.Type = ChannelVC.self
    public static var channelVM: ChannelVM.Type = ChannelVM.self
    public static var channelRouter: ChannelRouter.Type = ChannelRouter.self
    public static var channelCollectionView: ChannelCollectionView.Type = ChannelCollectionView.self
    public static var channelCollectionViewLayout: ChannelCollectionViewLayout.Type = ChannelCollectionViewLayout.self
    public static var channelUnreadCountView: ChannelUnreadCountView.Type = ChannelUnreadCountView.self
    public static var channelTitleView: ChannelVC.TitleView.Type = ChannelVC.TitleView.self
    public static var channelBottomView: ChannelVC.BottomView.Type = ChannelVC.BottomView.self

    public static var channelProfileVC: ChannelProfileVC.Type = ChannelProfileVC.self
    public static var channelProfileVM: ChannelProfileVM.Type = ChannelProfileVM.self
    public static var channelProfileRouter: ChannelProfileRouter.Type = ChannelProfileRouter.self
    
    public static var channelProfileHeaderCell: ChannelProfileHeaderCell.Type = ChannelProfileHeaderCell.self
    public static var channelProfileMenuCell: ChannelProfileMenuCell.Type = ChannelProfileMenuCell.self
    public static var channelProfileDescriptionCell: ChannelProfileDescriptionCell.Type = ChannelProfileDescriptionCell.self
    public static var channelProfileItemCell: ChannelProfileItemCell.Type = ChannelProfileItemCell.self
    public static var channelProfileContainerCell: ChannelProfileContainerCell.Type = ChannelProfileContainerCell.self
    
    public static var channelProfileEditVC: ChannelProfileEditVC.Type = ChannelProfileEditVC.self
    public static var channelProfileEditAvatarCell: ChannelProfileEditAvatarCell.Type = ChannelProfileEditAvatarCell.self
    public static var channelProfileEditFieldCell: ChannelProfileEditFieldCell.Type = ChannelProfileEditFieldCell.self
    public static var channelProfileEditURICell: ChannelProfileEditURICell.Type = ChannelProfileEditURICell.self

    public static var channelProfileEditVM: ChannelProfileEditVM.Type = ChannelProfileEditVM.self

    public static var channelMemberListVC: ChannelMemberListVC.Type = ChannelMemberListVC.self
    public static var channelMemberListVM: ChannelMemberListVM.Type = ChannelMemberListVM.self
    public static var channelMemberListRouter: ChannelMemberListRouter.Type = ChannelMemberListRouter.self
    public static var channelMemberCell: ChannelMemberCell.Type = ChannelMemberCell.self
    public static var channelMemberAddCell: ChannelMemberAddCell.Type = ChannelMemberAddCell.self
    public static var channelSelectingView: ChannelVC.SelectingView.Type = ChannelVC.SelectingView.self

    public static var channelMediaListView: ChannelMediaListView.Type = ChannelMediaListView.self
    public static var channelFileListView: ChannelFileListView.Type = ChannelFileListView.self
    public static var channelLinkListView: ChannelLinkListView.Type = ChannelLinkListView.self
    public static var channelVoiceListView: ChannelVoiceListView.Type = ChannelVoiceListView.self
    public static var channelProfileImageAttachmentCell: ChannelProfileImageAttachmentCell.Type = ChannelProfileImageAttachmentCell.self
    public static var channelProfileVideoAttachmentCell: ChannelProfileVideoAttachmentCell.Type = ChannelProfileVideoAttachmentCell.self
    public static var channelProfileFileHeaderView: ChannelProfileFileHeaderView.Type = ChannelProfileFileHeaderView.self
    public static var channelProfileFileCell: ChannelProfileFileCell.Type = ChannelProfileFileCell.self
    public static var channelProfileLinkCell: ChannelProfileLinkCell.Type = ChannelProfileLinkCell.self
    public static var channelProfileVoiceCell: ChannelProfileVoiceCell.Type = ChannelProfileVoiceCell.self
    public static var channelAvatarVC: ChannelAvatarVC.Type = ChannelAvatarVC.self
    public static var channelAvatarVM: ChannelAvatarVM.Type = ChannelAvatarVM.self

    public static var holdButton: HoldButton.Type = HoldButton.self
    
    public static var channelAttachmentListVM: ChannelAttachmentListVM.Type = ChannelAttachmentListVM.self
    
    public static var segmentedControlView: SegmentedControlView.Type = SegmentedControlView.self
    
    public static var composerVC: ComposerVC.Type = ComposerVC.self
    public static var composerRouter: ComposerRouter.Type = ComposerRouter.self
    public static var composerMediaView: ComposerVC.MediaView.Type = ComposerVC.MediaView.self
    public static var composerInputTextView: ComposerVC.InputTextView.Type = ComposerVC.InputTextView.self
    public static var composerActionView: ComposerVC.ActionView.Type = ComposerVC.ActionView.self
    
    public static var composerAttachmentThumbnailView: ComposerVC.ThumbnailView.Type = ComposerVC.ThumbnailView.self
    
    public static var mentioningUserListVC: MentioningUserListVC.Type = MentioningUserListVC.self
    public static var mentioningUserListVM: MentioningUserListVM.Type = MentioningUserListVM.self
    public static var mentioningUserViewCell: MentioningUserViewCell.Type = MentioningUserViewCell.self
    
    public static var outgoingMessageCell: OutgoingMessageCell.Type = OutgoingMessageCell.self
    public static var incomingMessageCell: IncomingMessageCell.Type = IncomingMessageCell.self
    public static var messageSectionSeparatorView: MessageSectionSeparatorView.Type = MessageSectionSeparatorView.self
    
    public static var messageInfoVC: MessageInfoVC.Type = MessageInfoVC.self
    public static var messageInfoVM: MessageInfoVM.Type = MessageInfoVM.self
    public static var messageInfoHeaderView: MessageInfoVC.HeaderView.Type = MessageInfoVC.HeaderView.self
    public static var messageInfoMessageCell: MessageInfoVC.MessageCell.Type = MessageInfoVC.MessageCell.self
    public static var messageInfoMarkerCell: MessageInfoVC.MarkerCell.Type = MessageInfoVC.MarkerCell.self
    
    public static var channelForwardVC: ChannelForwardVC.Type = ChannelForwardVC.self
    public static var channelForwardVM: ChannelForwardVM.Type = ChannelForwardVM.self
    public static var channelForwardRouter: ChannelForwardRouter.Type = ChannelForwardRouter.self

    public static var channelSearchResultsVC: ChannelSearchResultsVC.Type = ChannelSearchResultsVC.self

    public static var imagePickerVC: PhotosPickerVC.Type = PhotosPickerVC.self
    public static var imagePickerCell: PhotosPickerCell.Type = PhotosPickerCell.self
    public static var imagePickerCollectionView: PhotosPickerCollectionView.Type = PhotosPickerCollectionView.self
    public static var imagePickerCollectionViewLayout: PhotosPickerCollectionViewLayout.Type = PhotosPickerCollectionViewLayout.self
    
    public static var imageCropperVC: ImageCropperVC.Type = ImageCropperVC.self
    public static var imageCropperVM: ImageCropperVM.Type = ImageCropperVM.self

    public static var circularProgressView: CircularProgressView.Type = CircularProgressView.self
    public static var playerView: PlayerView.Type = PlayerView.self
    public static var typingView: TypingView.Type = TypingView.self
    public static var timeLabel: TimeLabel.Type = TimeLabel.self
    public static var checkBoxView: CheckBoxView.Type = CheckBoxView.self
    public static var circleImageView: CircleImageView.Type = CircleImageView.self
    
    public static var previewerNavigationController: PreviewerNavigationController.Type = PreviewerNavigationController.self
    public static var previewerCarouselVC: PreviewerCarouselVC.Type = PreviewerCarouselVC.self
    public static var previewerVC: PreviewerVC.Type = PreviewerVC.self
    public static var previewerRouter: PreviewerRouter.Type = PreviewerRouter.self
    public static var previewerVM: PreviewerVM.Type = PreviewerVM.self
    
    public static var emojiListVC: EmojiListVC.Type = EmojiListVC.self
    public static var emojiListVM: EmojiListVM.Type = EmojiListVM.self
    public static var emojiListCollectionViewCell: EmojiListCollectionViewCell.Type = EmojiListCollectionViewCell.self
    public static var emojiListSectionHeaderView: EmojiListSectionHeaderView.Type = EmojiListSectionHeaderView.self
    
    public static var userReactionListVC: UserReactionListVC.Type = UserReactionListVC.self
    public static var userReactionCell: UserReactionCell.Type = UserReactionCell.self
    public static var reactionPageVC: ReactionVC.Type = ReactionVC.self
    public static var reactionScoreCell: ReactionScoreCell.Type = ReactionScoreCell.self
    
    public static var createNewChannelVC: CreateNewChannelVC.Type = CreateNewChannelVC.self
    public static var createNewChannelVM: CreateNewChannelVM.Type = CreateNewChannelVM.self
    public static var createChatActionsView: CreateChatActionsView.Type = CreateChatActionsView.self
    public static var channelUserCell: ChannelUserCell.Type = ChannelUserCell.self
    public static var createChannelUserCell: CreateChannelUserCell.Type = CreateChannelUserCell.self
    public static var createChannelHeaderView: CreateChannelHeaderView.Type = CreateChannelHeaderView.self

    public static var textLabel: TextLabel.Type = TextLabel.self
    
    // Models
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
    public static var channelMessageMarkerProvider: ChannelMessageMarkerProvider.Type = ChannelMessageMarkerProvider.self
    public static var messageReactionProvider: MessageReactionProvider.Type = MessageReactionProvider.self
    public static var attachmentTransfer: AttachmentTransfer.Type = AttachmentTransfer.self
    
    public static var hud: HUD.Type = KitHUD.self
    
    public static var logger: SCTUIKitLog.Type = SCTUIKitLog.self
}
