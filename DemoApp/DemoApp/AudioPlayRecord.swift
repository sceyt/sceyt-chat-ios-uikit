//
//  AudioPlayRecord.swift
//  DemoApp
//
//

import Foundation
import AudioToolbox

public protocol AudioPlayable {
    
    init(fileUrl: URL)
    
    // Can be set in Player for notifying
    // every 500ms the current position of playback
    func play(durationCallback: ((TimeInterval) -> Void)?) -> Bool
    
    func pause()
    
    func stop()
    
    func seekToPosition(position: TimeInterval) -> Bool
    
    var playbackPosition: TimeInterval { get }
    
    var audioDuration: TimeInterval { get }
}

public protocol AudioRecordable {
    
    init(fileUrl: URL)
    
    // Can be set in Recorder for notifying
    // every 500ms the current position of recording
    func start(audioFormat: AudioFormatID, bitrate: Int, sampleRate: Float64, durationCallback: ((TimeInterval) -> Void)?) -> Bool
    
    func stop()
    
    var recordingDuration: TimeInterval { get }
}

public protocol AudioManageable: AudioPlayable, AudioRecordable {
    // AudioManageable can have a list of AudioPlayable
    // to support playNext() playPrev() functionality.
    // Can set to play some of them.
    // Can check permissions for audio recording.
    
    
    // Get audio file oscillation in float array if possible
    // to display in UI, can be static/companion
    
    func oscillation(file: String) -> [CGFloat]
        
}

