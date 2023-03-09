//
//  ChannelAddMembersVC.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelAddMembersVC: SelectChannelMembersVC {
 
    open var addMembersViewModel: ChannelAddMembersVM! {
        set {
            selectMemberViewModel = newValue
        }
        get {
            selectMemberViewModel as? ChannelAddMembersVM
        }
    }
    
    override open func setup() {
        super.setup()
        title = L10n.Channel.Add.Subscribers.title
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.add,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(addAction(_:)))
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.done,
                                                           style: .done,
                                                           target: self,
                                                           action: #selector(doneAction(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
        addMembersViewModel.$event1
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
    }
    
    @objc
    open func addAction(_ sender: UIBarButtonItem) {
        addMembersViewModel
            .addMembers()
    }
    
    @objc
    open func doneAction(_ sender: UIBarButtonItem) {
        router.dismiss(animated: false)
        ChannelListRouter.findAndShowChannel(id: addMembersViewModel.channel.id)
    }
    
    open func onEvent( _ event: ChannelAddMembersVM.Event) {
        switch event {
        case .success:
            router.dismiss(animated: false)
            ChannelListRouter.findAndShowChannel(id: addMembersViewModel.channel.id)
        case .error(let error):
            router.showAlert(error: error)
        }
    }
}
