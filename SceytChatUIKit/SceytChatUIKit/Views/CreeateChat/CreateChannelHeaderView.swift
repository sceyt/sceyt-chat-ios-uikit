//
//  CreateChatHeaderView.swift
//  SceytChatUIKit
//

import UIKit

class CreateChannelHeaderView: UITableViewHeaderFooterView {

    lazy var titleLabel: UILabel = {
        $0.text = L10n.Channel.New.userSectionTitle
        $0.textColor = Colors.textGray
        $0.font = Fonts.semiBold.withSize(13)
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupLayout() {
        contentView.addSubview(titleLabel)
        contentView.backgroundColor = UIColor.systemGroupedBackground
        titleLabel.heightAnchor.pin(constant: 32)
        titleLabel.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .centerY()])
    }
}

extension CreateChannelHeaderView {
    
    static var reuseId: String {
        String(describing: self)
    }
}
