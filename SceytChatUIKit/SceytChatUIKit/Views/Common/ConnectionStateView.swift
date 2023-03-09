//
//  ConnectionStateView.swift
//  SceytChatUIKit
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
        indicator.color = ChannelListVC.appearance.connectionIndicatorColor
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        addSubview(indicator)
        indicator.pin(to: label, anchors: [.centerY()])
        indicator.trailingAnchor.pin(to: label.leadingAnchor)
        
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
        label.attributedText = NSAttributedString(string: text, attributes: [.font: Fonts.medium.withSize(18)])
    }
}
