//
//  SimpleSinglePlayer.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 04.09.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVKit
import Foundation

internal class SimpleSinglePlayer: NSObject {
    typealias DurationBlock = (Double, Double) -> Void
    typealias StopBlock = () -> Void
    
    private static var currentPlayer: AVPlayer?
    private static var currentStopBlock: StopBlock?
    private static var currentPauseBlock: StopBlock?
    private static var currentDurationBlock: DurationBlock?
    private static var timeObserver: Any?
    private static var speedForPlayer: [Int64: Float] = [:]
    private(set) static var isPlaying = false
    private(set) static var duration: Double = 0
    private(set) static var currentTime: Double = 0
    internal static var currentId: Int64?
    static var progress: Double { currentTime / duration }
    static var url: URL? { (currentPlayer?.currentItem?.asset as? AVURLAsset)?.url }
    
    static func play(_ url: URL, id: Int64, durationBlock: DurationBlock?, stopBlock: StopBlock?) {
        guard url != self.url else {
            if !isPlaying {
                isPlaying = true
                currentId = id
                try? Components.audioSession.configure(category: .playback)
                currentPlayer?.play()
                // Apply stored speed if available
                if let storedRate = speedForPlayer[id], id != 0 {
                    currentPlayer?.rate = storedRate
                }
            }
            set(durationBlock: durationBlock, stopBlock: stopBlock)
            return
        }
        
        stop(resumeBackgroundPlayback: false)
        set(durationBlock: durationBlock, stopBlock: stopBlock)
        
        do {
            try Components.audioSession.configure(category: .playback)
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            currentPlayer = player
            duration = 0
            currentTime = 0
            currentDurationBlock?(0, 0)
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)), queue: DispatchQueue.main) { _ in
                if isPlaying, player.currentItem?.status == .readyToPlay {
                    duration = CMTimeGetSeconds(playerItem.duration)
                    currentTime = max(0, CMTimeGetSeconds(player.currentTime()))
                    currentDurationBlock?(currentTime, progress)
                    if currentTime >= duration {
                        stop(resumeBackgroundPlayback: true)
                    }
                }
            }
            isPlaying = true
            currentId = id
            player.play()
            // Apply stored speed if available
            if let storedRate = speedForPlayer[id] {
                player.rate = storedRate
            }
        } catch {
            logger.errorIfNotNil(error, "")
        }
    }
    
    @objc
    private func didPlayToEnd(notification: Notification) {
        SimpleSinglePlayer.stop()
    }
    
    static func set(durationBlock: DurationBlock?, stopBlock: StopBlock?) {
        currentDurationBlock = durationBlock
        currentStopBlock = stopBlock
        durationBlock?(currentTime, progress)
    }
    
    static func pause() {
        isPlaying = false
        currentPlayer?.pause()
        currentPauseBlock?()
    }

    static func setPauseBlock(_ block: StopBlock?) {
        currentPauseBlock = block
    }
    
    static func stop(resumeBackgroundPlayback: Bool = true) {
        isPlaying = false
        if let currentPlayer {
            currentPlayer.pause()
            if let timeObserver {
                currentPlayer.removeTimeObserver(timeObserver)
            }
        }
        timeObserver = nil
        currentPlayer = nil
        currentId = nil
        currentTime = 0
        currentStopBlock?()
        currentStopBlock = nil
        currentPauseBlock = nil
        
        if resumeBackgroundPlayback {
            try? Components.audioSession.notifyOthersOnDeactivation()
        }
    }
    
    static func setRate(_ rate: Float, for id: Int64) {
        speedForPlayer[id] = rate

        // Only apply to current player if this tId is currently playing
        guard id == currentId else { return }

        guard currentPlayer?.rate != rate
        else { return }
        
        currentPlayer?.rate = rate
        if !isPlaying {
            currentPlayer?.pause()
        }
    }

    static func getSpeed(for tid: Int64?) -> Float? {
        guard let tid = tid else { return nil }
        return speedForPlayer[tid]
    }
}
