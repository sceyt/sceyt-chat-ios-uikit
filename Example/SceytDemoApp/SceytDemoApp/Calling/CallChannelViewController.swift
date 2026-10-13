import Combine
import SceytChatUIKit
import UIKit

final class CallChannelViewController: ChannelViewController {
    static let videoCallIdentifier = "sceyt_demo_channel_video_call_button"
    static let audioCallIdentifier = "sceyt_demo_channel_audio_call_button"
    private var callStartTask: Task<Void, Never>?

    override func setupDone() {
        super.setupDone()
        DemoCalling.provider?.availabilityPublisher
            .sink { [weak self] _ in self?.updateCallActions() }
            .store(in: &subscriptions)
    }

    override func updateNavigationItems() {
        super.updateNavigationItems()
        updateCallActions()
    }

    override func onEvent(_ event: ChannelViewModel.Event) {
        super.onEvent(event)
        if case .updateChannel = event { updateCallActions() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            callStartTask?.cancel()
        }
    }

    func callBarButtonItems() -> [UIBarButtonItem] {
        guard !channelViewModel.isEditing, !channelViewModel.isSearching,
              DemoCalling.provider?.canStartCall(in: channelViewModel.channel) == true,
              channelViewModel.threadMessage == nil else { return [] }
        let video = UIBarButtonItem(image: UIImage(systemName: "video"), style: .plain,
                                    target: self, action: #selector(videoCallAction))
        video.accessibilityLabel = NSLocalizedString("Video call", comment: "Start a video call")
        video.accessibilityIdentifier = Self.videoCallIdentifier
        let audio = UIBarButtonItem(image: UIImage(systemName: "phone"), style: .plain,
                                    target: self, action: #selector(audioCallAction))
        audio.accessibilityLabel = NSLocalizedString("Audio call", comment: "Start an audio call")
        audio.accessibilityIdentifier = Self.audioCallIdentifier
        return [video, audio]
    }

    private func updateCallActions() {
        guard !channelViewModel.isEditing, !channelViewModel.isSearching else { return }
        navigationItem.rightBarButtonItems = callBarButtonItems()
    }

    @objc private func audioCallAction() { startCall(isVideo: false) }
    @objc private func videoCallAction() { startCall(isVideo: true) }

    private func startCall(isVideo: Bool) {
        guard callStartTask == nil, let provider = DemoCalling.provider else { return }
        view.endEditing(true)
        callStartTask = Task { [weak self] in
            guard let self else { return }
            defer { self.callStartTask = nil }
            await provider.startCall(in: self.channelViewModel.channel, isVideo: isVideo, from: self)
        }
    }
}
