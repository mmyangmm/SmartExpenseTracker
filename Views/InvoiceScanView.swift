import SwiftUI
import Combine
import AVFoundation
import Vision
import os.log

#if DEBUG
private let qrLog = Logger(subsystem: "com.Felix.SmartExpenseTracker", category: "QRScan")
private func qrPrint(_ msg: @autoclosure () -> String) {
    let text = msg()
    qrLog.debug("\(text, privacy: .private)")
}
#else
private func qrPrint(_ msg: @autoclosure () -> String) {}
#endif

// MARK: - CameraBox
// Non-actor container so session operations run on sessionQueue, not main thread.
// (Project uses -default-isolation=MainActor; storing camera objects here keeps them free.)

private final class CameraBox {
    let session     = AVCaptureSession()
    let coordinator = CameraCoordinator()
    let queue       = DispatchQueue(label: "invoiceScan.session")
    private var device: AVCaptureDevice?

    /// Configure session and start running — must be called on `queue`.
    func configureAndStart() {
        guard session.inputs.isEmpty else {
            if !session.isRunning { session.startRunning() }
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        // Use a virtual device that bundles the ultra-wide/macro lens.
        // Priority: triple (13 Pro+) → dual-wide → dual → wide-only fallback.
        // A virtual device is required for automatic macro lens switching.
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredTypes,
            mediaType: .video,
            position: .back
        )
        guard let dev = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: dev),
              session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        device = dev
        session.addInput(input)

        // QR metadata output
        let metaOut = AVCaptureMetadataOutput()
        if session.canAddOutput(metaOut) {
            session.addOutput(metaOut)
            metaOut.setMetadataObjectsDelegate(coordinator, queue: .main)
            if metaOut.availableMetadataObjectTypes.contains(.qr) {
                metaOut.metadataObjectTypes = [.qr]
            }
        }

        // Video data output for OCR
        let videoOut = AVCaptureVideoDataOutput()
        videoOut.setSampleBufferDelegate(coordinator,
            queue: DispatchQueue(label: "invoiceScan.ocr"))
        if session.canAddOutput(videoOut) { session.addOutput(videoOut) }

        // Configure autofocus, autoexposure, and automatic macro switching
        try? dev.lockForConfiguration()
        if dev.isFocusModeSupported(.continuousAutoFocus) {
            dev.focusMode = .continuousAutoFocus
        }
        if dev.isExposureModeSupported(.continuousAutoExposure) {
            dev.exposureMode = .continuousAutoExposure
        }
        // Keep full AF range so macro distances are reachable
        if dev.isAutoFocusRangeRestrictionSupported {
            dev.autoFocusRangeRestriction = .none
        }
        // Automatic macro lens switching — same behaviour as native Camera app (iOS 15+)
        // Only available on virtual devices that include an ultra-wide constituent.
        if #available(iOS 15.0, *), dev.constituentDevices.count > 1 {
            dev.setPrimaryConstituentDeviceSwitchingBehavior(
                .auto,
                restrictedSwitchingBehaviorConditions: []
            )
        }
        dev.unlockForConfiguration()

        session.commitConfiguration()
        session.startRunning()
    }

    // MARK: Focus
    /// Point is in camera device coordinates (0–1). Call from any thread.
    func setFocus(at point: CGPoint) {
        guard let dev = device else { return }
        try? dev.lockForConfiguration()
        if dev.isFocusPointOfInterestSupported {
            dev.focusPointOfInterest = point
            dev.focusMode = .autoFocus
        }
        if dev.isExposurePointOfInterestSupported {
            dev.exposurePointOfInterest = point
            dev.exposureMode = .autoExpose
        }
        dev.unlockForConfiguration()

        // After 2.5 s return to continuous autofocus
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let dev = self?.device else { return }
            try? dev.lockForConfiguration()
            if dev.isFocusModeSupported(.continuousAutoFocus) {
                dev.focusMode = .continuousAutoFocus
            }
            if dev.isExposureModeSupported(.continuousAutoExposure) {
                dev.exposureMode = .continuousAutoExposure
            }
            dev.unlockForConfiguration()
        }
    }

    // MARK: Torch
    /// Toggle torch and return new state (true = on).
    @discardableResult
    func toggleTorch() -> Bool {
        guard let dev = device, dev.hasTorch else { return false }
        let turnOn = dev.torchMode != .on
        try? dev.lockForConfiguration()
        if turnOn {
            try? dev.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else {
            dev.torchMode = .off
        }
        dev.unlockForConfiguration()
        return turnOn
    }

    func start() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stop()  { queue.async { if  self.session.isRunning { self.session.stopRunning()  } } }
}

// MARK: - CameraCoordinator

final class CameraCoordinator: NSObject,
    AVCaptureMetadataOutputObjectsDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    /// Called when BOTH left and right QR codes are detected in the same frame.
    var onBothQR:  ((String, String) -> Void)?
    /// Called when only the left QR code is detected.
    var onLeftQR:  ((String) -> Void)?
    /// Called when only the right QR code is detected.
    var onRightQR: ((String) -> Void)?
    var onQRBoundsUpdate:  ((_ left: CGRect?, _ right: CGRect?) -> Void)?
    var onAutoFocusPoint:  ((CGPoint) -> Void)?  // screen point → auto-focus trigger
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastAutoFocusTime: Date = .distantPast
    var onOCRText: ((String) -> Void)?
    var isOCRMode: Bool = false

    private var lastOCRTime:    Date = .distantPast
    private let ocrInterval:    TimeInterval = 1.5
    private var lastVisionQRTime: Date = .distantPast
    private let visionQRInterval: TimeInterval = 0.25  // Vision QR fallback cadence

    // MARK: QR — scan multiple codes in one frame
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isOCRMode else { return }
        qrPrint("▶︎ metadataOutput: \(metadataObjects.count) object(s)")
        var leftQR:  String?
        var rightQR: String?

        for obj in metadataObjects {
            guard let qr = obj as? AVMetadataMachineReadableCodeObject, qr.type == .qr else {
                qrPrint("  skip non-QR: \(obj.type.rawValue)")
                continue
            }
            guard let value = qr.stringValue else {
                qrPrint("  ⚠️ QR localized but stringValue=nil (too dense/blurry to decode)")
                continue
            }
            qrPrint("  QR payload(60): \(String(value.prefix(60)))")
            if value.hasPrefix("**") {
                rightQR = value
            } else if isInvoiceLeftQR(value) {
                leftQR = value
            } else {
                qrPrint("  ↳ not invoice format — first segment: \(value.components(separatedBy: ":").first ?? "?")")
            }
        }

        if let l = leftQR, let r = rightQR {
            qrPrint("✅ metadata: both QR found")
            onBothQR?(l, r)
        } else if let l = leftQR {
            qrPrint("🟡 metadata: left QR only — \(l.prefix(20))")
            onLeftQR?(l)
        } else if let r = rightQR {
            qrPrint("🔵 metadata: right QR only — storing for cross-frame match")
            onRightQR?(r)
        }

        // Emit screen-space bounds for overlay drawing
        var leftBounds: CGRect? = nil
        var rightBounds: CGRect? = nil
        for obj in metadataObjects {
            guard let qr = obj as? AVMetadataMachineReadableCodeObject,
                  qr.type == .qr,
                  let transformed = previewLayer?.transformedMetadataObject(for: qr) else { continue }
            let b = transformed.bounds
            if qr.stringValue?.hasPrefix("**") == true { rightBounds = b }
            else if let v = qr.stringValue, isInvoiceLeftQR(v) { leftBounds = b }
            else if leftBounds == nil && rightBounds == nil {
                qrPrint("  📦 bounds-fallback: payload=\(qr.stringValue?.prefix(60) ?? "nil (undecodable)")")
                leftBounds = b
            }
        }
        onQRBoundsUpdate?(leftBounds, rightBounds)

        // Auto-focus on undecodable QR: if we can localize but not decode, nudge focus toward it
        let now2 = Date()
        if now2.timeIntervalSince(lastAutoFocusTime) > 1.5,
           let pl = previewLayer {
            let focusBounds = leftBounds ?? rightBounds
            if let fb = focusBounds {
                let screenCenter = CGPoint(x: fb.midX, y: fb.midY)
                let devicePt = pl.captureDevicePointConverted(fromLayerPoint: screenCenter)
                lastAutoFocusTime = now2
                onAutoFocusPoint?(devicePt)
            }
        }
    }

    private func isInvoiceLeftQR(_ value: String) -> Bool {
        return value.range(of: "^[A-Za-z]{2}\\d{8}", options: .regularExpression) != nil
    }

    // MARK: Video frames — QR Vision fallback + OCR
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if isOCRMode {
            // ── OCR path ──────────────────────────────────────────────
            guard now.timeIntervalSince(lastOCRTime) > ocrInterval else { return }
            lastOCRTime = now
            let req = VNRecognizeTextRequest { [weak self] r, _ in
                guard let obs = r.results as? [VNRecognizedTextObservation] else { return }
                let text = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                guard !text.isEmpty else { return }
                DispatchQueue.main.async { self?.onOCRText?(text) }
            }
            req.recognitionLanguages = ["zh-Hant", "en-US"]
            req.recognitionLevel = .accurate
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([req])

        } else {
            // ── Vision QR fallback (supplements AVCaptureMetadataOutput) ──
            // Fires when the metadata delegate misses partially obscured finder patterns.
            guard now.timeIntervalSince(lastVisionQRTime) > visionQRInterval else { return }
            lastVisionQRTime = now
            qrPrint("🔍 Vision QR scan triggered")
            let req = VNDetectBarcodesRequest { [weak self] r, error in
                if let error {
                    qrPrint("❌ Vision error: \(error.localizedDescription)")
                    return
                }
                guard let self else { return }
                let allResults = r.results as? [VNBarcodeObservation] ?? []
                qrPrint("  Vision found \(allResults.count) barcode(s)")
                for obs in allResults {
                    qrPrint("  symbology=\(obs.symbology.rawValue) confidence=\(obs.confidence) payload=\(obs.payloadStringValue?.prefix(20) ?? "nil")")
                }
                var leftQR: String?, rightQR: String?
                for obs in allResults where obs.symbology == .qr {
                    guard let payload = obs.payloadStringValue else { continue }
                    if payload.hasPrefix("**") { rightQR = payload }
                    else if self.isInvoiceLeftQR(payload) { leftQR = payload }
                    else { qrPrint("  ↳ QR payload not invoice format") }
                }
                guard leftQR != nil || rightQR != nil else { return }
                DispatchQueue.main.async {
                    if let l = leftQR, let r = rightQR {
                        qrPrint("✅ Vision: both QR found")
                        self.onBothQR?(l, r)
                    } else if let l = leftQR {
                        qrPrint("🟡 Vision: left QR only — \(l.prefix(20))")
                        self.onLeftQR?(l)
                    } else if let r = rightQR {
                        qrPrint("🔵 Vision: right QR only — storing for cross-frame match")
                        self.onRightQR?(r)
                    }
                }
            }
            req.symbologies = [.qr]
            // Back camera in portrait → pixel buffer is rotated 90° clockwise (.right).
            // Passing the correct orientation is critical: without it Vision reads QR codes sideways
            // and the finder-pattern detector fails on anything but perfectly square framing.
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .right,   // kCGImagePropertyOrientationRight
                options: [:]
            )
            do {
                try handler.perform([req])
            } catch {
                qrPrint("❌ Vision perform error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CameraPreview
// Uses layerClass so the preview layer auto-fills the view bounds — most reliable approach.

final class _PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Called on tap: (devicePoint 0–1, screenPoint in view coords)
    var onTap: ((_ device: CGPoint, _ screen: CGPoint) -> Void)?
    var onPreviewLayerReady: ((AVCaptureVideoPreviewLayer) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> _PreviewView {
        let v = _PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        onPreviewLayerReady?(v.previewLayer)
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        v.addGestureRecognizer(tap)
        context.coordinator.view = v
        context.coordinator.onTap = onTap
        return v
    }

    func updateUIView(_ uiView: _PreviewView, context: Context) {
        context.coordinator.onTap = onTap
        // onPreviewLayerReady is one-shot (called only in makeUIView)
    }

    final class Coordinator: NSObject {
        weak var view: _PreviewView?
        var onTap: ((_ device: CGPoint, _ screen: CGPoint) -> Void)?

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let v = view else { return }
            let screenPt = g.location(in: v)
            let devicePt = v.previewLayer.captureDevicePointConverted(fromLayerPoint: screenPt)
            onTap?(devicePt, screenPt)
        }
    }
}

// MARK: - InvoiceScanVM

@MainActor
final class InvoiceScanVM: ObservableObject {
    @Published var permissionDenied: Bool = false
    @Published var leftQRData:  String? = nil
    @Published var rightQRData: String? = nil
    @Published var ocrText:     String? = nil
    @Published var isTorchOn:   Bool    = false
    @Published var leftQRBounds:  CGRect? = nil
    @Published var rightQRBounds: CGRect? = nil

    enum Mode { case qrCode, ocr }
    var mode: Mode = .qrCode {
        didSet { box.coordinator.isOCRMode = (mode == .ocr) }
    }

    private let box = CameraBox()
    var session: AVCaptureSession { box.session }

    func setup() {
        let coord = box.coordinator
        coord.onBothQR = { [weak self] left, right in
            DispatchQueue.main.async {
                let alreadySet = self?.leftQRData != nil
                qrPrint("📥 onBothQR dispatch: leftQRData=\(alreadySet ? "already set" : "nil")")
                guard !alreadySet else { return }
                self?.leftQRData  = left
                self?.rightQRData = right
                qrPrint("📥 onBothQR: set leftQRData=\(left.prefix(20))")
            }
        }
        coord.onLeftQR = { [weak self] left in
            DispatchQueue.main.async {
                guard self?.leftQRData == nil else { return }
                self?.leftQRData = left
            }
        }
        coord.onRightQR = { [weak self] right in
            DispatchQueue.main.async {
                guard self?.rightQRData == nil else { return }
                self?.rightQRData = right
            }
        }
        coord.onOCRText = { [weak self] text in
            DispatchQueue.main.async { self?.ocrText = text }
        }
        coord.onQRBoundsUpdate = { [weak self] left, right in
            DispatchQueue.main.async {
                self?.leftQRBounds  = left
                self?.rightQRBounds = right
            }
        }
        coord.onAutoFocusPoint = { [weak self] devicePt in
            self?.setFocus(at: devicePt)
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            box.queue.async { [box = self.box] in box.configureAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.box.queue.async { [box = self.box] in box.configureAndStart() }
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    /// Tap-to-focus. `devicePoint` is in 0–1 camera coordinate space.
    func setFocus(at devicePoint: CGPoint) {
        box.queue.async { [box = self.box] in box.setFocus(at: devicePoint) }
    }

    func toggleTorch() {
        box.queue.async { [box = self.box, weak self] in
            let on = box.toggleTorch()
            DispatchQueue.main.async { self?.isTorchOn = on }
        }
    }

    func start() { box.start() }
    func stop()  {
        // Turn off torch when stopping
        if isTorchOn { toggleTorch() }
        box.stop()
    }

    func reset() {
        leftQRData    = nil
        rightQRData   = nil
        ocrText       = nil
        leftQRBounds  = nil
        rightQRBounds = nil
    }

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        box.coordinator.previewLayer = layer
    }
}

// MARK: - ViewfinderCorners

struct ViewfinderCorners: View {
    let size: CGSize
    let color: Color
    let lineLength: CGFloat
    let lineWidth: CGFloat

    init(size: CGSize, color: Color = .white, lineLength: CGFloat = 24, lineWidth: CGFloat = 3) {
        self.size = size
        self.color = color
        self.lineLength = lineLength
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Top-left
            Path { p in
                p.move(to: CGPoint(x: 0, y: lineLength))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: lineLength, y: 0))
            }
            .stroke(color, lineWidth: lineWidth)

            // Top-right
            Path { p in
                p.move(to: CGPoint(x: size.width - lineLength, y: 0))
                p.addLine(to: CGPoint(x: size.width, y: 0))
                p.addLine(to: CGPoint(x: size.width, y: lineLength))
            }
            .stroke(color, lineWidth: lineWidth)

            // Bottom-left
            Path { p in
                p.move(to: CGPoint(x: 0, y: size.height - lineLength))
                p.addLine(to: CGPoint(x: 0, y: size.height))
                p.addLine(to: CGPoint(x: lineLength, y: size.height))
            }
            .stroke(color, lineWidth: lineWidth)

            // Bottom-right
            Path { p in
                p.move(to: CGPoint(x: size.width - lineLength, y: size.height))
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: size.width, y: size.height - lineLength))
            }
            .stroke(color, lineWidth: lineWidth)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - InvoiceScanView

struct InvoiceScanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var invoiceService: InvoiceService
    @StateObject private var vm = InvoiceScanVM()

    @State private var showConfirm    = false
    @State private var showManual     = false
    @State private var pendingInvoice: Invoice? = nil
    @State private var selectedMode: Int = 0   // 0=QR, 1=OCR
    @State private var leftFound      = false

    // Tap-to-focus indicator
    @State private var focusPoint:   CGPoint = .zero
    @State private var focusVisible: Bool    = false

    var body: some View {
        ZStack {
            CameraPreview(session: vm.session,
                          onTap: { devicePt, screenPt in
                vm.setFocus(at: devicePt)
                focusPoint   = screenPt
                focusVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    focusVisible = false
                }
            }, onPreviewLayerReady: { vm.setPreviewLayer($0) })
            .ignoresSafeArea()

            // Focus indicator
            if focusVisible {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: 68, height: 68)
                    .position(focusPoint)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: focusVisible)
            }

            // QR bounding box overlays
            if selectedMode == 0 {
                if let b = vm.leftQRBounds {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(vm.leftQRData != nil ? Color.green : Color.blue, lineWidth: 2.5)
                        .frame(width: b.width, height: b.height)
                        .position(x: b.midX, y: b.midY)
                }
                if let b = vm.rightQRBounds {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(vm.rightQRData != nil ? Color.green : Color.blue, lineWidth: 2.5)
                        .frame(width: b.width, height: b.height)
                        .position(x: b.midX, y: b.midY)
                }
            }

            VStack {
                // ── Top bar ──────────────────────────────────────────
                HStack {
                    // Close
                    Button { vm.stop(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(selectedMode == 0 ? "掃描電子發票" : "掃描傳統發票")
                        .font(.headline).foregroundColor(.white)
                    Spacer()
                    // Torch
                    Button { vm.toggleTorch() } label: {
                        Image(systemName: vm.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(vm.isTorchOn ? .yellow : .white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    // Manual entry
                    Button { vm.stop(); showManual = true } label: {
                        Image(systemName: "keyboard")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()

                // ── Viewfinder ───────────────────────────────────────
                if selectedMode == 0 {
                    HStack(spacing: 79) {
                        ForEach(0..<2, id: \.self) { _ in
                            Image(systemName: "qrcode")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
                                .foregroundColor(.white)
                                .opacity(0.22)
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .frame(width: 300, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                            )
                        ViewfinderCorners(size: CGSize(width: 300, height: 80), lineLength: 20)
                    }
                }

                Spacer()

                // ── Bottom controls ──────────────────────────────────
                VStack(spacing: 14) {
                    Picker("掃描模式", selection: $selectedMode) {
                        Text("📱 電子發票 QR碼").tag(0)
                        Text("🧾 傳統發票").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .onChange(of: selectedMode) { _, v in
                        vm.mode = v == 0 ? .qrCode : .ocr
                        vm.reset(); leftFound = false
                    }

                    Text(selectedMode == 0
                         ? (leftFound ? "✓ 左側已讀取，請對準右側 QR Code" : "將發票兩個 QR Code 對準鏡頭")
                         : "將發票號碼對準框內")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)

                    // Skip button: appears after left QR is captured but right isn't yet
                    if selectedMode == 0 && leftFound && vm.rightQRData == nil {
                        Button { showConfirm = true; vm.stop() } label: {
                            Text("略過右側 QR，直接確認")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.bottom, 100)
            }

            // ── Permission denied overlay ─────────────────────────
            if vm.permissionDenied {
                Color.black.opacity(0.85).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill").font(.largeTitle).foregroundColor(.white)
                    Text("需要相機權限").font(.headline).foregroundColor(.white)
                    Text("請至「設定」>「隱私權」>「相機」開啟")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .onAppear  { vm.reset(); vm.setup(); leftFound = false; pendingInvoice = nil }
        .onDisappear { vm.stop() }
        // Left QR detected
        .onChange(of: vm.leftQRData) { _, val in
            guard let val, !leftFound else { return }
            qrPrint("🔄 onChange leftQRData: payload(60)=\(val.prefix(60))")
            if let invoice = invoiceService.parseQRCode(val) {
                qrPrint("✅ parseQRCode success: \(invoice.invoiceNumber) amount=\(invoice.amount)")
                pendingInvoice = invoice
                leftFound = true
                if let r = vm.rightQRData {
                    qrPrint("🔗 rightQRData already set, calling applyRightQR")
                    applyRightQR(r)
                } else {
                    qrPrint("⏳ waiting for rightQRData")
                }
            } else {
                qrPrint("❌ parseQRCode returned nil — resetting in 2s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    vm.reset()
                    leftFound = false
                    pendingInvoice = nil
                }
            }
        }
        // Right QR detected
        .onChange(of: vm.rightQRData) { _, val in
            qrPrint("🔄 onChange rightQRData: leftFound=\(leftFound) val=\(val?.prefix(20) ?? "nil")")
            guard let val, leftFound else { return }
            applyRightQR(val)
        }
        // OCR text detected
        .onChange(of: vm.ocrText) { _, val in
            guard let val else { return }
            if let number = invoiceService.extractInvoiceNumber(from: val) {
                pendingInvoice = Invoice(invoiceNumber: number, source: .ocr)
                showConfirm = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { vm.reset() }
            }
        }
        .sheet(isPresented: $showConfirm) {
            if let inv = pendingInvoice {
                InvoiceConfirmSheet(invoice: inv) { confirmed in
                    invoiceService.add(confirmed)
                    showConfirm = false; vm.stop(); dismiss()
                }
                .environmentObject(invoiceService)
            }
        }
        .sheet(isPresented: $showManual) {
            InvoiceManualEntrySheet { inv in
                invoiceService.add(inv)
                showManual = false; vm.stop(); dismiss()
            }
        }
    }

    private func applyRightQR(_ raw: String) {
        qrPrint("🔧 applyRightQR: prefix=\(raw.prefix(10)) pendingInvoice=\(pendingInvoice?.invoiceNumber ?? "nil")")
        guard raw.hasPrefix("**"), pendingInvoice != nil else {
            qrPrint("⛔ applyRightQR guard failed: hasPrefix(**)=\(raw.hasPrefix("**")) pendingInvoice=\(pendingInvoice != nil)")
            return
        }
        let extra = invoiceService.parseRightQRCode(raw)
        if !extra.sellerName.isEmpty { pendingInvoice?.sellerName = extra.sellerName }
        if !extra.items.isEmpty      { pendingInvoice?.items      = extra.items }
        qrPrint("🎉 showConfirm = true")
        showConfirm = true
        vm.stop()
    }
}

// MARK: - QRStatusDot

private struct QRStatusDot: View {
    let label: String
    let found: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: found ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(found ? .green : .white.opacity(0.5))
            Text(label)
                .font(.caption)
                .foregroundColor(found ? .green : .white.opacity(0.6))
        }
        .animation(.easeInOut(duration: 0.2), value: found)
    }
}

// MARK: - InvoiceConfirmSheet

struct InvoiceConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (Invoice) -> Void

    @State private var invoice: Invoice

    init(invoice: Invoice, onConfirm: @escaping (Invoice) -> Void) {
        self._invoice = State(initialValue: invoice)
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("發票資訊") {
                    HStack {
                        Text("發票號碼")
                        Spacer()
                        Text(invoice.formattedNumber)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    DatePicker("日期", selection: $invoice.date, displayedComponents: .date)

                    HStack {
                        Text("金額 (NT$)")
                        Spacer()
                        TextField("0", value: $invoice.amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    TextField("商家名稱", text: $invoice.sellerName)
                    TextField("備註", text: $invoice.note)
                }

                if !invoice.items.isEmpty {
                    Section("品項") {
                        ForEach(invoice.items) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("NT$ \(Int(item.amount))")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("確認發票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { onConfirm(invoice) }
                }
            }
        }
    }
}

// MARK: - InvoiceManualEntrySheet

struct InvoiceManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Invoice) -> Void

    @State private var invoiceNumber = ""
    @State private var date = Date()
    @State private var amountStr = ""
    @State private var sellerName = ""
    @State private var note = ""
    @State private var validationError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("發票號碼") {
                    TextField("例: AB-12345678", text: $invoiceNumber)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    if let err = validationError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("詳細資訊") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)

                    HStack {
                        Text("金額 (NT$)")
                        Spacer()
                        TextField("0", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    TextField("商家名稱", text: $sellerName)
                    TextField("備註", text: $note)
                }
            }
            .navigationTitle("手動輸入發票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { validateAndSave() }
                }
            }
        }
    }

    private func validateAndSave() {
        let normalized = invoiceNumber.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        let pattern = "^[A-Z]{2}\\d{8}$"
        guard normalized.range(of: pattern, options: .regularExpression) != nil else {
            validationError = "格式錯誤，應為 2 個英文字母 + 8 個數字"
            return
        }
        validationError = nil

        let amount = Double(amountStr) ?? 0
        let invoice = Invoice(
            invoiceNumber: normalized,
            date: date,
            sellerName: sellerName,
            amount: amount,
            note: note,
            source: .manual
        )
        onSave(invoice)
    }
}

// MARK: - Invoice init with source param convenience

private extension Invoice {
    init(invoiceNumber: String, date: Date = Date(), sellerName: String = "",
         sellerTaxID: String = "", amount: Double = 0, items: [InvoiceItem] = [],
         note: String = "", source: InvoiceSource = .manual) {
        self.init(
            invoiceNumber: invoiceNumber,
            date: date,
            sellerName: sellerName,
            sellerTaxID: sellerTaxID,
            amount: amount,
            items: items,
            lotteryResult: .pending,
            source: source,
            note: note
        )
    }
}
