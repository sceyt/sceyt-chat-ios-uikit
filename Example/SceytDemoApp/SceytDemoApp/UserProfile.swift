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
    
    static func update(displayName: String?,
                avatarImage: UIImage? = nil,
                       deleteAvatar: Bool = false,
                       completion: ((Error?) -> Void)?) {
        let user = makeNamesFrom(displayName: displayName)
        if let image = avatarImage, let jpeg = try? ImageBuilder(image: image).resize(max: SceytChatUIKit.shared.config.avatarResizeConfig.dimensionThreshold).jpegData(compressionQuality: SceytChatUIKit.shared.config.avatarResizeConfig.compressionQuality) {
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
                        firstName: user.firstName,
                        lastName: user.lastName,
                        uploadedAvatarUrl: url?.absoluteString,
                        completion: completion
                    )
                }
            }
        } else {
            update(
                firstName: user.firstName,
                lastName: user.lastName,
                uploadedAvatarUrl: deleteAvatar ? nil : SceytChatUIKit.shared.chatClient.user.avatarUrl,
                completion: completion
            )
        }
    }
    
    private static func update(firstName: String?,
                        lastName: String?,
                        uploadedAvatarUrl: String?,
                               completion: ((Error?) -> Void)?) {
        SceytChatUIKit.shared.chatClient
            .setProfile(
                firstName: firstName,
                lastName: lastName,
                avatarUrl: uploadedAvatarUrl,
                metadataMap: SceytChatUIKit.shared.chatClient.user.metadataMap,
                username: SceytChatUIKit.shared.chatClient.user.username)
        { _, error in
            completion?(error)
        }
    }
    
    private static func makeNamesFrom(displayName: String?) -> (firstName: String?, lastName: String?) {
        guard let displayName
        else {
            return (nil, nil)
        }
        
        if let range = displayName.range(of: " ") {
            let firstName = String(displayName.prefix(upTo: range.lowerBound))
            let lastName = String(displayName.suffix(from: range.upperBound))
            return (firstName, lastName)
        } else {
            return (displayName, nil)
        }
        
    }
}
