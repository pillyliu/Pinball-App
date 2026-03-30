import CoreImage
import UIKit

func scoreScannerCrop(frame: CIImage, previewMapping: ScoreScannerPreviewMapping?) -> CIImage? {
    let cropRect: CGRect?
    if let previewMapping {
        cropRect = ScoreScannerFrameMapper.cropRect(
            frameExtent: frame.extent,
            previewMapping: previewMapping
        )
    } else {
        cropRect = ScoreScannerFrameMapper.cropRect(
            frameExtent: frame.extent,
            normalizedRect: ScoreScannerTargetBoxLayout.fallbackNormalizedRect
        )
    }

    guard let cropRect else { return nil }
    return frame.cropped(to: cropRect)
}

func scoreScannerPreviewImage(from frame: CIImage, ciContext: CIContext) -> UIImage? {
    let normalizedFrame = frame.transformed(
        by: CGAffineTransform(translationX: -frame.extent.minX, y: -frame.extent.minY)
    )
    let normalizedExtent = normalizedFrame.extent.integral
    guard let cgImage = ciContext.createCGImage(normalizedFrame, from: normalizedExtent) else { return nil }
    return UIImage(cgImage: cgImage)
}

func scoreScannerOCRImage(from image: UIImage) -> CIImage? {
    if let cgImage = image.cgImage {
        return CIImage(cgImage: cgImage)
    }
    return image.ciImage
}
