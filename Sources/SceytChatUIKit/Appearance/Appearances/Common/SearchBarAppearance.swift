//
//  SearchBarAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SearchBarAppearance: TextInputAppearance {
    public var searchIcon: UIImage? = nil
    public var clearIcon: UIImage? = nil
    public var activityIndicatorStyle: UIActivityIndicatorView.Style = .medium
    public var activityIndicatorColor: UIColor = .iconInactive
    public var showsCancelButton: Bool = true
    public var activityIndicatorHidesWhenStopped: Bool = true
    public var textFieldReturnKeyType: UIReturnKeyType = .default
    
    // Initializer with default values
    public init(
        backgroundColor: UIColor = .background,
        labelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        placeholderAppearance: LabelAppearance = .init(
            foregroundColor: .footnoteText,
            font: Fonts.regular.withSize(16)
        ),
        placeholder: String? = nil,
        tintColor: UIColor = .accent,
        cornerRadius: CGFloat = 18,
        cornerCurve: CALayerCornerCurve = .continuous,
        borderWidth: CGFloat = 0,
        borderColor: UIColor? = nil,
        searchIcon: UIImage? = nil,
        clearIcon: UIImage? = nil,
        activityIndicatorStyle: UIActivityIndicatorView.Style = .medium,
        activityIndicatorColor: UIColor = .iconInactive,
        showsCancelButton: Bool = true,
        activityIndicatorHidesWhenStopped: Bool = true,
        textFieldReturnKeyType: UIReturnKeyType = .default
    ) {
        super.init(
            backgroundColor: backgroundColor,
            labelAppearance: labelAppearance,
            placeholderAppearance: placeholderAppearance,
            placeholder: placeholder,
            tintColor: tintColor,
            cornerRadius: cornerRadius,
            cornerCurve: cornerCurve,
            borderWidth: borderWidth,
            borderColor: borderColor
        )
        
        self.searchIcon = searchIcon
        self.clearIcon = clearIcon
        self.activityIndicatorStyle = activityIndicatorStyle
        self.activityIndicatorColor = activityIndicatorColor
        self.showsCancelButton = showsCancelButton
        self.activityIndicatorHidesWhenStopped = activityIndicatorHidesWhenStopped
        self.textFieldReturnKeyType = textFieldReturnKeyType
    }
}
