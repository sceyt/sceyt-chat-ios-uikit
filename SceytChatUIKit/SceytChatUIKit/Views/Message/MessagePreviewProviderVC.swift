//
//  MessagePreviewProviderVC.swift
//  SceytChatUIKit
//

import UIKit

open class MessagePreviewProviderVC: ViewController {

    public let cell: MessageCell
    private var snapshotCell: MessageCell!
    
    public var reactionsView = ReactionsView()
        .withoutAutoresizingMask
    
    public static var reactionsViewSize = CGSize(width: 306, height: 40)
    
    public init(message cell: MessageCell) {
        self.cell = cell
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = .clear
        
    }
    open override func setupLayout() {
        super.setupLayout()
        let snapshot: MessageCell = (cell is IncomingMessageCell) ?
        IncomingMessageCell(frame: cell.bounds) :
        OutgoingMessageCell(frame: cell.bounds)
        snapshot.unreadView.isHidden = true
//        snapshot.separatorView.isHidden = true
        
        view.addSubview(snapshot.withoutAutoresizingMask)
        snapshot.pin(to: view)
        snapshot.contentView.pin(to: snapshot)
        snapshot.showSenderInfo = cell.showSenderInfo
        snapshot.data = cell.data
        snapshotCell = snapshot
        view.addSubview(reactionsView)
        preferredContentSize = CGSize(width: 200, height: 300)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let posX = (cell is IncomingMessageCell) ?
        -cell.bubbleView.frame.origin.x :
        cell.bounds.maxX - cell.bubbleView.frame.maxX
        snapshotCell.frame.origin = .init(x: posX, y: 0)
    }
}

extension MessagePreviewProviderVC {

    public class ReactionsView: View {
        
        public var reactions = ["😎", "😂", "👌🏻", "😍", "👍🏻", "😏"] {
            didSet {
                
            }
        }
        
        open lazy var stackView = UIStackView()
            .withoutAutoresizingMask
        
        public override func setup() {
            super.setup()
            
            stackView.alignment = .center
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 2
            reactions.forEach { reaction in
                let button = ReactionButton(type: .custom)
                button.setTitle(reaction, for: .normal)
                stackView.addArrangedSubview(button)
            }
        }
        
        public override func setupAppearance() {
            super.setupAppearance()
            
            
        }
        
        public override func setupLayout() {
            super.setupLayout()
            addSubview(stackView)
            stackView.pin(to: self)
        }
        
        open class ReactionButton: Button {
            
            open override func setup() {
                super.setup()
                self.titleLabel?.font = Fonts.regular.withSize(28)
            }
        }
    }
}
