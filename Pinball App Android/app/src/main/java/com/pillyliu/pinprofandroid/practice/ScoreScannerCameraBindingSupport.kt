package com.pillyliu.pinprofandroid.practice

import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.cancel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

internal fun ScoreScannerController.bindCamera(
    lifecycleOwner: LifecycleOwner,
    previewView: PreviewView,
) {
    boundLifecycleOwner = lifecycleOwner
    boundPreviewView = previewView
    if (!hasCameraPermission) {
        status = ScoreScannerStatus.CameraPermissionRequired
        return
    }

    scope.launch {
        val provider = try {
            cameraProvider ?: ProcessCameraProvider.getInstance(appContext).await().also {
                cameraProvider = it
            }
        } catch (_: Exception) {
            status = ScoreScannerStatus.CameraUnavailable
            return@launch
        }

        withContext(Dispatchers.Main.immediate) {
            runCatching {
                provider.unbindAll()

                val preview = Preview.Builder().build().also { useCase ->
                    useCase.surfaceProvider = previewView.surfaceProvider
                }

                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { useCase ->
                        useCase.setAnalyzer(cameraExecutor, ::analyzeFrame)
                    }

                val boundCamera = provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis,
                )

                imageAnalysis = analysis
                camera = boundCamera

                val maxZoom = boundCamera.cameraInfo.zoomState.value?.maxZoomRatio?.coerceAtMost(8f) ?: 8f
                availableZoomRange = 1f..maxZoom.coerceAtLeast(1f)
                updateZoomFactor(1f)
                status = ScoreScannerStatus.Searching
            }.onFailure {
                status = ScoreScannerStatus.CameraUnavailable
            }
        }
    }
}

internal fun ScoreScannerController.dispose() {
    imageAnalysis?.clearAnalyzer()
    cameraProvider?.unbindAll()
    ocrService.close()
    scope.cancel()
    cameraExecutor.shutdown()
}

private suspend fun <T> ListenableFuture<T>.await(): T = suspendCancellableCoroutine { continuation ->
    addListener(
        {
            runCatching { get() }
                .onSuccess { continuation.resume(it) }
                .onFailure { continuation.resumeWithException(it) }
        },
        java.util.concurrent.Executor { runnable -> runnable.run() },
    )
}
