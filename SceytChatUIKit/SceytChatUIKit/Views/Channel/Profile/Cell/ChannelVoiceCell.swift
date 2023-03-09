//
//  ChannelVoiceCell.swift
//  SceytChatUIKit
//

import AVKit
import UIKit

open class ChannelVoiceCell: CollectionViewCell {
    open lazy var playButton = Button()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var dateLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var durationLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var separatorView = UIView()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelVoiceListView.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open var player: AVPlayer?
    
    public private(set) var isPlaying = false {
        didSet {
            playButton.setImage(isPlaying ? Images.audioPlayerPause : Images.audioPlayerPlay, for: .normal)
            isPlaying ? play() : pause()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override open func setup() {
        super.setup()
        isPlaying = false
        titleLabel.lineBreakMode = .byTruncatingMiddle
        playButton.addTarget(self, action: #selector(playButtonAction(_:)), for: .touchUpInside)
        
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(onTapPlayVoice),
                name: .init("onTapPlayVoice"),
                object: nil
            )
        
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(didPlayToEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: nil
            )
    }

    override open func setupAppearance() {
        super.setupAppearance()
        
        titleLabel.font = appearance.titleLabelFont
        titleLabel.textColor = appearance.titleLabelTextColor
        dateLabel.font = appearance.dateLabelFont
        dateLabel.textColor = appearance.dateLabelTextColor
        durationLabel.font = appearance.durationLabelFont
        durationLabel.textColor = appearance.dateLabelTextColor
        separatorView.backgroundColor = appearance.separatorColor
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(playButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(separatorView)

        playButton.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 16)
        playButton.centerYAnchor.pin(to: contentView.centerYAnchor)
        playButton.widthAnchor.pin(constant: 40)
        playButton.heightAnchor.pin(constant: 40)
        titleLabel.leadingAnchor.pin(to: playButton.trailingAnchor, constant: 12)
        titleLabel.topAnchor.pin(to: playButton.topAnchor)
        titleLabel.trailingAnchor.pin(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        dateLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        dateLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 4)
        durationLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -16)
        durationLabel.centerYAnchor.pin(to: contentView.centerYAnchor)
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }
    
    open var data: ChatMessage.Attachment! {
        didSet {
            if let user = data.user {
                titleLabel.text = Formatters.userDisplayName.format(user)
            } else {
                titleLabel.text = data.userId
            }
            
            dateLabel.text = Formatters.attachmentTimestamp.format(data.createdAt)
                .replacingOccurrences(of: " ", with: " • ")
                .replacingOccurrences(of: ",", with: "")
            
            resetDuration()
        }
    }
    
    private func resetDuration() {
        if let duration = data.voiceDecodedMetadata?.duration, duration > 0 {
            durationLabel.text = Formatters.videoAssetDuration.format(TimeInterval(duration))
        } else {
            durationLabel.text = ""
        }
    }
    
    @objc
    open func playButtonAction(_ sender: Button) {
        isPlaying.toggle()
    }
    
    open func play() {
        NotificationCenter.default.post(.init(name: .init("onTapPlayVoice"), object: data.originUrl))
        
        if player == nil {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let mimeType = "audio/mp4"
                let asset = AVURLAsset(url: data.originUrl, options: ["AVURLAssetOutOfBandMIMETypeKey": mimeType])
                let playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)
                player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: Int32(NSEC_PER_SEC)), queue: DispatchQueue.main) { [weak self] _ in
                    guard let self else { return }
                    if self.isPlaying, self.player?.currentItem?.status == .readyToPlay {
                        let duration = CMTimeGetSeconds(playerItem.duration)
                        let currentTime = max(0, CMTimeGetSeconds(self.player!.currentTime()))
                        self.durationLabel.text = Formatters.videoAssetDuration.format(currentTime)
                        if currentTime >= duration {
                            self.stop()
                        }
                    }
                }
            } catch {
                debugPrint(error)
            }
        }
        player?.play()
    }
    
    open func pause() {
        player?.pause()
    }
    
    open func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        resetDuration()
    }
    
    @objc
    func onTapPlayVoice(_ n: Notification) {
        if isPlaying, n.object as? URL != data.originUrl {
            stop()
        }
    }
    
    @objc
    func didPlayToEnd(notification: Notification) {
        if ((notification.object as? AVPlayerItem)?.asset as? AVURLAsset)?.url == data.originUrl {
            stop()
        }
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        stop()
    }
}
