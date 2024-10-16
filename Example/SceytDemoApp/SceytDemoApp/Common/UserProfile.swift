//
//  UserProfile.swift
//  SceytDemoApp
//
//  Created by Hovsep Keropyan on 16.01.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat
import SceytChatUIKit

struct UserProfile {
    
    static func update(firstName: String,
                       lastName: String,
                       username: String? = nil,
                       avatarImage: UIImage? = nil,
                       deleteAvatar: Bool = false,
                       completion: ((Error?) -> Void)?) {
        if let image = avatarImage,
            let jpeg = try? ImageBuilder(image: image).resize(max: SceytChatUIKit.shared.config.avatarResizeConfig.dimensionThreshold).jpegData(compressionQuality: SceytChatUIKit.shared.config.avatarResizeConfig.compressionQuality) {
            if let fileUrl = Storage.storeInTemporaryDirectory(data: jpeg, ext: "jpeg") {
                
                SceytChatUIKit.shared.chatClient.upload(fileUrl: fileUrl) { _ in
                    
                } completion: { url, _ in
                    if let url = url {
                        Storage
                            .storeFile(originalUrl: url,
                                       file: fileUrl,
                                       deleteFromSrc: true)
                    }
                    update(
                        firstName: firstName,
                        lastName: lastName,
                        username: username,
                        uploadedAvatarUrl: url?.absoluteString,
                        completion: completion
                    )
                }
            }
        } else {
            update(
                firstName: firstName,
                lastName: lastName,
                username: username,
                uploadedAvatarUrl: deleteAvatar ? nil : SceytChatUIKit.shared.chatClient.user.avatarUrl,
                completion: completion
            )
        }
    }
    
    private static func update(firstName: String?,
                               lastName: String?,
                               username: String?,
                               uploadedAvatarUrl: String?,
                               completion: ((Error?) -> Void)?) {
        SceytChatUIKit.shared.chatClient
            .setProfile(
                firstName: firstName,
                lastName: lastName,
                avatarUrl: uploadedAvatarUrl,
                metadataMap: SceytChatUIKit.shared.chatClient.user.metadataMap,
                username: username ?? SceytChatUIKit.shared.chatClient.user.username)
        { user, error in
            if error == nil {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "userProfileUpdated"), object: nil)
            }
            completion?(error)
        }
    }
}
