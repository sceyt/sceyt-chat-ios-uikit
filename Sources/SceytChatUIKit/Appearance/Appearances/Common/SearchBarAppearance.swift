//
//  SearchBarAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SearchBarAppearance: AppearanceProviding {
    public var appearance: SearchBarAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: SearchBarAppearance?
    
    
    public static var appearance = SearchBarAppearance(
        backgroundColor: .background,
        labelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16),
            backgroundColor: .clear
        ),
        placeholderAppearance: LabelAppearance(
            foregroundColor: .footnoteText,
            font: Fonts.regular.withSize(16),
            backgroundColor: .clear
        ),
        placeholder: nil,
        tintColor: .accent,
        cornerRadius: 18,
        cornerCurve: .continuous,
        borderWidth: 0,
        borderColor: nil,
        searchIcon: nil,
        clearIcon: nil,
        activityIndicatorStyle: .medium,
        activityIndicatorColor: .iconInactive,
        showsCancelButton: true,
        activityIndicatorHidesWhenStopped: true,
        textFieldReturnKeyType: .default
    )
    
    @Trackable<SearchBarAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<SearchBarAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
    
    @Trackable<SearchBarAppearance, LabelAppearance>
    public var placeholderAppearance: LabelAppearance
    
    @Trackable<SearchBarAppearance, String?>
    public var placeholder: String?
    
    @Trackable<SearchBarAppearance, UIColor>
    public var tintColor: UIColor
    
    @Trackable<SearchBarAppearance, CGFloat>
    public var cornerRadius: CGFloat
    
    @Trackable<SearchBarAppearance, CALayerCornerCurve>
    public var cornerCurve: CALayerCornerCurve
    
    @Trackable<SearchBarAppearance, CGFloat>
    public var borderWidth: CGFloat
    
    @Trackable<SearchBarAppearance, UIColor?>
    public var borderColor: UIColor?
    
    // Specific to SearchBarAppearance
    @Trackable<SearchBarAppearance, UIImage?>
    public var searchIcon: UIImage?
    
    @Trackable<SearchBarAppearance, UIImage?>
    public var clearIcon: UIImage?
    
    @Trackable<SearchBarAppearance, UIActivityIndicatorView.Style>
    public var activityIndicatorStyle: UIActivityIndicatorView.Style
    
    @Trackable<SearchBarAppearance, UIColor>
    public var activityIndicatorColor: UIColor
    
    @Trackable<SearchBarAppearance, Bool>
    public var showsCancelButton: Bool
    
    @Trackable<SearchBarAppearance, Bool>
    public var activityIndicatorHidesWhenStopped: Bool
    
    @Trackable<SearchBarAppearance, UIReturnKeyType>
    public var textFieldReturnKeyType: UIReturnKeyType
    
    // Primary Initializer with all parameters
    public init(
        backgroundColor: UIColor,
        labelAppearance: LabelAppearance,
        placeholderAppearance: LabelAppearance,
        placeholder: String?,
        tintColor: UIColor,
        cornerRadius: CGFloat,
        cornerCurve: CALayerCornerCurve,
        borderWidth: CGFloat,
        borderColor: UIColor?,
        searchIcon: UIImage?,
        clearIcon: UIImage?,
        activityIndicatorStyle: UIActivityIndicatorView.Style,
        activityIndicatorColor: UIColor,
        showsCancelButton: Bool,
        activityIndicatorHidesWhenStopped: Bool,
        textFieldReturnKeyType: UIReturnKeyType
    ) {
        self._backgroundColor = Trackable(value: backgroundColor)
        self._labelAppearance = Trackable(value: labelAppearance)
        self._placeholderAppearance = Trackable(value: placeholderAppearance)
        self._placeholder = Trackable(value: placeholder)
        self._tintColor = Trackable(value: tintColor)
        self._cornerRadius = Trackable(value: cornerRadius)
        self._cornerCurve = Trackable(value: cornerCurve)
        self._borderWidth = Trackable(value: borderWidth)
        self._borderColor = Trackable(value: borderColor)
        self._searchIcon = Trackable(value: searchIcon)
        self._clearIcon = Trackable(value: clearIcon)
        self._activityIndicatorStyle = Trackable(value: activityIndicatorStyle)
        self._activityIndicatorColor = Trackable(value: activityIndicatorColor)
        self._showsCancelButton = Trackable(value: showsCancelButton)
        self._activityIndicatorHidesWhenStopped = Trackable(value: activityIndicatorHidesWhenStopped)
        self._textFieldReturnKeyType = Trackable(value: textFieldReturnKeyType)
    }
    
    // Secondary Initializer with optional parameters
    public init(
        reference: SearchBarAppearance,
        backgroundColor: UIColor? = nil,
        labelAppearance: LabelAppearance? = nil,
        placeholderAppearance: LabelAppearance? = nil,
        placeholder: String? = nil,
        tintColor: UIColor? = nil,
        cornerRadius: CGFloat? = nil,
        cornerCurve: CALayerCornerCurve? = nil,
        borderWidth: CGFloat? = nil,
        borderColor: UIColor? = nil,
        searchIcon: UIImage? = nil,
        clearIcon: UIImage? = nil,
        activityIndicatorStyle: UIActivityIndicatorView.Style? = nil,
        activityIndicatorColor: UIColor? = nil,
        showsCancelButton: Bool? = nil,
        activityIndicatorHidesWhenStopped: Bool? = nil,
        textFieldReturnKeyType: UIReturnKeyType? = nil
    ) {
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
        self._placeholderAppearance = Trackable(reference: reference, referencePath: \.placeholderAppearance)
        self._placeholder = Trackable(reference: reference, referencePath: \.placeholder)
        self._tintColor = Trackable(reference: reference, referencePath: \.tintColor)
        self._cornerRadius = Trackable(reference: reference, referencePath: \.cornerRadius)
        self._cornerCurve = Trackable(reference: reference, referencePath: \.cornerCurve)
        self._borderWidth = Trackable(reference: reference, referencePath: \.borderWidth)
        self._borderColor = Trackable(reference: reference, referencePath: \.borderColor)
        self._searchIcon = Trackable(reference: reference, referencePath: \.searchIcon)
        self._clearIcon = Trackable(reference: reference, referencePath: \.clearIcon)
        self._activityIndicatorStyle = Trackable(reference: reference, referencePath: \.activityIndicatorStyle)
        self._activityIndicatorColor = Trackable(reference: reference, referencePath: \.activityIndicatorColor)
        self._showsCancelButton = Trackable(reference: reference, referencePath: \.showsCancelButton)
        self._activityIndicatorHidesWhenStopped = Trackable(reference: reference, referencePath: \.activityIndicatorHidesWhenStopped)
        self._textFieldReturnKeyType = Trackable(reference: reference, referencePath: \.textFieldReturnKeyType)
        
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let labelAppearance { self.labelAppearance = labelAppearance }
        if let placeholderAppearance { self.placeholderAppearance = placeholderAppearance }
        if let placeholder { self.placeholder = placeholder }
        if let tintColor { self.tintColor = tintColor }
        if let cornerRadius { self.cornerRadius = cornerRadius }
        if let cornerCurve { self.cornerCurve = cornerCurve }
        if let borderWidth { self.borderWidth = borderWidth }
        if let borderColor { self.borderColor = borderColor }
        if let searchIcon { self.searchIcon = searchIcon }
        if let clearIcon { self.clearIcon = clearIcon }
        if let activityIndicatorStyle { self.activityIndicatorStyle = activityIndicatorStyle }
        if let activityIndicatorColor { self.activityIndicatorColor = activityIndicatorColor }
        if let showsCancelButton { self.showsCancelButton = showsCancelButton }
        if let activityIndicatorHidesWhenStopped { self.activityIndicatorHidesWhenStopped = activityIndicatorHidesWhenStopped }
        if let textFieldReturnKeyType { self.textFieldReturnKeyType = textFieldReturnKeyType }
    }
}
