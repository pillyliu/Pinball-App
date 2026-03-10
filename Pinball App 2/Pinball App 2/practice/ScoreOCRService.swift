import Foundation
import Vision
import CoreImage

final class ScoreOCRService {
    enum Mode {
        case livePreview
        case finalPass
    }

    func recognize(
        in image: CIImage,
        mode: Mode,
        displayMode: ScoreScannerDisplayMode = .lcd
    ) throws -> ScoreOCRAnalysis {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = mode == .livePreview ? .fast : .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = minimumTextHeight(for: displayMode, mode: mode)

        let handler = VNImageRequestHandler(ciImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        let observations = (request.results ?? []).flatMap { observation in
            observation.topCandidates(mode == .livePreview ? 2 : 4).map { candidate in
                ScoreOCRObservation(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox
                )
            }
        }

        let candidates = ScoreParsingService.rankedCandidates(from: observations)
        return ScoreOCRAnalysis(bestCandidate: candidates.first, candidates: candidates)
    }

    private func minimumTextHeight(for displayMode: ScoreScannerDisplayMode, mode: Mode) -> Float {
        switch (displayMode, mode) {
        case (.lcd, .livePreview):
            return 0.10
        case (.lcd, .finalPass):
            return 0.06
        case (.dmd, .livePreview):
            return 0.08
        case (.dmd, .finalPass):
            return 0.05
        case (.segmented, .livePreview):
            return 0.12
        case (.segmented, .finalPass):
            return 0.08
        }
    }
}
