//
//  ChannelViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: {
            $0.appearance.standardAppearance?.backgroundColor = .surface1
            return $0.appearance
        }(NavigationBarAppearance()),
        backgroundColor: .background,
        headerAppearance: HeaderView.appearance,
        emptyStateAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .noMessages,
            title: L10n.Channel.NoMessages.title,
            message: L10n.Channel.NoMessages.message
        ),
        scrollDownAppearance: ScrollDownView.appearance,
        dateSeparatorAppearance: DateSeparatorView.appearance,
        reactionPickerAppearance: ReactionPickerViewController.appearance,
        enableDateSeparator: true,
        enableScrollDownButton: true,
        messageCellAppearance: MessageCell.appearance,
        searchBarAppearance: SearchBarAppearance.Appearance(
            reference: SearchBarAppearance.appearance,
            placeholder: L10n.Channel.Search.search
        ),
        messageInputAppearance: MessageInputViewController.appearance,
        messageShareBodyFormatter: SceytChatUIKit.shared.formatters.messageShareBodyFormatter,
        unreadCountFormatter: SceytChatUIKit.shared.formatters.unreadCountFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        //        public var coverViewBackgroundColor: UIColor? = .clear
        //
        // review searchBar.barTintColor = appearance.searchBarAppearance.backgroundColor
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, HeaderView.Appearance>
        public var headerAppearance: HeaderView.Appearance
        
        @Trackable<Appearance, EmptyStateView.Appearance>
        public var emptyStateAppearance: EmptyStateView.Appearance
        
        @Trackable<Appearance, ScrollDownView.Appearance>
        public var scrollDownAppearance: ScrollDownView.Appearance
        
        @Trackable<Appearance, DateSeparatorView.Appearance>
        public var dateSeparatorAppearance: DateSeparatorView.Appearance
        
        @Trackable<Appearance, ReactionPickerViewController.Appearance>
        public var reactionPickerAppearance: ReactionPickerViewController.Appearance
        
        @Trackable<Appearance, Bool>
        public var enableDateSeparator: Bool
        
        @Trackable<Appearance, Bool>
        public var enableScrollDownButton: Bool
        
        @Trackable<Appearance, MessageCell.Appearance>
        public var messageCellAppearance: MessageCell.Appearance
        
        @Trackable<Appearance, SearchBarAppearance.Appearance>
        public var searchBarAppearance: SearchBarAppearance.Appearance
        
        @Trackable<Appearance, MessageInputViewController.Appearance>
        public var messageInputAppearance: MessageInputViewController.Appearance
        
        @Trackable<Appearance, any MessageFormatting>
        public var messageShareBodyFormatter: any MessageFormatting
        
        @Trackable<Appearance, any UIntFormatting>
        public var unreadCountFormatter: any UIntFormatting
        
        public init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            headerAppearance: HeaderView.Appearance,
            emptyStateAppearance: EmptyStateView.Appearance,
            scrollDownAppearance: ScrollDownView.Appearance,
            dateSeparatorAppearance: DateSeparatorView.Appearance,
            reactionPickerAppearance: ReactionPickerViewController.Appearance,
            enableDateSeparator: Bool,
            enableScrollDownButton: Bool,
            messageCellAppearance: MessageCell.Appearance,
            searchBarAppearance: SearchBarAppearance.Appearance,
            messageInputAppearance: MessageInputViewController.Appearance,
            messageShareBodyFormatter: any MessageFormatting,
            unreadCountFormatter: any UIntFormatting
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._headerAppearance = Trackable(value: headerAppearance)
            self._emptyStateAppearance = Trackable(value: emptyStateAppearance)
            self._scrollDownAppearance = Trackable(value: scrollDownAppearance)
            self._dateSeparatorAppearance = Trackable(value: dateSeparatorAppearance)
            self._reactionPickerAppearance = Trackable(value: reactionPickerAppearance)
            self._enableDateSeparator = Trackable(value: enableDateSeparator)
            self._enableScrollDownButton = Trackable(value: enableScrollDownButton)
            self._messageCellAppearance = Trackable(value: messageCellAppearance)
            self._searchBarAppearance = Trackable(value: searchBarAppearance)
            self._messageInputAppearance = Trackable(value: messageInputAppearance)
            self._messageShareBodyFormatter = Trackable(value: messageShareBodyFormatter)
            self._unreadCountFormatter = Trackable(value: unreadCountFormatter)
        }
        
        public init(
            reference: ChannelViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            headerAppearance: HeaderView.Appearance? = nil,
            emptyStateAppearance: EmptyStateView.Appearance? = nil,
            scrollDownAppearance: ScrollDownView.Appearance? = nil,
            dateSeparatorAppearance: DateSeparatorView.Appearance? = nil,
            reactionPickerAppearance: ReactionPickerViewController.Appearance? = nil,
            enableDateSeparator: Bool? = nil,
            enableScrollDownButton: Bool? = nil,
            messageCellAppearance: MessageCell.Appearance? = nil,
            searchBarAppearance: SearchBarAppearance.Appearance? = nil,
            messageInputAppearance: MessageInputViewController.Appearance? = nil,
            messageShareBodyFormatter: (any MessageFormatting)? = nil,
            unreadCountFormatter: (any UIntFormatting)? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._headerAppearance = Trackable(reference: reference, referencePath: \.headerAppearance)
            self._emptyStateAppearance = Trackable(reference: reference, referencePath: \.emptyStateAppearance)
            self._scrollDownAppearance = Trackable(reference: reference, referencePath: \.scrollDownAppearance)
            self._dateSeparatorAppearance = Trackable(reference: reference, referencePath: \.dateSeparatorAppearance)
            self._reactionPickerAppearance = Trackable(reference: reference, referencePath: \.reactionPickerAppearance)
            self._enableDateSeparator = Trackable(reference: reference, referencePath: \.enableDateSeparator)
            self._enableScrollDownButton = Trackable(reference: reference, referencePath: \.enableScrollDownButton)
            self._messageCellAppearance = Trackable(reference: reference, referencePath: \.messageCellAppearance)
            self._searchBarAppearance = Trackable(reference: reference, referencePath: \.searchBarAppearance)
            self._messageInputAppearance = Trackable(reference: reference, referencePath: \.messageInputAppearance)
            self._messageShareBodyFormatter = Trackable(reference: reference, referencePath: \.messageShareBodyFormatter)
            self._unreadCountFormatter = Trackable(reference: reference, referencePath: \.unreadCountFormatter)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let headerAppearance { self.headerAppearance = headerAppearance }
            if let emptyStateAppearance { self.emptyStateAppearance = emptyStateAppearance }
            if let scrollDownAppearance { self.scrollDownAppearance = scrollDownAppearance }
            if let dateSeparatorAppearance { self.dateSeparatorAppearance = dateSeparatorAppearance }
            if let reactionPickerAppearance { self.reactionPickerAppearance = reactionPickerAppearance }
            if let enableDateSeparator { self.enableDateSeparator = enableDateSeparator }
            if let enableScrollDownButton { self.enableScrollDownButton = enableScrollDownButton }
            if let messageCellAppearance { self.messageCellAppearance = messageCellAppearance }
            if let searchBarAppearance { self.searchBarAppearance = searchBarAppearance }
            if let messageInputAppearance { self.messageInputAppearance = messageInputAppearance }
            if let messageShareBodyFormatter { self.messageShareBodyFormatter = messageShareBodyFormatter }
            if let unreadCountFormatter { self.unreadCountFormatter = unreadCountFormatter }
        }
    }
}


////emptyState: Int, (Android Only)
////emptyStateForSelfChannel: Int,(Android Only)
////loadingState: Int,(Android Only)

//enableDateSeparator: Boolean,
//sameSenderMessageDistance: Int
//differentSenderMessageDistance: Int

