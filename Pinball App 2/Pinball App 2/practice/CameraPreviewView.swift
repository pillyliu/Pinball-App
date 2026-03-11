import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let onPreviewLayerReady: (AVCaptureVideoPreviewLayer) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onPreviewLayerReady = onPreviewLayerReady
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.previewLayer.videoGravity = .resizeAspectFill
        uiView.onPreviewLayerReady = onPreviewLayerReady
        uiView.notifyPreviewLayerReadyIfNeeded()
    }
}

final class PreviewView: UIView {
    var onPreviewLayerReady: ((AVCaptureVideoPreviewLayer) -> Void)?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        notifyPreviewLayerReadyIfNeeded()
    }

    func notifyPreviewLayerReadyIfNeeded() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        onPreviewLayerReady?(previewLayer)
    }
}
