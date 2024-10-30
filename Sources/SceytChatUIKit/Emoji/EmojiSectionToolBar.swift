//
//  EmojiSectionToolBar.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol EmojiSectionToolBarDelegate: AnyObject {
    func emojiSectionToolBar(_ sectionToolbar: EmojiSectionToolBar, didSelectSection: Int)
    func emojiSectionToolBarShouldShowRecentsSection(_ sectionToolbar: EmojiSectionToolBar) -> Bool
}

open class EmojiSectionToolBar: View {
    
    open private(set) var buttons = [UIButton]()
    open lazy var toolbar = UIToolbar().withoutAutoresizingMask
    
    open lazy var separator = UIView().withoutAutoresizingMask
    
    open weak var delegate: EmojiSectionToolBarDelegate? {
        didSet {
            if delegate?.emojiSectionToolBarShouldShowRecentsSection(self) == true {
                buttons.insert(createSectionButton(icon: appearance.icons.recentIcon), at: 0)
            }
        }
    }
    
    open var appearance: EmojiPickerViewController.Appearance = Components.emojiPickerViewController.appearance

    open override func setup() {
        super.setup()
        buttons = [
            createSectionButton(icon: appearance.icons.smileysIcon),
            createSectionButton(icon: appearance.icons.animalNatureIcon),
            createSectionButton(icon: appearance.icons.foodDrinkIcon),
            createSectionButton(icon: appearance.icons.activitiesIcon),
            createSectionButton(icon: appearance.icons.travelIcon),
            createSectionButton(icon: appearance.icons.objectsIcon),
            createSectionButton(icon: appearance.icons.flagsIcon),
            createSectionButton(icon: appearance.icons.symbolsIcon)
        ]
    }

    open override func setupLayout() {
        super.setupLayout()
        
        addSubview(toolbar)
        toolbar.pin(to: self, anchors: [.leading, .top, .trailing])
        
        addSubview(separator)
        separator.topAnchor.pin(to: toolbar.bottomAnchor)
        separator.pin(to: self, anchors: [.leading, .bottom, .trailing])
        separator.resize(anchors: [.height(1)])
        
        var items = [UIBarButtonItem]()
        items.reserveCapacity(buttons.count * 2 + 3)
        let edgeSeperator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        edgeSeperator.width = 8
        items.append(edgeSeperator)
        let toolBarItems = Array(
            buttons
                .map { [UIBarButtonItem(customView: $0)] }
                .joined(separator: [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)])
        )
        items.append(contentsOf: toolBarItems)
        items.append(edgeSeperator)
        toolbar.items = items
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        backgroundColor = appearance.backgroundColor
        separator.backgroundColor = appearance.separatorColor
        for button in buttons {
            button.setImage(button.image(for: .normal)?.withTintColor(appearance.normalColor), for: .normal)
            button.setImage(button.image(for: .selected)?.withTintColor(appearance.selectedColor), for: .selected)
        }
    }

    open override func setupDone() {
        super.setupDone()
        setSelectedSection(0)
    }
    
    open func createSectionButton(icon: UIImage) -> UIButton {
        let button = UIButton()
        let normalImage = icon.withTintColor(appearance.normalColor)
        let selectedImage = icon.withTintColor(appearance.selectedColor)
        button.setImage(normalImage, for: .normal)
        button.setImage(selectedImage, for: .selected)
        button.resize(anchors: [.width(30), .height(30)])
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(didSelectSection), for: .touchUpInside)
        return button
    }

    @objc
    open func didSelectSection(sender: UIButton) {
        guard let selectedSection = buttons.firstIndex(of: sender) else {
            return
        }

        setSelectedSection(selectedSection)

        delegate?.emojiSectionToolBar(self, didSelectSection: selectedSection)
    }

    open func setSelectedSection(_ section: Int) {
        buttons.forEach { $0.isSelected = false }
        if buttons.indices.contains(section) {
            buttons[section].isSelected = true
        }
    }
}
