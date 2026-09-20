import Foundation
import AVFoundation
import Vision
import CoreMedia

final class CameraPresenceDetector:
    NSObject,
    @unchecked Sendable {

    enum Result {
        case present
        case absent
        case failed
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "IdleFaceLock.Camera")

    private var completion: (@Sendable (Result) -> Void)?
    private var detectionFinished = false
    private var frameCount = 0
    private var faceFrameCount = 0
    private var detectionTimer: DispatchWorkItem?

    // Called once during application startup.
    // This is the only place where requestAccess() is ever invoked.
    func prepareCameraAccess(
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        sessionQueue.async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)

            switch status {
            case .authorized:
                AppLogger.log("Camera permission: authorized.")
                completion(true)

            case .notDetermined:
                AppLogger.log(
                    "Camera permission: not determined. Requesting access once at startup..."
                )

                AVCaptureDevice.requestAccess(for: .video) { granted in
                    AppLogger.log(
                        "Camera permission request finished:",
                        granted ? "granted" : "denied"
                    )
                    completion(granted)
                }

            case .denied:
                AppLogger.error(
                    "Camera permission: denied. Enable it in System Settings > Privacy & Security > Camera."
                )
                completion(false)

            case .restricted:
                AppLogger.error("Camera permission: restricted.")
                completion(false)

            @unknown default:
                AppLogger.error("Camera permission: unknown status.")
                completion(false)
            }
        }
    }

    func detectPresence(
        completion: @escaping @Sendable (Result) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.startDetection(completion: completion)
        }
    }

    private func startDetection(
        completion: @escaping @Sendable (Result) -> Void
    ) {
        self.completion = completion
        detectionFinished = false
        frameCount = 0
        faceFrameCount = 0

        // No requestAccess() here. Permission was handled once at startup.
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            AppLogger.error("Camera is not authorized at detection time.")
            finishDetection(result: .failed)
            return
        }

        guard configureSession() else {
            AppLogger.error("Camera configuration failed.")
            finishDetection(result: .failed)
            return
        }

        AppLogger.log("Camera ON")

        let usingRevision3 = VNDetectFaceRectanglesRequest.supportedRevisions
            .contains(VNDetectFaceRectanglesRequestRevision3)
        AppLogger.log(
            "Face detector revision:",
            usingRevision3
                ? "3 (tilt-tolerant)"
                : "platform default (revision 3 unsupported)"
        )

        session.startRunning()

        guard session.isRunning else {
            AppLogger.error("Camera session failed to start.")
            finishDetection(result: .failed)
            return
        }

        sessionQueue.asyncAfter(
            deadline: .now() + AppConfig.cameraWarmupTime
        ) { [weak self] in
            guard let self, !self.detectionFinished else { return }
            AppLogger.log("Camera session warmup should be completed")
        }

        let timer = DispatchWorkItem { [weak self] in
            guard let self, !self.detectionFinished else { return }

            AppLogger.log("Camera detection timeout")

            if self.faceFrameCount >= AppConfig.requiredFaceFrames {
                self.finishDetection(result: .present)
            } else if self.frameCount < 2 {
                // No frame was ever analyzed within the detection window
                // (the first frame is skipped as warmup). The camera never
                // delivered usable frames, so this is a camera/session
                // failure, not a genuine "no person". Treat as failure so the
                // app enters safe mode instead of locking the screen.
                AppLogger.error(
                    "Camera delivered no analyzable frames before timeout; treating as failure, not absence."
                )
                self.finishDetection(result: .failed)
            } else {
                self.finishDetection(result: .absent)
            }
        }

        detectionTimer = timer

        sessionQueue.asyncAfter(
            deadline: .now() + AppConfig.maxDetectionDuration,
            execute: timer
        )
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            AppLogger.error("No front camera found.")
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            guard session.canAddInput(input) else {
                AppLogger.error("Cannot add camera input.")
                return false
            }

            session.addInput(input)
        } catch {
            AppLogger.error("Cannot create camera input:", error)
            return false
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        guard session.canAddOutput(output) else {
            AppLogger.error("Cannot add video output.")
            return false
        }

        session.addOutput(output)
        return true
    }

    private func detectFace(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest {
            [weak self] request, error in

            guard let self, !self.detectionFinished else {
                return
            }

            if let error {
                AppLogger.error("Vision error:", error)
                self.finishDetection(result: .failed)
                return
            }

            let faces = request.results as? [VNFaceObservation] ?? []

            if !faces.isEmpty {
                // boundingBox is normalized (0...1) relative to the oriented
                // image, so its width/height are already the per-axis
                // proportion of the frame. Multiply by the oriented pixel
                // dimensions to recover an approximate size in pixels. The
                // request uses .leftMirrored, so the oriented image swaps the
                // buffer's width and height.
                let orientedWidth = CVPixelBufferGetHeight(pixelBuffer)
                let orientedHeight = CVPixelBufferGetWidth(pixelBuffer)

                for (index, face) in faces.enumerated() {
                    let box = face.boundingBox
                    AppLogger.log(
                        String(
                            format:
                                "Face %d size: %.0fx%.0f px (%.1f%% x %.1f%% of frame), area %.2f%% of frame",
                            index,
                            box.width * CGFloat(orientedWidth),
                            box.height * CGFloat(orientedHeight),
                            box.width * 100,
                            box.height * 100,
                            box.width * box.height * 100
                        )
                    )
                }

                // Distance gate: only a face large enough to fill at least
                // minFaceAreaRatio of the frame counts as present. This
                // rejects someone standing further back or a passer-by in the
                // background. Use the largest face so the nearest person decides.
                let largestAreaRatio = faces
                    .map { $0.boundingBox.width * $0.boundingBox.height }
                    .max() ?? 0

                if largestAreaRatio >= AppConfig.minFaceAreaRatio {
                    self.faceFrameCount += 1
                    AppLogger.log(
                        "Face detected (near): frame",
                        self.frameCount,
                        "face frames",
                        self.faceFrameCount
                    )
                } else {
                    AppLogger.log(
                        String(
                            format:
                                "Face too far: frame %d, largest area %.2f%% < %.2f%% threshold",
                            self.frameCount,
                            largestAreaRatio * 100,
                            AppConfig.minFaceAreaRatio * 100
                        )
                    )
                }
            } else {
                AppLogger.log("No face: frame", self.frameCount)
            }

            if self.faceFrameCount >= AppConfig.requiredFaceFrames {
                self.finishDetection(result: .present)
                return
            }

            if self.frameCount >= AppConfig.maxDetectionFrames {
                self.finishDetection(
                    result: self.faceFrameCount >= AppConfig.requiredFaceFrames
                        ? .present
                        : .absent
                )
            }
        }

        // Prefer revision 3 (better tolerance for tilted / rotated heads),
        // but fall back gracefully on systems that don't support it so the
        // detector keeps working with the platform default revision.
        if VNDetectFaceRectanglesRequest.supportedRevisions
            .contains(VNDetectFaceRectanglesRequestRevision3) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            AppLogger.error("Vision request failed:", error)
            finishDetection(result: .failed)
        }
    }

    private func finishDetection(result: Result) {
        guard !detectionFinished else {
            return
        }

        detectionFinished = true
        detectionTimer?.cancel()
        detectionTimer = nil

        switch result {
        case .present:
            AppLogger.log("Camera detection finished: PERSON PRESENT")
        case .absent:
            AppLogger.log("Camera detection finished: NO PERSON")
        case .failed:
            AppLogger.error("Camera detection finished: FAILED")
        }

        if session.isRunning {
            session.stopRunning()
        }

        for input in session.inputs {
            session.removeInput(input)
        }

        for output in session.outputs {
            session.removeOutput(output)
        }

        AppLogger.log("Camera OFF")

        let callback = completion
        completion = nil
        callback?(result)
    }
}

extension CameraPresenceDetector:
    AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !detectionFinished else {
            return
        }

        frameCount += 1

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            finishDetection(result: .failed)
            return
        }

        if frameCount <= 1 {
            return
        }

        detectFace(in: pixelBuffer)
    }
}
