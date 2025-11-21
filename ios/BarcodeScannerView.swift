import AVFoundation
import SwiftUI

final class BarcodeScannerCoordinator: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let supportedTypes: [AVMetadataObject.ObjectType]
    private let onBarcodeDetected: (String) -> Void
    private var isRunning = false

    init(supportedTypes: [AVMetadataObject.ObjectType], onBarcodeDetected: @escaping (String) -> Void) {
        self.supportedTypes = supportedTypes
        self.onBarcodeDetected = onBarcodeDetected
        super.init()
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = supportedTypes
        }

        session.commitConfiguration()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = metadataObject.stringValue else { return }

        stop()
        onBarcodeDetected(barcode)
    }
}

struct BarcodeScannerView: View {
    @StateObject private var coordinator: BarcodeScannerCoordinator

    init(supportedTypes: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce], onBarcodeDetected: @escaping (String) -> Void) {
        _coordinator = StateObject(wrappedValue: BarcodeScannerCoordinator(supportedTypes: supportedTypes, onBarcodeDetected: onBarcodeDetected))
    }

    var body: some View {
        CameraPreview(session: coordinator.session)
            .onAppear { coordinator.start() }
            .onDisappear { coordinator.stop() }
            .ignoresSafeArea()
    }
}
