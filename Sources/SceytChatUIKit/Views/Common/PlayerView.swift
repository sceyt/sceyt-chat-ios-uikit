//
//  PlayerView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import AVKit

open class PlayerView: View {
    
    open var player: AVPlayer?
    open lazy var playerLayer = AVPlayerLayer()
    public private(set) var mediaUrl: URL?
    public private(set) var playerItem: AVPlayerItem?
    
    open lazy var timeLabel = Components.timeLabel
        .init()
        .withoutAutoresizingMask
    
    open lazy var playButton = Button
        .init()
        .withoutAutoresizingMask
    
    open override func setup() {
        super.setup()
        playerLayer.videoGravity = .resizeAspectFill
        playButton.setImage(.messageVideoPlay, for: .normal)
    }

    open override func setupLayout() {
        super.setupLayout()
        layer.addSublayer(playerLayer)
        playerLayer.frame = bounds
        layer.cornerRadius = 16
        
        addSubview(timeLabel)
        addSubview(playButton)
        timeLabel.pin(to: self, anchors: [.top(8), .leading(8)])
        playButton.pin(to: self, anchors: [.centerX, .centerY])
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    
    open func setPlayerItem(url: URL) {
        mediaUrl = url
        playerItem = AVPlayerItem(url: url)
//        setDuration(playerItem: playerItem!)
    }
    
    open func createPlayer() -> Bool {
        guard let playerItem else { return false }
        player = AVPlayer(playerItem: playerItem)
        playerLayer.player = player
        return true
    }
    
    
    open func calculateDuration() {
        guard let playerItem else { return }
        Task {
            if #available(iOS 15, *) {
                do {
                    let duration = try await playerItem.asset.load(.duration)
                    self.timeLabel.text = Formatters.videoAssetDuration.format(duration.seconds)
                } catch {
                    debugPrint(error)
                }

            } else {
                playerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
                    let seconds = playerItem.duration.seconds
                    guard !seconds.isNaN else { return }
                    self?.timeLabel.text = Formatters.videoAssetDuration.format(playerItem.duration.seconds)
                }
            }
        }
    }
}
