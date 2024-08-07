//
//  ChannelListEmptyView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelListEmptyView: View {
    open private(set) lazy var imageView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFit)
    
    open private(set) lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
    
    open private(set) lazy var descriptionLabel = UILabel()
        .withoutAutoresizingMask
    
    open private(set) lazy var createButton = UIButton()
        .withoutAutoresizingMask
    
    open override func setup() {
        super.setup()
        descriptionLabel.numberOfLines = 0
    }
    
    open override func setupLayout() {
        super.setupLayout()
        
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(createButton)
        imageView.topAnchor.pin(to: topAnchor, constant: 150)
        imageView.trailingAnchor.pin(to: centerXAnchor, constant: 35)
        imageView.bottomAnchor.pin(to: titleLabel.topAnchor, constant: -20)
        titleLabel.centerXAnchor.pin(to: centerXAnchor)
        titleLabel.bottomAnchor.pin(to: descriptionLabel.topAnchor, constant: -8)
        descriptionLabel.leadingAnchor.pin(greaterThanOrEqualTo: leadingAnchor, constant: 52)
        descriptionLabel.trailingAnchor.pin(lessThanOrEqualTo: trailingAnchor, constant: -52)
        descriptionLabel.centerXAnchor.pin(to: centerXAnchor)
        descriptionLabel.bottomAnchor.pin(to: createButton.topAnchor, constant: -5)
        createButton.centerXAnchor.pin(to: centerXAnchor)
        createButton.heightAnchor.pin(constant: 40)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        imageView.image = .emptyChannelList
        
        titleLabel.text = L10n.Channel.Empty.title
        titleLabel.textColor = .primaryText
        titleLabel.font = Fonts.bold.withSize(17)
        
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.text = L10n.Channel.Empty.description
        descriptionLabel.textColor = .secondaryText
        descriptionLabel.font = Fonts.regular.withSize(16)
        createButton.isHidden = true
        createButton.setTitleColor(.blue, for: .normal)
        createButton.titleLabel?.font = Fonts.regular.withSize(14)
        createButton.setTitle(L10n.Channel.Empty.createNew, for: .normal)
    }
    
}
