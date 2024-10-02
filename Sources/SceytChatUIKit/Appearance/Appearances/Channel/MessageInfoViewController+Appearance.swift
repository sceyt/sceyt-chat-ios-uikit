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
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor? = .backgroundSecondary
        public lazy var cellBackgroundColor: UIColor? = .backgroundSections
        
        public lazy var messageCellAppearance: MessageCellAppearance = Components.messageCell.appearance
        public lazy var descriptionTitleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                                 font: Fonts.semiBold.withSize(14))
        public lazy var descriptionValueLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                                 font: Fonts.regular.withSize(14))
        public lazy var headerLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                       font: Fonts.semiBold.withSize(13))
        public lazy var markerCellAppearance: MessageInfoViewController.MarkerCell.Appearance = Components.messageInfoMarkerCell.appearance
        
        public lazy var navigationBarTitle: String = L10n.Message.Info.title
        public lazy var sentLabelText: String = L10n.Message.Info.sent
        public lazy var sizeLabelText: String = L10n.Message.Info.size
        
        public lazy var messageDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageInfoDateFormatter
        public lazy var attachmentSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter
        public lazy var markerTitleProvider: any DefaultMarkerTitleProviding = SceytChatUIKit.shared.visualProviders.defaultMarkerTitleProvider
        
        public init(
            backgroundColor: UIColor? = .backgroundSecondary,
            cellBackgroundColor: UIColor? = .backgroundSections,
            messageCellAppearance: MessageCellAppearance = SceytChatUIKit.Components.messageCell.appearance,
            descriptionTitleLabelAppearance: LabelAppearance = LabelAppearance(foregroundColor: .primaryText,
                                                                               font: Fonts.semiBold.withSize(14)),
            descriptionValueLabelAppearance: LabelAppearance = LabelAppearance(foregroundColor: .secondaryText,
                                                                               font: Fonts.regular.withSize(14)),
            headerLabelAppearance: LabelAppearance = LabelAppearance(foregroundColor: .secondaryText,
                                                                     font: Fonts.semiBold.withSize(13)),
            markerCellAppearance: MessageInfoViewController.MarkerCell.Appearance = SceytChatUIKit.Components.messageInfoMarkerCell.appearance,
            navigationBarTitle: String = L10n.Message.Info.title,
            sentLabelText: String = L10n.Message.Info.sent,
            sizeLabelText: String = L10n.Message.Info.size,
            messageDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageInfoDateFormatter,
            attachmentSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
            markerTitleProvider: any DefaultMarkerTitleProviding = SceytChatUIKit.shared.visualProviders.defaultMarkerTitleProvider
        ) {
            self.backgroundColor = backgroundColor
            self.cellBackgroundColor = cellBackgroundColor
            self.messageCellAppearance = messageCellAppearance
            self.descriptionTitleLabelAppearance = descriptionTitleLabelAppearance
            self.descriptionValueLabelAppearance = descriptionValueLabelAppearance
            self.headerLabelAppearance = headerLabelAppearance
            self.markerCellAppearance = markerCellAppearance
            self.navigationBarTitle = navigationBarTitle
            self.sentLabelText = sentLabelText
            self.sizeLabelText = sizeLabelText
            self.messageDateFormatter = messageDateFormatter
            self.attachmentSizeFormatter = attachmentSizeFormatter
            self.markerTitleProvider = markerTitleProvider
        }
    }
}
