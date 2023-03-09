//
//  AudioRecorder.swift
//  SceytChatUIKit
//

import Accelerate
import AVFoundation
import Foundation
import UIKit

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var timer: Timer?
    private var audioRecorder: AVAudioRecorder?
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    let onEvent: (Event) -> Void
    
    enum Event {
        case
            durationChanged(Double),
            start,
            reset,
            noPermission,
            stopped
    }
    
    let url: URL
    private var waveformData: [Float] = []
    private var duration: Float = 0
    var metadata: ChatMessage.Attachment.Metadata<[Int]> {
        .init(
            width: 0,
            height: 0,
            thumbnail: waveformData.map { Int($0) },
            duration: Int(duration)
        )
    }
    
    deinit {
        stopRecording()
    }
    
    init(url: URL, onEvent: @escaping (Event) -> Void) {
        self.url = url
        self.onEvent = onEvent
        super.init()
        impactFeedbackGenerator.prepare()
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder?.isMeteringEnabled = false
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
    }
    
    func startRecording() {
        do {
            let recordingSession = AVAudioSession.sharedInstance()
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        
            impactFeedbackGenerator.impactOccurred()
            onEvent(.durationChanged(0))
        
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            waveformData.removeAll()
            duration = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                guard let self, let audioRecorder = self.audioRecorder else { return }
                audioRecorder.updateMeters()
                
                let level: Float
                let minDecibels: Float = -80.0
                let decibels = audioRecorder.averagePower(forChannel: 0)

                if decibels < minDecibels {
                    level = 0.0
                } else if decibels >= 0.0 {
                    level = 1.0
                } else {
                    let minAmp = powf(10.0, 0.05 * minDecibels)
                    let inverseAmpRange = 1.0 / (1.0 - minAmp)
                    let amp = powf(10.0, 0.05 * decibels)
                    let adjAmp = (amp - minAmp) * inverseAmpRange
                    level = powf(adjAmp, 1 / 2)
                }
                
                self.waveformData.append(level * 1000)
                self.duration += 0.01
                if audioRecorder.isRecording {
                    self.onEvent(.durationChanged(audioRecorder.currentTime))
                }
            }
            timer?.fire()
            onEvent(.start)
        } catch {
            stopRecording()
            onEvent(.noPermission)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        stopRecording()
        onEvent(.stopped)
    }
}
