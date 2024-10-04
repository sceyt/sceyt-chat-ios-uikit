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
    
    public struct Appearance {
        public var navigationBarAppearance: NavigationBarAppearance = {
            $0.standardAppearance?.backgroundColor = .surface1
            return $0
        }(NavigationBarAppearance())

        //        public var coverViewBackgroundColor: UIColor? = .clear
        //
        // review searchBar.barTintColor = appearance.searchBarAppearance.backgroundColor
        public var backgroundColor: UIColor = .background
        public var headerAppearance: HeaderView.Appearance = HeaderView.appearance
        public var emptyStateAppearance: EmptyStateView.Appearance = .init(
            icon: .noMessages,
            title: L10n.Channel.NoMessages.title,
            message: L10n.Channel.NoMessages.message
        )
        public var scrollDownAppearance: ScrollDownView.Appearance = ScrollDownView.appearance
        public var dateSeparatorAppearance: DateSeparatorView.Appearance = DateSeparatorView.appearance
        public var reactionPickerAppearance: ReactionPickerViewController.Appearance = ReactionPickerViewController.appearance
        public var enableDateSeparator: Bool = true
        public var enableScrollDownButton: Bool = true
        public var messageCellAppearance: MessageCell.Appearance = MessageCell.appearance
        public var searchBarAppearance: SearchBarAppearance = SearchBarAppearance(placeholder: L10n.Channel.Search.search)
        
        public var messageInputAppearance: MessageInputViewController.Appearance = MessageInputViewController.appearance
        
        public var messageShareBodyFormatter: any MessageFormatting = SceytChatUIKit.shared.formatters.messageShareBodyFormatter
        public var unreadCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.unreadCountFormatter
        
        
        // Initializer with default values
        public init(
            navigationBarAppearance: NavigationBarAppearance = {
                $0.standardAppearance?.backgroundColor = .surface1
                return $0
            }(NavigationBarAppearance()),
            backgroundColor: UIColor = .background,
            headerAppearance: HeaderView.Appearance = HeaderView.appearance,
            emptyStateAppearance: EmptyStateView.Appearance = .init(
                icon: .noMessages,
                title: L10n.Channel.NoMessages.title,
                message: L10n.Channel.NoMessages.message
            ),
            scrollDownAppearance: ScrollDownView.Appearance = ScrollDownView.appearance,
            dateSeparatorAppearance: DateSeparatorView.Appearance = DateSeparatorView.appearance,
            reactionPickerAppearance: ReactionPickerViewController.Appearance = ReactionPickerViewController.appearance,
            enableDateSeparator: Bool = true,
            enableScrollDownButton: Bool = true,
            messageCellAppearance: MessageCell.Appearance = MessageCell.appearance,
            searchBarAppearance: SearchBarAppearance = SearchBarAppearance(placeholder: L10n.Channel.Search.search),
            messageInputAppearance: MessageInputViewController.Appearance = MessageInputViewController.appearance,
            messageShareBodyFormatter: any MessageFormatting = SceytChatUIKit.shared.formatters.messageShareBodyFormatter,
            unreadCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.unreadCountFormatter
        ) {
            self.navigationBarAppearance = navigationBarAppearance
            self.backgroundColor = backgroundColor
            self.headerAppearance = headerAppearance
            self.emptyStateAppearance = emptyStateAppearance
            self.scrollDownAppearance = scrollDownAppearance
            self.dateSeparatorAppearance = dateSeparatorAppearance
            self.reactionPickerAppearance = reactionPickerAppearance
            self.enableDateSeparator = enableDateSeparator
            self.enableScrollDownButton = enableScrollDownButton
            self.messageCellAppearance = messageCellAppearance
            self.searchBarAppearance = searchBarAppearance
            self.messageInputAppearance = messageInputAppearance
            self.messageShareBodyFormatter = messageShareBodyFormatter
            self.unreadCountFormatter = unreadCountFormatter
        }
    }
}


////emptyState: Int, (Android Only)
////emptyStateForSelfChannel: Int,(Android Only)
////loadingState: Int,(Android Only)

//enableDateSeparator: Boolean,
//sameSenderMessageDistance: Int
//differentSenderMessageDistance: Int

