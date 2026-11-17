//
//  VideoPosterFrameTests.swift
//  SceytChatUIKitTests
//
//  The poster frame a video's thumbnail is made of: the first non-black frame from the start,
//  the same picture for the picked original and its exported copy.
//

import AVFoundation
import XCTest
@testable import SceytChatUIKit

final class VideoPosterFrameTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("VideoPosterFrameTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testPosterSkipsABlackOpening() throws {
        // Black for 0.6 s, then red: 0, 0.25 and 0.5 s are black, 1 s is red.
        let url = try writeVideo(frames: [(.black, 0.6), (.red, 1.4)])
        let poster = try XCTUnwrap(VideoProcessor.copyFrame(url: url))
        XCTAssertEqual(try dominantColor(poster), .red)
    }

    func testPosterIsTheFirstFrameWhenItIsNotBlack() throws {
        // A 1 s default used to land on the blue part.
        let url = try writeVideo(frames: [(.green, 0.8), (.blue, 1.2)])
        let poster = try XCTUnwrap(VideoProcessor.copyFrame(url: url))
        XCTAssertEqual(try dominantColor(poster), .green)
    }

    func testAllBlackVideoStillHasAPoster() throws {
        let url = try writeVideo(frames: [(.black, 1.5)])
        XCTAssertNotNil(VideoProcessor.copyFrame(url: url))
    }

    func testAnExplicitTimeStillReturnsAFrame() throws {
        // An explicit time keeps the loose (nearest keyframe) lookup, so only its presence is
        // certain, not which picture.
        let url = try writeVideo(frames: [(.green, 0.8), (.blue, 1.2)])
        XCTAssertNotNil(VideoProcessor.copyFrame(url: url, at: 1.5))
    }

    func testNearlyBlackDetection() throws {
        XCTAssertTrue(VideoProcessor.isNearlyBlack(try solid(UIColor(white: 0.03, alpha: 1))))
        XCTAssertFalse(VideoProcessor.isNearlyBlack(try solid(UIColor(white: 0.5, alpha: 1))))
        // A dark frame with one bright spot (a title on black) is not black.
        let spot = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.white.setFill()
            context.fill(CGRect(x: 24, y: 24, width: 16, height: 16))
        }
        XCTAssertFalse(VideoProcessor.isNearlyBlack(try XCTUnwrap(spot.cgImage)))
    }
}

private extension VideoPosterFrameTests {

    enum Color: Equatable { case black, red, green, blue }

    var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return format
    }

    func solid(_ color: UIColor) throws -> CGImage {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        return try XCTUnwrap(image.cgImage)
    }

    func uiColor(_ color: Color) -> UIColor {
        switch color {
        case .black: return .black
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        }
    }

    /// The color of the center pixel.
    func dominantColor(_ image: UIImage) throws -> Color {
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let (r, g, b) = (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
        if max(r, g, b) < 40 { return .black }
        if r > g && r > b { return .red }
        if g > r && g > b { return .green }
        return .blue
    }

    /// An H.264 video of solid-color segments at 30 fps, keyframes every 2 s.
    func writeVideo(frames segments: [(Color, TimeInterval)]) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).mp4")
        let size = 64
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size,
            AVVideoHeightKey: size,
            AVVideoCompressionPropertiesKey: [AVVideoMaxKeyFrameIntervalKey: 60],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size,
            kCVPixelBufferHeightKey as String: size,
        ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        var frameIndex: Int64 = 0
        for (color, seconds) in segments {
            for _ in 0..<Int(seconds * Double(fps)) {
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                let pool = try XCTUnwrap(adaptor.pixelBufferPool)
                var buffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
                let pixelBuffer = try XCTUnwrap(buffer)
                fill(pixelBuffer, with: uiColor(color))
                XCTAssertTrue(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: frameIndex, timescale: fps)))
                frameIndex += 1
            }
        }
        input.markAsFinished()
        let done = expectation(description: "video written")
        writer.finishWriting { done.fulfill() }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
        return url
    }

    func fill(_ buffer: CVPixelBuffer, with color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<CVPixelBufferGetHeight(buffer) {
            for x in 0..<CVPixelBufferGetWidth(buffer) {
                let pixel = base + y * bytesPerRow + x * 4
                pixel[0] = UInt8(b * 255)
                pixel[1] = UInt8(g * 255)
                pixel[2] = UInt8(r * 255)
                pixel[3] = 255
            }
        }
    }
}
