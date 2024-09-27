//
//  ConnectionStateView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class ConnectionStateView: View {

    public let state: ConnectionState
    public let appearance: ConnectionStateViewAppearance
    
    public required init?(state: ConnectionState, appearance: ConnectionStateViewAppearance) {
        guard state != .connected
        else { return nil }
        self.state = state
        self.appearance = appearance
        super.init(frame: .zero)
    }
    
    public required init?(coder: NSCoder) {
        state = .connected
        appearance = ConnectionStateViewAppearance()
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        let label = UILabel().withoutAutoresizingMask
        addSubview(label)
        label.pin(to: self, anchors: [.centerX(10), .centerY()])
        
        let indicator = UIActivityIndicatorView(style: appearance.indicatorStyle).withoutAutoresizingMask
        indicator.color = appearance.indicatorColor
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        addSubview(indicator)
        indicator.pin(to: label, anchors: [.centerY()])
        indicator.trailingAnchor.pin(to: label.leadingAnchor, constant: -2)
        
        let text: String = appearance.connectionStateTextProvider.provideVisual(for: state)
        switch state {
        case .disconnected:
            indicator.stopAnimating()
        case .failed:
            indicator.stopAnimating()
            let imageView = UIImageView(image: appearance.failedIcon).withoutAutoresizingMask
            addSubview(imageView)
            imageView.pin(to: label, anchors: [.centerY()])
            imageView.trailingAnchor.pin(to: label.leadingAnchor)
        default:
            break
        }
        label.attributedText = NSAttributedString(string: text, attributes: [
            .foregroundColor: appearance.labelAppearance.foregroundColor,
            .font: appearance.labelAppearance.font
        ])
    }
}
