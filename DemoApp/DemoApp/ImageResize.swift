
import UIKit
import Accelerate

func resize(image: CGImage, resize newSize: CGSize) -> CGImage? {
    guard image.width != Int(newSize.width),
            image.height != Int(newSize.height)
    else { return image }
    guard let colorSpace = image.colorSpace
    else { return nil }

    var format = vImage_CGImageFormat(bitsPerComponent: numericCast(image.bitsPerComponent),
                                      bitsPerPixel: numericCast(image.bitsPerPixel),
                                      colorSpace: Unmanaged.passUnretained(colorSpace),
                                      bitmapInfo: image.bitmapInfo,
                                      version: 0,
                                      decode: nil,
                                      renderingIntent: .defaultIntent)
    var sourceBuffer = vImage_Buffer()
    defer { sourceBuffer.data.deallocate() }

    var error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                             &format,
                                             nil,
                                             image,
                                             numericCast(kvImageNoFlags))
    guard error == kvImageNoError
    else { return nil }

    let destinationWidth = Int(newSize.width)
    let destinationHeight = Int(newSize.height)
    let bytesPerPixel = image.bitsPerPixel
    let destinationBytesPerRow = destinationWidth * bytesPerPixel
    let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationHeight * destinationBytesPerRow)
    defer { destData.deallocate() }
    var destBuffer = vImage_Buffer(data: destData,
                                   height: vImagePixelCount(destinationHeight),
                                   width: vImagePixelCount(destinationWidth),
                                   rowBytes: destinationBytesPerRow)

    error = vImageScale_ARGB8888(&sourceBuffer,
                                 &destBuffer,
                                 nil,
                                 numericCast(kvImageHighQualityResampling))
    guard error == kvImageNoError
    else { return nil }

    guard let resultCGImage = vImageCreateCGImageFromBuffer(&destBuffer,
                                                            &format,
                                                            nil,
                                                            nil,
                                                            numericCast(kvImageNoFlags),
                                                            &error)?.takeRetainedValue()
    else { return nil }

    return resultCGImage
}

func resize(image: UIImage, resize newSize: CGSize) -> UIImage? {
    guard let cgImage = image.cgImage
    else { return nil }
    guard let resizedImage = resize(image: cgImage, resize: newSize)
    else { return nil }
    return UIImage(cgImage: resizedImage)
    
}
