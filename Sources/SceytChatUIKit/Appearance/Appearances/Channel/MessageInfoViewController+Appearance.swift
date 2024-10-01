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
        public lazy var messageFileSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.fileSizeFormatter
        public lazy var markerTitleProvider: any DefaultMarkerTitleProviding = SceytChatUIKit.shared.visualProviders.defaultMarkerTitleProvider
        
        public init() {
            
        }
    }
}
