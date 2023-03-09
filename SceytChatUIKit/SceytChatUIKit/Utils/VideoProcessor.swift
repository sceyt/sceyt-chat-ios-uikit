//
//  VideoProcessor.swift
//  SceytChatUIKit
//

import UIKit
import AVFoundation

open class VideoProcessor {
    
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
        duration.value = min(duration.value, Int64(time))
        do {
            let cgImage = try generator.copyCGImage(at: duration, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            debugPrint(error)
            return nil
        }
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
        fileType: AVFileType = .mp4,
        presetName: String = AVAssetExportPresetMediumQuality,
        from url: URL
    ) async -> Result<URL, Error> {
        let ext = fileExtensions(fileType: fileType)
        let outputPath = NSTemporaryDirectory().appending("\(UUID().uuidString)")
        var outputUrl = URL(fileURLWithPath: outputPath)
        try? FileManager.default.createDirectory(at: outputUrl, withIntermediateDirectories: true, attributes: nil)
        outputUrl = outputUrl.appendingPathComponent(url.deletingPathExtension().lastPathComponent).appendingPathExtension(ext)
        let avAsset = AVURLAsset(url: url)
        print("[VideoBuilder]", fileType.rawValue, outputUrl)
        let failedState = NSError(domain: "AVFoundation", code: AVAssetExportSession.Status.failed.rawValue)
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: presetName)
        else { return .failure(failedState) }
        exportSession.outputURL = outputUrl;
        exportSession.outputFileType = fileType;
        exportSession.shouldOptimizeForNetworkUse = true;
        await exportSession.export()
        
        if exportSession.status == .completed {
            return .success(outputUrl)
        } else if exportSession.status == .failed {
            if let error = exportSession.error {
                return .failure(error)
            }
        }
        return .failure(failedState)
    }
    
    open class func fileExtensions(fileType: AVFileType) -> String {
        switch fileType {
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
            return fileType.rawValue
        }
    }
}


extension VideoProcessor {
    
    public enum AVAssetRequestProperty: String {
        case duration
    }
    
    public enum AVAssetResponseProperty {
        case duration(CMTime)
        case error(Error)
    }
}

