//
//  LandingViewController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 14.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class LandingViewController: ViewController {
    
    // MARK: Views
    lazy var logoImageView = {
        $0.resize(anchors: [.height(40), .width(160)])
        $0.contentMode = .scaleAspectFit
        return $0.withoutAutoresizingMask
    }(UIImageView(image: .logo))
    
    lazy var titleLabel = {
        $0.text = "Fast and Seamless\nChat API"
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.font = .systemFont(ofSize: .init(32), weight: .semibold)
        $0.textColor = .primaryText.light
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var subtitleLabel = {
        $0.text = "You haven’t created channels yet,\ncreate one for sending messages."
        $0.numberOfLines = 0
        $0.textAlignment = .center
        $0.font = .systemFont(ofSize: .init(15), weight: .regular)
        $0.textColor = .secondaryText.light
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    lazy var createButton = {
        $0.setTitle("Create Account", for: .normal)
        $0.setTitleColor(.onPrimary.light, for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: .init(17), weight: .semibold)
        $0.backgroundColor = .accent.light
        $0.layer.cornerRadius = 8
        $0.layer.cornerCurve = .continuous
        $0.addTarget(self, action: #selector(createButtonAction), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton())
    
    lazy var chooseButton = {
        $0.setTitle("Choose Account", for: .normal)
        $0.setTitleColor(.accent.light, for: .normal)
        $0.titleLabel?.font = .systemFont(ofSize: .init(17), weight: .semibold)
        $0.backgroundColor = .surface1.light
        $0.layer.cornerRadius = 8
        $0.layer.cornerCurve = .continuous
        $0.addTarget(self, action: #selector(chooseButtonAction), for: .touchUpInside)
        return $0.withoutAutoresizingMask
    }(UIButton())
    
    // MARK: Lifecycle
    override func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = .white
    }
    
    override func setupLayout() {
        super.setupLayout()
        
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(createButton)
        view.addSubview(chooseButton)
        
        logoImageView.pin(to: view.safeAreaLayoutGuide, anchors: [.top(), .centerX, .leading(60, .greaterThanOrEqual)])
        
        titleLabel.pin(to: view, anchors: [.centerX, .centerY])
        
        subtitleLabel.pin(to: createButton, anchors: [.leading, .trailing])
        subtitleLabel.bottomAnchor.pin(to: createButton.topAnchor, constant: -28)
        createButton.pin(to: chooseButton, anchors: [.leading, .trailing])
        createButton.bottomAnchor.pin(to: chooseButton.topAnchor, constant: -12)
        chooseButton.pin(to: view.safeAreaLayoutGuide, anchors: [.leading(12), .trailing(-12), .bottom(-12)])
        
        createButton.resize(anchors: [.height(44)])
        chooseButton.resize(anchors: [.height(44)])
    }
    
    // MARK: Actions
    @objc
    func createButtonAction() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController else { return }
        show(vc, sender: self)
    }
    
    @objc
    func chooseButtonAction() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AccountPickerViewController") as? AccountPickerViewController else { return }
        
        vc.onUserIdSelected = { userId in
            SceytChatUIKit.shared.currentUserId = userId
            Config.currentUserId = userId
            AppCoordinator.shared.showMainFlow()
        }
        let nav = CustomInteractiveTransitionNavigationController(rootViewController: vc)
        nav.isNavigationBarHidden = true
        nav.presentationControllerType = CustomPresentationController.self
        nav.modalPresentationStyle = .custom
        present(nav, animated: true)
    }
}
