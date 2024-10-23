//
//  EmojiPickerViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EmojiPickerViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        normalColor: .footnoteText,
        selectedColor: .accent,
        headerAppearance: Components.emojiPickerSectionHeaderView.appearance,
        separatorColor: .border,
        icons: EmojiPickerIcons()
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var normalColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var selectedColor: UIColor
        
        @Trackable<Appearance, EmojiPickerViewController.SectionHeaderView.Appearance>
        public var headerAppearance: EmojiPickerViewController.SectionHeaderView.Appearance
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, EmojiPickerIcons>
        public var icons: EmojiPickerIcons
        
        
        public init(
            backgroundColor: UIColor,
            normalColor: UIColor,
            selectedColor: UIColor,
            headerAppearance: EmojiPickerViewController.SectionHeaderView.Appearance,
            separatorColor: UIColor,
            icons: EmojiPickerIcons
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._normalColor = Trackable(value: normalColor)
            self._selectedColor = Trackable(value: selectedColor)
            self._headerAppearance = Trackable(value: headerAppearance)
            self._separatorColor = Trackable(value: separatorColor)
            self._icons = Trackable(value: icons)
        }
        
        public init(
            reference: EmojiPickerViewController.Appearance,
            backgroundColor: UIColor? = nil,
            normalColor: UIColor? = nil,
            selectedColor: UIColor? = nil,
            headerAppearance: EmojiPickerViewController.SectionHeaderView.Appearance? = nil,
            separatorColor: UIColor? = nil,
            icons: EmojiPickerIcons? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._normalColor = Trackable(reference: reference, referencePath: \.normalColor)
            self._selectedColor = Trackable(reference: reference, referencePath: \.selectedColor)
            self._headerAppearance = Trackable(reference: reference, referencePath: \.headerAppearance)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._icons = Trackable(reference: reference, referencePath: \.icons)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let normalColor { self.normalColor = normalColor }
            if let selectedColor { self.selectedColor = selectedColor }
            if let headerAppearance { self.headerAppearance = headerAppearance }
            if let separatorColor { self.separatorColor = separatorColor }
            if let icons { self.icons = icons }
        }
    }
}

public struct EmojiPickerIcons {
    let recentIcon: UIImage
    let smileysIcon: UIImage
    let animalNatureIcon: UIImage
    let foodDrinkIcon: UIImage
    let activitiesIcon: UIImage
    let travelIcon: UIImage
    let objectsIcon: UIImage
    let flagsIcon: UIImage
    let symbolsIcon: UIImage

    public init(
        recentIcon: UIImage = .emojiRecent,
        smileysIcon: UIImage = .emojiSmileys,
        animalNatureIcon: UIImage = .emojiAnimalNature,
        foodDrinkIcon: UIImage = .emojiFoodDrink,
        activitiesIcon: UIImage = .emojiActivities,
        travelIcon: UIImage = .emojiTravel,
        objectsIcon: UIImage = .emojiObjects,
        flagsIcon: UIImage = .emojiFlags,
        symbolsIcon: UIImage = .emojiSymbols
    ) {
        self.recentIcon = recentIcon
        self.smileysIcon = smileysIcon
        self.animalNatureIcon = animalNatureIcon
        self.foodDrinkIcon = foodDrinkIcon
        self.activitiesIcon = activitiesIcon
        self.travelIcon = travelIcon
        self.objectsIcon = objectsIcon
        self.flagsIcon = flagsIcon
        self.symbolsIcon = symbolsIcon
    }
}
