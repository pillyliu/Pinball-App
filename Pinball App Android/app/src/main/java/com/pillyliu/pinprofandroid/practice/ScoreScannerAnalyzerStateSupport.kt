package com.pillyliu.pinprofandroid.practice

internal data class AnalyzerState(
    var lastOcrTimeMs: Long = 0L,
    var lastLiveBitmapFallbackTimeMs: Long = 0L,
    var isProcessingFrame: Boolean = false,
    var processingPaused: Boolean = false,
    var pendingFreezeRequest: Boolean = false,
    var pendingFreezePreferredReading: ScoreScannerLockedReading? = null,
    var frozenGate: Boolean = false,
    var latestSnapshot: ScoreScannerStabilityService.Snapshot? = null,
)

internal data class AnalyzerFramePermit(
    val requestedFreeze: Boolean,
    val requestedFreezePreferredReading: ScoreScannerLockedReading?,
)

internal inline fun <T> ScoreScannerController.withAnalyzerState(block: AnalyzerState.() -> T): T =
    synchronized(analyzerStateLock) {
        analyzerState.block()
    }

internal fun ScoreScannerController.requestPendingFreeze(preferredReading: ScoreScannerLockedReading?) {
    withAnalyzerState {
        pendingFreezePreferredReading = preferredReading
        pendingFreezeRequest = true
    }
}

internal fun ScoreScannerController.beginAnalyzerFrame(now: Long): AnalyzerFramePermit? =
    withAnalyzerState {
        if (processingPaused || frozenGate || isProcessingFrame || now - lastOcrTimeMs < liveOcrIntervalMs) {
            null
        } else {
            lastOcrTimeMs = now
            isProcessingFrame = true
            val requestedFreeze = pendingFreezeRequest
            val requestedFreezePreferredReading = pendingFreezePreferredReading
            if (requestedFreeze) {
                pendingFreezeRequest = false
                pendingFreezePreferredReading = null
            }
            AnalyzerFramePermit(
                requestedFreeze = requestedFreeze,
                requestedFreezePreferredReading = requestedFreezePreferredReading,
            )
        }
    }

internal fun ScoreScannerController.finishAnalyzerFrame() {
    withAnalyzerState {
        isProcessingFrame = false
    }
}

internal fun ScoreScannerController.updateAnalyzerSnapshot(
    candidate: ScoreScannerCandidate?,
): ScoreScannerStabilityService.Snapshot = withAnalyzerState {
    stabilityService.ingest(candidate).also { latestSnapshot = it }
}

