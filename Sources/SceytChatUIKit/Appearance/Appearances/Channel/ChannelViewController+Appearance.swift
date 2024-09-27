//
//  ChannelViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        //        public var coverViewBackgroundColor: UIColor? = .clear
        //        public var navigationBarBackgroundColor: UIColor? = .background
        //        public var searchBarBackgroundColor: UIColor? = .surface1
        //        public var searchBarActivityIndicatorColor: UIColor? = .iconInactive
        //
        public lazy var backgroundColor: UIColor = .background
        public lazy var headerAppearance: HeaderView.Appearance = HeaderView.appearance
        public lazy var emptyStateAppearance: EmptyStateView.Appearance = .init(icon: .noMessages,
                                                                                title: L10n.Channel.NoMessages.title,
                                                                                message: L10n.Channel.NoMessages.message)
        public lazy var scrollDownAppearance: ScrollDownView.Appearance = ScrollDownView.appearance
        public lazy var dateSeparatorAppearance: DateSeparatorView.Appearance = DateSeparatorView.appearance
        public lazy var reactionPickerAppearance: ReactionPickerViewController.Appearance = ReactionPickerViewController.appearance
        public lazy var enableScrollDownButton: Bool = true
        public lazy var messageCellAppearance: MessageCell.Appearance = MessageCell.appearance
        public lazy var searchBarAppearance: SearchBarAppearance = SearchBarAppearance(placeholder: L10n.Channel.Search.search)
        // review searchBar.barTintColor = appearance.searchBarAppearance.backgroundColor
        //        public var reactionPickerAppearance: ReactionPickerViewController.Appearance = .init()

        public lazy var messageInputAppearance: MessageInputViewController.Appearance = MessageInputViewController.appearance
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            headerAppearance: HeaderView.Appearance = HeaderView.appearance,
            emptyStateAppearance: EmptyStateView.Appearance = .init(icon: .noMessages,
                                                                    title: L10n.Channel.NoMessages.title,
                                                                    message: L10n.Channel.NoMessages.message),
            scrollDownAppearance: ScrollDownView.Appearance = ScrollDownView.appearance,
            dateSeparatorAppearance: DateSeparatorView.Appearance = DateSeparatorView.appearance,
            reactionPickerAppearance: ReactionPickerViewController.Appearance = ReactionPickerViewController.appearance,
            enableScrollDownButton: Bool = true,
            messageCellAppearance: MessageCell.Appearance = MessageCell.appearance,
            searchBarAppearance: SearchBarAppearance = SearchBarAppearance(placeholder: L10n.Channel.Search.search),
            messageInputAppearance: MessageInputViewController.Appearance = MessageInputViewController.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.headerAppearance = headerAppearance
            self.emptyStateAppearance = emptyStateAppearance
            self.scrollDownAppearance = scrollDownAppearance
            self.dateSeparatorAppearance = dateSeparatorAppearance
            self.reactionPickerAppearance = reactionPickerAppearance
            self.enableScrollDownButton = enableScrollDownButton
            self.messageCellAppearance = messageCellAppearance
            self.searchBarAppearance = searchBarAppearance
            self.messageInputAppearance = messageInputAppearance
        }
    }
}


////emptyState: Int, (Android Only)
////emptyStateForSelfChannel: Int,(Android Only)
////loadingState: Int,(Android Only)
//navigationBarBackgroundColor: UIColor (iOS only)
//searchBarBackgroundColor: UIColor (iOS only)
//searchBarActivityIndicatorColor: UIColor (iOS only)




//enableDateSeparator: Boolean,
//sameSenderMessageDistance: Int
//differentSenderMessageDistance: Int

