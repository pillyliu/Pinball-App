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
            return "Tilt slightly if reflections block digits."
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

struct ScoreScannerTargetBoxLayout {
    static func rect(in size: CGSize, safeAreaInsets: EdgeInsets) -> CGRect {
        let width = min(size.width * 0.82, 420)
        let height = min(max(size.height * 0.16, 96), 146)
        let x = (size.width - width) / 2
        let topInset = safeAreaInsets.top + 112
        let y = min(max(topInset, 110), max(size.height * 0.26, topInset))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static let fallbackNormalizedRect = CGRect(x: 0.12, y: 0.24, width: 0.76, height: 0.20)
}
