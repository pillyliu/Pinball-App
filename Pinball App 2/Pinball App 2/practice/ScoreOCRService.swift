import Foundation
import Vision
import CoreImage

nonisolated final class ScoreOCRService {
    enum Mode {
        case livePreview
        case finalPass
    }

    private struct RecognitionVariant {
        let image: CIImage
        let confidenceMultiplier: Float
    }

    func recognize(
        in image: CIImage,
        mode: Mode,
        displayMode: ScoreScannerDisplayMode = .lcd
    ) throws -> ScoreOCRAnalysis {
        let observations = try recognitionVariants(for: image, mode: mode).flatMap { variant in
            try recognizeObservations(
                in: variant.image,
                mode: mode,
                displayMode: displayMode,
                confidenceMultiplier: variant.confidenceMultiplier
            )
        }

        let candidates = ScoreParsingService.rankedCandidates(from: observations)
        return ScoreOCRAnalysis(bestCandidate: candidates.first, candidates: candidates)
    }

    private func recognizeObservations(
        in image: CIImage,
        mode: Mode,
        displayMode: ScoreScannerDisplayMode,
        confidenceMultiplier: Float
    ) throws -> [ScoreOCRObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = minimumTextHeight(for: displayMode, mode: mode)

        let handler = VNImageRequestHandler(ciImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        return (request.results ?? []).flatMap { observation in
            observation.topCandidates(mode == .livePreview ? 3 : 8).map { candidate in
                ScoreOCRObservation(
                    text: candidate.string,
                    confidence: candidate.confidence * confidenceMultiplier,
                    boundingBox: observation.boundingBox
                )
            }
        }
    }

    private func recognitionVariants(for image: CIImage, mode: Mode) -> [RecognitionVariant] {
        var variants = [RecognitionVariant(image: image, confidenceMultiplier: 1)]

        if mode == .finalPass {
            let scaledContrastImage = image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 1.75
                ])
                .applyingFilter("CISharpenLuminance", parameters: [
                    kCIInputSharpnessKey: 0.7
                ])
                .applyingFilter("CILanczosScaleTransform", parameters: [
                    kCIInputScaleKey: 1.8,
                    kCIInputAspectRatioKey: 1
                ])

            variants.append(
                RecognitionVariant(
                    image: scaledContrastImage,
                    confidenceMultiplier: 0.97
                )
            )

            let boostedExposureImage = image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 2.0,
                    kCIInputBrightnessKey: 0.02
                ])
                .applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: 0.3
                ])
                .applyingFilter("CILanczosScaleTransform", parameters: [
                    kCIInputScaleKey: 2.1,
                    kCIInputAspectRatioKey: 1
                ])

            variants.append(
                RecognitionVariant(
                    image: boostedExposureImage,
                    confidenceMultiplier: 0.92
                )
            )

            let monochromeOutlineImage = image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 2.35,
                    kCIInputBrightnessKey: 0.03
                ])
                .applyingFilter("CIUnsharpMask", parameters: [
                    kCIInputIntensityKey: 0.85,
                    kCIInputRadiusKey: 1.35
                ])
                .applyingFilter("CIGammaAdjust", parameters: [
                    "inputPower": 0.74
                ])
                .applyingFilter("CILanczosScaleTransform", parameters: [
                    kCIInputScaleKey: 2.25,
                    kCIInputAspectRatioKey: 1
                ])

            variants.append(
                RecognitionVariant(
                    image: monochromeOutlineImage,
                    confidenceMultiplier: 0.9
                )
            )
        }

        return variants
    }

    private func minimumTextHeight(for displayMode: ScoreScannerDisplayMode, mode: Mode) -> Float {
        switch (displayMode, mode) {
        case (.lcd, .livePreview):
            return 0.03
        case (.lcd, .finalPass):
            return 0.02
        case (.dmd, .livePreview):
            return 0.025
        case (.dmd, .finalPass):
            return 0.018
        case (.segmented, .livePreview):
            return 0.04
        case (.segmented, .finalPass):
            return 0.025
        }
    }
}
