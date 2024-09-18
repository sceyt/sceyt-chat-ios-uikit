//
//  ConnectionStateView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

public class ConnectionStateView: View {

    public let state: ConnectionState
    
    public required  init?(state: ConnectionState) {
        guard state != .connected
        else { return nil }
        self.state = state
        super.init(frame: .zero)
    }
    
    public required init?(coder: NSCoder) {
        state = .connected
        super.init(coder: coder)
    }
    
    public override func setup() {
        super.setup()
        let label = UILabel().withoutAutoresizingMask
        addSubview(label)
        label.pin(to: self, anchors: [.centerX(10), .centerY()])
        
        let indicator = UIActivityIndicatorView(style: .medium).withoutAutoresizingMask
        indicator.color = ChannelListViewController.appearance.connectionIndicatorColor
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        addSubview(indicator)
        indicator.pin(to: label, anchors: [.centerY()])
        indicator.trailingAnchor.pin(to: label.leadingAnchor, constant: -2)
        
        let text: String
        switch state {
        case .connecting:
            text = L10n.Connection.State.connecting
        case .disconnected:
            text = L10n.Connection.State.disconnected
            indicator.stopAnimating()
        case .reconnecting:
            text = L10n.Connection.State.reconnecting
        case .failed:
            indicator.stopAnimating()
            text = L10n.Connection.State.failed
            let imageView = UIImageView(image: .failedMessage).withoutAutoresizingMask
            addSubview(imageView)
            imageView.pin(to: label, anchors: [.centerY()])
            imageView.trailingAnchor.pin(to: label.leadingAnchor)
        default:
            text = ""
        }
        label.attributedText = NSAttributedString(string: text, attributes: [.font: Fonts.semiBold.withSize(18)])
    }
}
