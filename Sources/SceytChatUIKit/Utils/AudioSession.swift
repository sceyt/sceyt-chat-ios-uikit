//
//  AudioSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 19.09.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import AVFoundation

open class AudioSession: NSObject {
    
    private static var audioSession: AVAudioSession {
        AVAudioSession.sharedInstance()
    }
    
    open class func configure(category: AVAudioSession.Category, mode: AVAudioSession.Mode = .default) throws {
        try audioSession.setCategory(category, mode: mode)
        try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try audioSession.setActive(true)
    }
    
    open class func notifyOthersOnDeactivation() throws {
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    open class var recordPermission: AVAudioSession.RecordPermission {
        audioSession.recordPermission
    }
    
    open class func requestRecordPermission(_ response: @escaping (Bool) -> Void) {
        audioSession.requestRecordPermission(response)
    }
}
