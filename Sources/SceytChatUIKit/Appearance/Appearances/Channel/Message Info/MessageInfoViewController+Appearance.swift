//
//  MessageInfoViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public typealias MessageCellAppearance = MessageCell.Appearance

extension MessageInfoViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: {
            $0.appearance.standardAppearance?.backgroundColor = .surface1
            return $0.appearance
        }(NavigationBarAppearance()),
        backgroundColor: .backgroundSecondary,
        cellBackgroundColor: .backgroundSections,
        messageCellAppearance: SceytChatUIKit.Components.messageCell.appearance,
        descriptionTitleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(14)
        ),
        descriptionValueLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(14)
        ),
        headerLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(13)
        ),
        markerCellAppearance: SceytChatUIKit.Components.messageInfoMarkerCell.appearance,
        navigationBarTitle: L10n.Message.Info.title,
        sentLabelText: L10n.Message.Info.sent,
        sizeLabelText: L10n.Message.Info.size,
        messageDateFormatter: SceytChatUIKit.shared.formatters.messageInfoDateFormatter,
        attachmentSizeFormatter: SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
        markerTitleProvider: SceytChatUIKit.shared.visualProviders.defaultMarkerTitleProvider
    )
    
    public struct Appearance {
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var cellBackgroundColor: UIColor?
        
        @Trackable<Appearance, MessageCellAppearance>
        public var messageCellAppearance: MessageCellAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var descriptionTitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var descriptionValueLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var headerLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, MessageInfoViewController.MarkerCell.Appearance>
        public var markerCellAppearance: MessageInfoViewController.MarkerCell.Appearance
        
        @Trackable<Appearance, String>
        public var navigationBarTitle: String
        
        @Trackable<Appearance, String>
        public var sentLabelText: String
        
        @Trackable<Appearance, String>
        public var sizeLabelText: String
        
        @Trackable<Appearance, any DateFormatting>
        public var messageDateFormatter: any DateFormatting
        
        @Trackable<Appearance, any UIntFormatting>
        public var attachmentSizeFormatter: any UIntFormatting
        
        @Trackable<Appearance, any DefaultMarkerTitleProviding>
        public var markerTitleProvider: any DefaultMarkerTitleProviding
        
        public init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor?,
            cellBackgroundColor: UIColor?,
            messageCellAppearance: MessageCellAppearance,
            descriptionTitleLabelAppearance: LabelAppearance,
            descriptionValueLabelAppearance: LabelAppearance,
            headerLabelAppearance: LabelAppearance,
            markerCellAppearance: MessageInfoViewController.MarkerCell.Appearance,
            navigationBarTitle: String,
            sentLabelText: String,
            sizeLabelText: String,
            messageDateFormatter: any DateFormatting,
            attachmentSizeFormatter: any UIntFormatting,
            markerTitleProvider: any DefaultMarkerTitleProviding
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cellBackgroundColor = Trackable(value: cellBackgroundColor)
            self._messageCellAppearance = Trackable(value: messageCellAppearance)
            self._descriptionTitleLabelAppearance = Trackable(value: descriptionTitleLabelAppearance)
            self._descriptionValueLabelAppearance = Trackable(value: descriptionValueLabelAppearance)
            self._headerLabelAppearance = Trackable(value: headerLabelAppearance)
            self._markerCellAppearance = Trackable(value: markerCellAppearance)
            self._navigationBarTitle = Trackable(value: navigationBarTitle)
            self._sentLabelText = Trackable(value: sentLabelText)
            self._sizeLabelText = Trackable(value: sizeLabelText)
            self._messageDateFormatter = Trackable(value: messageDateFormatter)
            self._attachmentSizeFormatter = Trackable(value: attachmentSizeFormatter)
            self._markerTitleProvider = Trackable(value: markerTitleProvider)
        }
        
        public init(
            reference: MessageInfoViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            cellBackgroundColor: UIColor? = nil,
            messageCellAppearance: MessageCellAppearance? = nil,
            descriptionTitleLabelAppearance: LabelAppearance? = nil,
            descriptionValueLabelAppearance: LabelAppearance? = nil,
            headerLabelAppearance: LabelAppearance? = nil,
            markerCellAppearance: MessageInfoViewController.MarkerCell.Appearance? = nil,
            navigationBarTitle: String? = nil,
            sentLabelText: String? = nil,
            sizeLabelText: String? = nil,
            messageDateFormatter: (any DateFormatting)? = nil,
            attachmentSizeFormatter: (any UIntFormatting)? = nil,
            markerTitleProvider: (any DefaultMarkerTitleProviding)? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._cellBackgroundColor = Trackable(reference: reference, referencePath: \.cellBackgroundColor)
            self._messageCellAppearance = Trackable(reference: reference, referencePath: \.messageCellAppearance)
            self._descriptionTitleLabelAppearance = Trackable(reference: reference, referencePath: \.descriptionTitleLabelAppearance)
            self._descriptionValueLabelAppearance = Trackable(reference: reference, referencePath: \.descriptionValueLabelAppearance)
            self._headerLabelAppearance = Trackable(reference: reference, referencePath: \.headerLabelAppearance)
            self._markerCellAppearance = Trackable(reference: reference, referencePath: \.markerCellAppearance)
            self._navigationBarTitle = Trackable(reference: reference, referencePath: \.navigationBarTitle)
            self._sentLabelText = Trackable(reference: reference, referencePath: \.sentLabelText)
            self._sizeLabelText = Trackable(reference: reference, referencePath: \.sizeLabelText)
            self._messageDateFormatter = Trackable(reference: reference, referencePath: \.messageDateFormatter)
            self._attachmentSizeFormatter = Trackable(reference: reference, referencePath: \.attachmentSizeFormatter)
            self._markerTitleProvider = Trackable(reference: reference, referencePath: \.markerTitleProvider)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let cellBackgroundColor { self.cellBackgroundColor = cellBackgroundColor }
            if let messageCellAppearance { self.messageCellAppearance = messageCellAppearance }
            if let descriptionTitleLabelAppearance { self.descriptionTitleLabelAppearance = descriptionTitleLabelAppearance }
            if let descriptionValueLabelAppearance { self.descriptionValueLabelAppearance = descriptionValueLabelAppearance }
            if let headerLabelAppearance { self.headerLabelAppearance = headerLabelAppearance }
            if let markerCellAppearance { self.markerCellAppearance = markerCellAppearance }
            if let navigationBarTitle { self.navigationBarTitle = navigationBarTitle }
            if let sentLabelText { self.sentLabelText = sentLabelText }
            if let sizeLabelText { self.sizeLabelText = sizeLabelText }
            if let messageDateFormatter { self.messageDateFormatter = messageDateFormatter }
            if let attachmentSizeFormatter { self.attachmentSizeFormatter = attachmentSizeFormatter }
            if let markerTitleProvider { self.markerTitleProvider = markerTitleProvider }
        }
    }
}
