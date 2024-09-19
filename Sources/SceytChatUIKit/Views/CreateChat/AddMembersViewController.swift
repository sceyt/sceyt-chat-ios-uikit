//
//  AddMembersViewController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class AddMembersViewController: SelectUsersViewController {
 
    open var addMembersViewModel: ChannelAddMembersViewModel! {
        set {
            selectMemberViewModel = newValue
        }
        get {
            selectMemberViewModel as? ChannelAddMembersViewModel
        }
    }
    
    override open func setup() {
        super.setup()
        
        title = addMembersViewModel.title
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.cancel,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(cancelAction(_:)))
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.Nav.Bar.done,
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
    open func cancelAction(_ sender: UIBarButtonItem) {
        router.dismiss(animated: true)
        if !addMembersViewModel.onlyDismissAfterDone {
            ChannelListRouter.showChannel(addMembersViewModel.channel)
        }
    }
    
    @objc
    open func doneAction(_ sender: UIBarButtonItem) {
        loader.isLoading = true
        addMembersViewModel.addMembers()
    }
    
    open func onEvent( _ event: ChannelAddMembersViewModel.Event) {
        switch event {
        case .success:
            loader.isLoading = false
            router.dismiss(animated: true)
            if !addMembersViewModel.onlyDismissAfterDone {
                ChannelListRouter.showChannel(addMembersViewModel.channel)
            }
        case .error(let error):
            loader.isLoading = false
            router.showAlert(error: error)
        }
    }
}
