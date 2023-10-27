//
//  MemberRoleListVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelMemberRoleListVC: ViewController, UITableViewDelegate, UITableViewDataSource {

    open lazy var viewModel = ChannelMemberRolesVM()

    open lazy var tableView = UITableView()
        .withoutAutoresizingMask
        .rowAutomaticDimension

    open var didSelectRole: ((String) -> Void)?

    open override func setup() {
        super.setup()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MemberRolesCell.self)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneAction))
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelAction))

        viewModel.loadRoles { [weak self] (error) in
            if let error = error {
                self?.showAlert(error: error)
            } else {
                self?.tableView.reloadData()
            }
        }
    }

    open override func setupLayout() {
        super.setupLayout()
        view.addSubview(tableView)
        tableView.pin(to: view )
    }

    open override func setupAppearance() {
        super.setupAppearance()
        view.backgroundColor = Appearance.Colors.background
        title = L10n.Channel.Member.Role.title
    }

    @objc
    open func doneAction() {
        if let indexPath = tableView.indexPathForSelectedRow, let role = viewModel.role(at: indexPath.row)?.name {
            didSelectRole?(role)
        }
        dismiss(animated: true, completion: nil)
    }

    @objc
    open func cancelAction() {
        dismiss(animated: true, completion: nil)
    }

    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.roles.count
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: MemberRolesCell.self)
        cell.bind(viewModel.roles[indexPath.row])

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
}
