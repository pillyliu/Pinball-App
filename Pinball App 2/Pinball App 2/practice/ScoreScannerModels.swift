import Foundation
import CoreGraphics
import SwiftUI

enum ScoreScannerDisplayMode: String, CaseIterable, Identifiable {
    case lcd
    case dmd
    case segmented

    var id: String { rawValue }
}

enum ScoreScannerStatus: Equatable {
    case cameraPermissionRequired
    case cameraUnavailable
    case searching
    case reading
    case stableCandidate
    case locked
    case failedNoReading

    var title: String {
        switch self {
        case .cameraPermissionRequired:
            return "Camera access required"
        case .cameraUnavailable:
            return "Camera unavailable"
        case .searching:
            return "Searching"
        case .reading:
            return "Reading"
        case .stableCandidate:
            return "Stable candidate"
        case .locked:
            return "Locked"
        case .failedNoReading:
            return "No reading"
        }
    }

    var detail: String {
        switch self {
        case .cameraPermissionRequired:
            return "Allow camera access to scan score displays on-device."
        case .cameraUnavailable:
            return "This device could not start the rear camera."
        case .searching:
            return "Align the score display inside the box."
        case .reading:
            return "Live OCR is tracking the display."
        case .stableCandidate:
            return "Hold steady for a clean lock."
        case .locked:
            return "Stable reading captured. Confirm or edit before use."
        case .failedNoReading:
            return "No stable numeric reading yet. Freeze and confirm manually if needed."
        }
    }
}

struct ScoreOCRObservation: Equatable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct ScoreScannerCandidate: Equatable {
    let rawText: String
    let normalizedScore: Int
    let formattedScore: String
    let confidence: Float
    let boundingBox: CGRect
    let digitCount: Int
    let centerBias: Double
}

struct ScoreOCRAnalysis: Equatable {
    let bestCandidate: ScoreScannerCandidate?
    let candidates: [ScoreScannerCandidate]
}

struct ScoreScannerLockedReading: Equatable {
    let score: Int
    let formattedScore: String
    let rawText: String
    let confidence: Float
    let averageConfidence: Float
}

struct ScoreScannerPreviewMapping: Equatable {
    let previewBounds: CGRect
    let targetRect: CGRect
}

enum ScoreScannerFrameMapper {
    static func cropRect(frameExtent: CGRect, previewMapping: ScoreScannerPreviewMapping) -> CGRect? {
        guard frameExtent.width > 0, frameExtent.height > 0 else { return nil }

        let previewBounds = previewMapping.previewBounds.standardized
        let targetRect = previewMapping.targetRect.intersection(previewBounds).standardized
        guard previewBounds.width > 0,
              previewBounds.height > 0,
              !targetRect.isNull,
              !targetRect.isEmpty else {
            return nil
        }

        let scale = max(
            previewBounds.width / frameExtent.width,
            previewBounds.height / frameExtent.height
        )
        guard scale > 0 else { return nil }

        let displayedSize = CGSize(
            width: frameExtent.width * scale,
            height: frameExtent.height * scale
        )
        let imageRectInPreview = CGRect(
            x: previewBounds.minX + ((previewBounds.width - displayedSize.width) / 2),
            y: previewBounds.minY + ((previewBounds.height - displayedSize.height) / 2),
            width: displayedSize.width,
            height: displayedSize.height
        )
        let visibleRect = targetRect.intersection(imageRectInPreview)
        guard !visibleRect.isNull, !visibleRect.isEmpty else { return nil }

        let xInImage = (visibleRect.minX - imageRectInPreview.minX) / scale
        let yInImageTop = (visibleRect.minY - imageRectInPreview.minY) / scale
        let widthInImage = visibleRect.width / scale
        let heightInImage = visibleRect.height / scale

        let x = frameExtent.minX + xInImage
        let y = frameExtent.minY + (frameExtent.height - yInImageTop - heightInImage)
        let cropRect = CGRect(x: x, y: y, width: widthInImage, height: heightInImage)
            .integral
            .intersection(frameExtent)

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        return cropRect
    }

    static func cropRect(frameExtent: CGRect, normalizedRect: CGRect) -> CGRect? {
        guard frameExtent.width > 0, frameExtent.height > 0 else { return nil }

        let width = frameExtent.width * normalizedRect.width
        let height = frameExtent.height * normalizedRect.height
        let x = frameExtent.minX + (frameExtent.width * normalizedRect.minX)
        let y = frameExtent.minY + (frameExtent.height * (1 - normalizedRect.maxY))
        let cropRect = CGRect(x: x, y: y, width: width, height: height)
            .integral
            .intersection(frameExtent)

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        return cropRect
    }
}

struct ScoreScannerTargetBoxLayout {
    static func rect(in size: CGSize, safeAreaInsets: EdgeInsets) -> CGRect {
        let width = min(size.width * 0.82, 420)
        let height = min(max(size.height * 0.10, 78), 104)
        let x = (size.width - width) / 2
        let topInset = safeAreaInsets.top + 192
        let y = min(max(topInset, 190), max(size.height * 0.26, topInset))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static let fallbackNormalizedRect = CGRect(x: 0.12, y: 0.27, width: 0.76, height: 0.13)
}
