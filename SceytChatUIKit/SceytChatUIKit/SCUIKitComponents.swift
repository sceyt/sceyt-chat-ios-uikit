//
//  SCUIKitComponents.swift
//  SceytChatUIKit
//

import Foundation

typealias Components = SCUIKitComponents

public struct SCUIKitComponents {
    //Channel list VC
    public static var channelListVC: ChannelListVC.Type = ChannelListVC.self
    public static var channelListVM: ChannelListVM.Type = ChannelListVM.self
    public static var channelListRouter: ChannelListRouter.Type = ChannelListRouter.self
    
    public static var channelTableView: ChannelTableView.Type = ChannelTableView.self
    //Channel Cell (Channel list item)
    public static var channelCell: ChannelCell.Type = ChannelCell.self
    //The empty view (when there is no any channels)
    public static var channelListEmptyView: ChannelListEmptyView.Type = ChannelListEmptyView.self
    
    //Channel VC
    public static var channelVC: ChannelVC.Type = ChannelVC.self
    public static var channelVM: ChannelVM.Type = ChannelVM.self
    public static var channelRouter: ChannelRouter.Type = ChannelRouter.self
    public static var channelCollectionView: ChannelCollectionView.Type = ChannelCollectionView.self
    public static var channelCollectionViewLayout: ChannelCollectionViewLayout.Type = ChannelCollectionViewLayout.self
    public static var channelUnreadCountView: ChannelUnreadCountView.Type = ChannelUnreadCountView.self
    public static var channelTitleView: ChannelVC.TitleView.Type = ChannelVC.TitleView.self
    public static var channelBlockView: ChannelVC.BlockView.Type = ChannelVC.BlockView.self
    
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
    
    public static var channelMemberListVC: ChannelMemberListVC.Type = ChannelMemberListVC.self
    public static var channelMemberListVM: ChannelMemberListVM.Type = ChannelMemberListVM.self
    public static var channelMemberListRouter: ChannelMemberListRouter.Type = ChannelMemberListRouter.self
    public static var channelMemberCell: ChannelMemberCell.Type = ChannelMemberCell.self
    public static var channelMemberAddCell: ChannelMemberAddCell.Type = ChannelMemberAddCell.self
    
    
    public static var channelMediaListView: ChannelMediaListView.Type = ChannelMediaListView.self
    public static var channelFileListView: ChannelFileListView.Type = ChannelFileListView.self
    public static var channelLinkListView: ChannelLinkListView.Type = ChannelLinkListView.self
    public static var channelVoiceListView: ChannelVoiceListView.Type = ChannelVoiceListView.self
    public static var channelMediaImageCell: ChannelMediaImageCell.Type = ChannelMediaImageCell.self
    public static var channelMediaVideoCell: ChannelMediaVideoCell.Type = ChannelMediaVideoCell.self
    public static var channelFileCell: ChannelFileCell.Type = ChannelFileCell.self
    public static var channelLinkCell: ChannelLinkCell.Type = ChannelLinkCell.self
    public static var channelVoiceCell: ChannelVoiceCell.Type = ChannelVoiceCell.self
    
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
    
    public static var imagePickerVC: PhotosPickerVC.Type = PhotosPickerVC.self
    public static var imagePickerCell: PhotosPickerCell.Type = PhotosPickerCell.self
    public static var imagePickerCollectionView: PhotosPickerCollectionView.Type = PhotosPickerCollectionView.self
    public static var imagePickerCollectionViewLayout: PhotosPickerCollectionViewLayout.Type = PhotosPickerCollectionViewLayout.self
    
    public static var circularProgressView: CircularProgressView.Type = CircularProgressView.self
    public static var playerView: PlayerView.Type = PlayerView.self
    public static var typingView: TypingView.Type = TypingView.self
    public static var timeLabel: TimeLabel.Type = TimeLabel.self
    public static var checkBoxView: CheckBoxView.Type = CheckBoxView.self
    public static var circleImageView: CircleImageView.Type = CircleImageView.self
    
    public static var previewerCarouselVC: PreviewerCarouselVC.Type = PreviewerCarouselVC.self
    public static var previewerVC: PreviewerVC.Type = PreviewerVC.self
    public static var previewerRouter: PreviewerRouter.Type = PreviewerRouter.self
    public static var previewerVM: PreviewerVM.Type = PreviewerVM.self
    
    public static var userReactionListVC: UserReactionListVC.Type = UserReactionListVC.self
    public static var userReactionCell: UserReactionCell.Type = UserReactionCell.self
    public static var reactionPageVC: ReactionVC.Type = ReactionVC.self
    public static var reactionScoreCell: ReactionScoreCell.Type = ReactionScoreCell.self    
    
    //Models
    public static var messageLayoutModel: MessageLayoutModel.Type = MessageLayoutModel.self
    public static var initialsBuilder: InitialsBuilder.Type = InitialsBuilder.self
    public static var imageBuilder: ImageBuilder.Type = ImageBuilder.self
    public static var videoProcessor: VideoProcessor.Type = VideoProcessor.self
    public static var avatarBuilder: AvatarBuilder.Type = AvatarBuilder.self
    public static var dataSession: SCDataSession?
    
    public static var channelEventHandler: ChannelEventHandler.Type = ChannelEventHandler.self
    
    
}

