//
//  VideoProcessor.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVFoundation
import Photos
import UIKit
import VideoToolbox

open class VideoProcessor {
    static let shared = VideoProcessor()
    
    private lazy var inProgress: [String: Operation] = [:]
    private lazy var queue = {
        $0.name = "com.sceyt.VideoProcessor"
        $0.maxConcurrentOperationCount = 1
        return $0
    }(OperationQueue())
    
    open class func copyFrame(
        url: URL,
        at time: TimeInterval = 1
    ) -> UIImage? {
        let asset = AVAsset(url: url)
        return copyFrame(asset: asset, at: time)
    }
    
    open class func copyFrame(
        asset: AVAsset,
        at time: TimeInterval = 1
    ) -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        var duration = asset.duration
        duration.value = min(duration.value, CMTimeValue(Int32(time * TimeInterval(duration.timescale))))
        do {
            let cgImage = try generator.copyCGImage(at: duration, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            log.errorIfNotNil(error, "Copy video frame at \(CMTimeGetSeconds(duration)) s., given value id \(time) s.")
            return nil
        }
    }
    
    open class func resolutionSize(url: URL) -> CGSize? {
        let asset = AVAsset(url: url)
        return resolutionSize(asset: asset)
    }
    
    open class func resolutionSize(asset: AVAsset) -> CGSize? {
        guard let track = asset.tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    open class func duration(
        url: URL
    ) async -> CMTime? {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        if !asset.duration.seconds.isNaN {
            return asset.duration
        }
        if #available(iOS 15, *) {
            return try? await asset.load(.duration)
        } else {
            await asset.loadValues(forKeys: ["duration"])
            return asset.duration
        }
    }
    
    open class func export(
        from inputPath: String,
        processInfo: SCVideoProcessInfo
    ) async -> Result<URL, Error> {
        await withCheckedContinuation { continuation in
            let uuid = UUID().uuidString
            let operation = VideoOperation(
                uuid: uuid,
                inputPath: inputPath,
                processInfo: processInfo,
                config: .init()
            )
            operation.completionBlock = {
                shared.inProgress.removeValue(forKey: uuid)
                continuation.resume(returning: operation.result)
            }
            shared.inProgress[uuid] = operation
            shared.queue.addOperation(operation)
        }
    }
    
    open class func getSlowmoVideoUrl(_ asset: AVComposition, completion: @escaping (URL?) -> Void, progressHandler: ((Float) -> Void)? = nil) {
        if asset.tracks.count > 1,
           let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540)
        {
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("\(UUID().uuidString).\(AVFileType.mp4.fileExtension)"))
            exporter.outputURL = outputURL
            exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = true
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    completion(outputURL)
                default:
                    completion(nil)
                }
            }
            DispatchQueue.global().async {
                while [.waiting, .exporting].contains(exporter.status) {
                    DispatchQueue.main.async {
                        progressHandler?(exporter.progress)
                    }
                    usleep(100000)
                }
            }
        } else {
            completion(nil)
        }
    }
    
    open class func calculateSizeWith(maxDimen: CGFloat?, originalSize: CGSize) -> CGSize {
        guard let maxDimen = maxDimen else {
            return originalSize
        }
        if maxDimen > max(originalSize.width, originalSize.height) {
            return originalSize
        } else if originalSize.height > originalSize.width {
            let targetWidth = Int(maxDimen * originalSize.width / originalSize.height)
            return CGSize(width: CGFloat(targetWidth), height: maxDimen)
        } else {
            let targetHeight = Int(maxDimen * originalSize.height / originalSize.width)
            return CGSize(width: maxDimen, height: CGFloat(targetHeight))
        }
    }
    
    open class func assetUrl(localIdentifier: String, completion: @escaping (URL?) -> Void) {
        if localIdentifier.hasPrefix("/local/"),
           let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier.substring(fromIndex: 7)], options: .none).firstObject
        {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) {avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    completion(urlAsset.url)
                } else if let composition = avAsset as? AVComposition {
                    if let trak = composition.tracks(withMediaType: .video).first,
                        let segment = trak.segments.first,
                       let assetUrl = segment.sourceURL {
                        completion(assetUrl)
                    } else {
                        SCTUIKitComponents.videoProcessor.getSlowmoVideoUrl(
                            composition,
                            completion: { url in
                                completion(url)
                            }
                        )
                    }
                    
                } else {
                    completion(nil)
                }
            }
        } else {
            completion(URL(fileURLWithPath: localIdentifier))
        }
    }
}

public extension VideoProcessor {
    enum AVAssetRequestProperty: String {
        case duration
    }
    
    enum AVAssetResponseProperty {
        case duration(CMTime)
        case error(Error)
    }
    
    enum Errors {
        static let noSuchFile = NSError(domain: "com.sceyt.VideoProcessor", code: NSFileReadNoSuchFileError)
        static let cancelled = NSError(domain: "com.sceyt.VideoProcessor", code: NSURLErrorCancelled)
    }
}

open class SCVideoProcessInfo: NSObject {
    var isCancelled = false
    let progress = Progress()

    override public init() {
        super.init()
        debugPrint("[SCVideoProcessInfo] init \(self)")
    }
    
    open func cancel() {
        isCancelled = true
        debugPrint("[SCVideoProcessInfo] cancel \(self)")
    }
}

open class VideoOperation: AsyncOperation {
    private var inputPath: String
    private let config: CompressionConfig
    private let processInfo: SCVideoProcessInfo
    private let group = DispatchGroup()
    let videoCompressQueue = DispatchQueue(label: "com.sceytchat.uikit.videoQueue")
    let audioCompressQueue = DispatchQueue(label: "com.sceytchat.uikit.audioQueue")
    private var reader: AVAssetReader?
    private var writer: AVAssetWriter?
        
    public var result: Result<URL, Error> = .failure(VideoProcessor.Errors.noSuchFile)
    
    override open var isCancelled: Bool { processInfo.isCancelled }
    
    init(uuid: String,
         inputPath: String,
         processInfo: SCVideoProcessInfo,
         config: CompressionConfig)
    {
        self.inputPath = inputPath
        self.processInfo = processInfo
        self.config = config

        super.init(uuid)
    }
    
    override public func cancel() {
        processInfo.cancel()
    }
    
    override open func main() {
        if inputPath.hasPrefix("/local/"),
           let asset = PHAsset.fetchAssets(withLocalIdentifiers: [inputPath.substring(fromIndex: 7)], options: .none).firstObject
        {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
                guard let self else { return }
                if let urlAsset = avAsset as? AVURLAsset {
                    compressVideo(inputURL: urlAsset.url)
                } else if let avCompositionAsset = avAsset as? AVComposition {
                    SCTUIKitComponents.videoProcessor.getSlowmoVideoUrl(
                        avCompositionAsset,
                        completion: { [weak self] url in
                            guard let self else { return }
                            if let url {
                                compressVideo(inputURL: url)
                            } else {
                                result = .failure(VideoProcessor.Errors.noSuchFile)
                                complete()
                            }
                        }
                    )
                } else {
                    self.result = .failure(VideoProcessor.Errors.noSuchFile)
                    self.complete()
                }
            }
        } else {
            compressVideo(inputURL: URL(fileURLWithPath: inputPath), completion: { [weak self] in
                self?.result = $0
                self?.complete()
            })
        }
    }
    
    func outputURL(for inputURL: URL) -> URL {
        let uuid = UUID().uuidString
        var outputURL = URL(fileURLWithPath: NSTemporaryDirectory().appending(uuid))
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        outputURL = outputURL
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(AVFileType.mp4.fileExtension)
        return outputURL
    }

    enum Errors {
        static let noSuchFile = NSError(domain: "com.sceyt.VideoProcessor", code: NSFileReadNoSuchFileError)
        static let cancelled = NSError(domain: "com.sceyt.VideoProcessor", code: NSURLErrorCancelled)
    }
    
    public struct CompressionConfig {
        public var videoBitrate: Int
        public var videomaxKeyFrameInterval: Int
        public var audioSampleRate: Int
        public var audioBitrate: Int
        public var fileType: AVFileType
        public var maxDimen: CGFloat?
        
        public init(videoBitrate: Int = 1500000,
                    videomaxKeyFrameInterval: Int = 10,
                    audioSampleRate: Int = 44100,
                    audioBitrate: Int = 65000,
                    fileType: AVFileType = .mp4,
                    maxDimen: CGFloat? = 848.0)
        {
            self.videoBitrate = videoBitrate
            self.videomaxKeyFrameInterval = videomaxKeyFrameInterval
            self.audioSampleRate = audioSampleRate
            self.audioBitrate = audioBitrate
            self.fileType = fileType
            self.maxDimen = maxDimen
        }
    }
    
    public func compressVideo(inputURL: URL) {
        compressVideo(inputURL: inputURL) { [weak self] in
            self?.result = $0
            self?.complete()
        }
    }
    
    public func compressVideo(inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let outputURL = outputURL(for: inputURL)
        
        let asset = AVAsset(url: inputURL)
        // setup
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(Errors.noSuchFile))
            return
        }
        
        let targetVideoBitrate: Float
        if Float(config.videoBitrate) > videoTrack.estimatedDataRate {
            targetVideoBitrate = videoTrack.estimatedDataRate
        } else {
            targetVideoBitrate = Float(config.videoBitrate)
        }
        
        let targetSize = VideoProcessor.calculateSizeWith(maxDimen: config.maxDimen, originalSize: videoTrack.naturalSize)
        
        if videoTrack.naturalSize.width <= targetSize.width && videoTrack.naturalSize.height <= targetSize.height && videoTrack.estimatedDataRate <= targetVideoBitrate {
            // no need to compress, just return the original file
            do {
                try FileManager.default.copyItem(at: inputURL, to: outputURL)
            } catch {
                completion(.failure(error))
            }
            return completion(.success(outputURL))
        }
        
        let targetFrameRate = videoTrack.nominalFrameRate
        
        let videoSettings = createVideoSettingsWithBitrate(targetVideoBitrate,
                                                           maxKeyFrameInterval: config.videomaxKeyFrameInterval,
                                                           size: targetSize)
        
        var audioTrack: AVAssetTrack?
        var audioSettings: [String: Any]?
        
        if let adTrack = asset.tracks(withMediaType: .audio).first {
            audioTrack = adTrack
            let targetAudioBitrate: Float
            if Float(config.audioBitrate) < adTrack.estimatedDataRate {
                targetAudioBitrate = Float(config.audioBitrate)
            } else {
                targetAudioBitrate = 64000
            }
            
            let targetSampleRate: Int
            if config.audioSampleRate < 8000 {
                targetSampleRate = 8000
            } else if config.audioSampleRate > 192000 {
                targetSampleRate = 192000
            } else {
                targetSampleRate = config.audioSampleRate
            }
            audioSettings = createAudioSettingsWithAudioTrack(adTrack, bitrate: targetAudioBitrate, sampleRate: targetSampleRate)
        }
        
        debugPrint("[VideoProcessor][\(uuid)] ************** Video info **************")
        debugPrint("[VideoProcessor][\(uuid)] 🎬 Video ")
        debugPrint("[VideoProcessor][\(uuid)] INPUT:")
        debugPrint("[VideoProcessor][\(uuid)] video size: \(inputURL.sizeInMB())M")
        debugPrint("[VideoProcessor][\(uuid)] bitrate: \(videoTrack.estimatedDataRate) b/s")
        debugPrint("[VideoProcessor][\(uuid)] fps: \(videoTrack.nominalFrameRate)") //
        debugPrint("[VideoProcessor][\(uuid)] scale size: \(videoTrack.naturalSize)")
        debugPrint("[VideoProcessor][\(uuid)] OUTPUT:")
        debugPrint("[VideoProcessor][\(uuid)] video bitrate: \(targetVideoBitrate) b/s")
        debugPrint("[VideoProcessor][\(uuid)] fps: \(targetFrameRate)")
        debugPrint("[VideoProcessor][\(uuid)] scale size: (\(targetSize))")
        debugPrint("[VideoProcessor][\(uuid)] ****************************************")
        
        _compress(asset: asset,
                  fileType: config.fileType,
                  videoTrack,
                  videoSettings,
                  audioTrack,
                  audioSettings,
                  outputURL: outputURL,
                  completion: completion)
    }
    
    // MARK: - Private methods
    
    private func _compress(asset: AVAsset,
                           fileType: AVFileType,
                           _ videoTrack: AVAssetTrack,
                           _ videoSettings: [String: Any],
                           _ audioTrack: AVAssetTrack?,
                           _ audioSettings: [String: Any]?,
                           outputURL: URL,
                           completion: @escaping (Result<URL, Error>) -> Void)
    {
        // video
        let colorProperties: [String: Any] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                AVVideoColorPropertiesKey: colorProperties
            ]
        )
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform // fix output video orientation
        do {
            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(url: outputURL, fileType: fileType)
            writer.shouldOptimizeForNetworkUse = true
            self.reader = reader
            self.writer = writer
            
            // video output
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
                videoOutput.alwaysCopiesSampleData = false
            }
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
            
            // audio output
            var audioInput: AVAssetWriterInput?
            var audioOutput: AVAssetReaderTrackOutput?
            if let audioTrack = audioTrack, let audioSettings = audioSettings {
                audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
                                                                                           AVNumberOfChannelsKey: 2])
                let adInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput = adInput
                if reader.canAdd(audioOutput!) {
                    reader.add(audioOutput!)
                }
                if writer.canAdd(adInput) {
                    writer.add(adInput)
                }
            }
            
            let startTime = Date()
            
            // start compressing
            reader.startReading()
            writer.startWriting()
            writer.startSession(atSourceTime: CMTime.zero)
            
            // output video
            group.enter()
            
            outputVideoData(videoInput: videoInput,
                            videoOutput: videoOutput)
            {
                self.group.leave()
            }
            
            // output audio
            if let realAudioInput = audioInput, let realAudioOutput = audioOutput {
                group.enter()
                // TODO: drop audio sample buffer
                outputAudioData(realAudioInput, audioOutput: realAudioOutput, frameIndexArr: []) {
                    self.group.leave()
                }
            }
            
            // completion
            group.notify(queue: .main) { [weak self] in
                guard let self else { return }
                if isCancelled {
                    debugPrint("[VideoProcessor][\(uuid)] cancelled")
                    return completion(.failure(Errors.cancelled))
                }
                switch writer.status {
                case .writing, .completed:
                    writer.finishWriting { [weak self] in
                        guard let self else { return }
                        let endTime = Date()
                        let elapse = endTime.timeIntervalSince(startTime)
                        debugPrint("[VideoProcessor][\(uuid)] ******** Compression finished ✅**********")
                        debugPrint("[VideoProcessor][\(uuid)] Compressed video:")
                        debugPrint("[VideoProcessor][\(uuid)] time: \(elapse)")
                        debugPrint("[VideoProcessor][\(uuid)] size: \(outputURL.sizeInMB())M")
                        debugPrint("[VideoProcessor][\(uuid)] url: \(outputURL)")
                        debugPrint("[VideoProcessor][\(uuid)] ******************************************")
                        DispatchQueue.main.sync {
                            completion(.success(outputURL))
                        }
                    }
                default:
                    completion(.failure(writer.error!))
                }
            }
            
        } catch {
            completion(.failure(error))
        }
    }
    
    private func createVideoSettingsWithBitrate(_ bitrate: Float, maxKeyFrameInterval: Int, size: CGSize) -> [String: Any] {
        let compressionProperties: [String: Any]
        let codecType: AVVideoCodecType
        if hasHEVC {
            codecType = .hevc
            compressionProperties = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel
            ]
        } else {
            codecType = .h264
            compressionProperties = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        }
        return [AVVideoCodecKey: codecType,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                AVVideoCompressionPropertiesKey: compressionProperties]
    }
    
    private let hasHEVC: Bool = {
        false
//        let spec: [CFString: Any] = [:]
//        var outID: CFString?
//        var properties: CFDictionary?
//        let result = VTCopySupportedPropertyDictionaryForEncoder(width: 1920, height: 1080, codecType: kCMVideoCodecType_HEVC, encoderSpecification: spec as CFDictionary, encoderIDOut: &outID, supportedPropertiesOut: &properties)
//        if result == kVTCouldNotFindVideoEncoderErr {
//            return false
//        }
//        return result == noErr
    }()
    
    private func createAudioSettingsWithAudioTrack(_ audioTrack: AVAssetTrack, bitrate: Float, sampleRate: Int) -> [String: Any] {
        if let audioFormatDescs = audioTrack.formatDescriptions as? [CMFormatDescription], let formatDescription = audioFormatDescs.first {
            debugPrint("[VideoProcessor][\(uuid)] 🔊 Audio")
            debugPrint("[VideoProcessor][\(uuid)] INPUT:")
            debugPrint("[VideoProcessor][\(uuid)] bitrate: \(audioTrack.estimatedDataRate)")
            if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                debugPrint("[VideoProcessor][\(uuid)] sampleRate: \(streamBasicDescription.pointee.mSampleRate)")
                debugPrint("[VideoProcessor][\(uuid)] channels: \(streamBasicDescription.pointee.mChannelsPerFrame)")
                debugPrint("[VideoProcessor][\(uuid)] formatID: \(streamBasicDescription.pointee.mFormatID)")
            }
            debugPrint("[VideoProcessor][\(uuid)] OUTPUT:")
            debugPrint("[VideoProcessor][\(uuid)] bitrate: \(bitrate)")
            debugPrint("[VideoProcessor][\(uuid)] sampleRate: \(sampleRate)")
            debugPrint("[VideoProcessor][\(uuid)] formatID: \(kAudioFormatMPEG4AAC)")
        }
        
        var audioChannelLayout = AudioChannelLayout()
        memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitrate,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: Data(bytes: &audioChannelLayout, count: MemoryLayout<AudioChannelLayout>.size)
        ]
    }
    
    private func outputVideoData(videoInput: AVAssetWriterInput,
                                 videoOutput: AVAssetReaderTrackOutput,
                                 completion: @escaping (() -> Void))
    {
        var counter = 0
        var index = 0
        
        videoInput.requestMediaDataWhenReady(on: videoCompressQueue) { [weak self] in
            guard let self else { return }
            while videoInput.isReadyForMoreMediaData {
                if isCancelled {
                    videoInput.markAsFinished()
                    completion()
                    break
                }
                if let buffer = videoOutput.copyNextSampleBuffer() {
                    videoInput.append(buffer)
                } else {
                    videoInput.markAsFinished()
                    completion()
                    break
                }
            }
        }
    }
    
    private func outputAudioData(_ audioInput: AVAssetWriterInput,
                                 audioOutput: AVAssetReaderTrackOutput,
                                 frameIndexArr: [Int],
                                 completion: @escaping (() -> Void))
    {
        var counter = 0
        var index = 0
        
        audioInput.requestMediaDataWhenReady(on: audioCompressQueue) { [weak self] in
            guard let self else { return }
            while audioInput.isReadyForMoreMediaData {
                if isCancelled {
                    audioInput.markAsFinished()
                    completion()
                    break
                }
                if let buffer = audioOutput.copyNextSampleBuffer() {
                    if frameIndexArr.isEmpty {
                        audioInput.append(buffer)
                        counter += 1
                    } else {
                        // append first frame
                        if index < frameIndexArr.count {
                            let frameIndex = frameIndexArr[index]
                            if counter == frameIndex {
                                index += 1
                                audioInput.append(buffer)
                            }
                            counter += 1
                        } else {
                            // Drop this frame
                            CMSampleBufferInvalidate(buffer)
                        }
                    }
                    
                } else {
                    audioInput.markAsFinished()
                    completion()
                    break
                }
            }
        }
    }
}

extension AVFileType {
    var fileExtension: String {
        switch self {
        case .mov:
            return "mov"
        case .mp4:
            return "mp4"
        case .m4v:
            return "m4v"
        case .m4a:
            return "m4a"
        case .mobile3GPP:
            return "3gp"
        case .mobile3GPP2:
            return "3g2"
        case .caf:
            return "caf"
        case .wav:
            return "wav"
        case .aiff:
            return "aif"
        case .aifc:
            return "aifc"
        case .amr:
            return "amr"
        case .mp3:
            return "mp3"
        case .ac3:
            return "ac3"
        default:
            return rawValue
        }
    }
}

private extension URL {
    func sizeInMB() -> Double {
        guard isFileURL else { return 0 }
        do {
            let attribute = try FileManager.default.attributesOfItem(atPath: path)
            if let size = attribute[FileAttributeKey.size] as? NSNumber {
                return size.doubleValue / (1024 * 1024)
            }
        } catch {
            debugPrint("[VideoProcessor] Error: \(error)")
        }
        return 0.0
    }
}

public extension AVAsset {
    var isSlowMotionVideo: Bool {
        (self as? AVComposition)?.tracks.count ?? 0 > 1
    }
}

public extension AVComposition {
    var slowMoDuration: Float64 {
        if let timeMapping = tracks.last?.segments.last?.timeMapping {
            return CMTimeGetSeconds(CMTimeAdd(timeMapping.source.duration, timeMapping.target.start))
        }
        return 0
    }
}
