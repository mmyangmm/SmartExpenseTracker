import SwiftUI
import Combine
import AVFoundation
import Vision

// MARK: - CameraCoordinator

final class CameraCoordinator: NSObject,
    AVCaptureMetadataOutputObjectsDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    var onQRCode: ((String) -> Void)?
    var onOCRText: ((String) -> Void)?
    var isOCRMode: Bool = false

    private var lastOCRTime: Date = .distantPast
    private let ocrInterval: TimeInterval = 1.5

    // MARK: QR Delegate
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isOCRMode else { return }
        for obj in metadataObjects {
            if let readable = obj as? AVMetadataMachineReadableCodeObject,
               readable.type == .qr,
               let value = readable.stringValue {
                onQRCode?(value)
                return
            }
        }
    }

    // MARK: OCR Delegate
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isOCRMode else { return }
        let now = Date()
        guard now.timeIntervalSince(lastOCRTime) > ocrInterval else { return }
        lastOCRTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let results = req.results as? [VNRecognizedTextObservation] else { return }
            let text = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            guard !text.isEmpty else { return }
            DispatchQueue.main.async {
                self?.onOCRText?(text)
            }
        }
        request.recognitionLanguages = ["zh-Hant", "en-US"]
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - CameraPreview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = UIScreen.main.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - InvoiceScanVM

@MainActor
final class InvoiceScanVM: ObservableObject {
    @Published var scannedString: String? = nil
    @Published var permissionDenied: Bool = false

    enum Mode { case qrCode, ocr }
    var mode: Mode = .qrCode {
        didSet { coordinator.isOCRMode = (mode == .ocr) }
    }

    let session = AVCaptureSession()
    let coordinator = CameraCoordinator()
    private let sessionQueue = DispatchQueue(label: "invoiceScan.session")

    func setup() {
        coordinator.onQRCode = { [weak self] str in
            Task { @MainActor in
                self?.scannedString = str
            }
        }
        coordinator.onOCRText = { [weak self] text in
            Task { @MainActor in
                self?.scannedString = text
            }
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if !granted {
                Task { @MainActor in self.permissionDenied = true }
                return
            }
            self.sessionQueue.async { self.configureSession() }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Input
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // Metadata (QR)
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(coordinator, queue: .main)
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
            }
        }

        // Video data (OCR)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(coordinator, queue: DispatchQueue(label: "invoiceScan.ocr"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func reset() {
        scannedString = nil
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

    @State private var showConfirm = false
    @State private var showManual = false
    @State private var pendingInvoice: Invoice? = nil
    @State private var selectedMode: Int = 0  // 0=QR, 1=OCR

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(session: vm.session)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        vm.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text(selectedMode == 0 ? "掃描電子發票" : "掃描傳統發票")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        vm.stop()
                        showManual = true
                    } label: {
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

                // Viewfinder
                if selectedMode == 0 {
                    // QR: square 240x240
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clear)
                            .frame(width: 240, height: 240)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        ViewfinderCorners(size: CGSize(width: 240, height: 240))
                    }
                } else {
                    // Traditional invoice: wide 300x80
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .frame(width: 300, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        ViewfinderCorners(size: CGSize(width: 300, height: 80), lineLength: 20)
                    }
                }

                Spacer()

                // Mode picker + hint
                VStack(spacing: 12) {
                    Picker("掃描模式", selection: $selectedMode) {
                        Text("📱 電子發票 QR碼").tag(0)
                        Text("🧾 傳統發票").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .onChange(of: selectedMode) { _, newVal in
                        vm.mode = newVal == 0 ? .qrCode : .ocr
                    }

                    Text(selectedMode == 0 ? "將 QR 碼對準框內" : "將發票號碼對準框內")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 100)
            }

            // Permission denied overlay
            if vm.permissionDenied {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("需要相機權限")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("請至「設定」> 「隱私權」> 「相機」開啟")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .onAppear { vm.setup(); vm.start() }
        .onDisappear { vm.stop() }
        .onChange(of: vm.scannedString) { _, str in
            guard let str else { return }
            handleScanned(str)
        }
        .sheet(isPresented: $showConfirm) {
            if let inv = pendingInvoice {
                InvoiceConfirmSheet(invoice: inv) { confirmed in
                    invoiceService.add(confirmed)
                    showConfirm = false
                    vm.stop()
                    dismiss()
                }
                .environmentObject(invoiceService)
            }
        }
        .sheet(isPresented: $showManual) {
            InvoiceManualEntrySheet { inv in
                invoiceService.add(inv)
                showManual = false
                vm.stop()
                dismiss()
            }
        }
    }

    private func handleScanned(_ str: String) {
        if selectedMode == 0 {
            // QR mode
            if let invoice = invoiceService.parseQRCode(str) {
                pendingInvoice = invoice
                showConfirm = true
            } else {
                // Not a valid invoice QR — reset after 2s
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    vm.reset()
                }
            }
        } else {
            // OCR mode
            if let number = invoiceService.extractInvoiceNumber(from: str) {
                pendingInvoice = Invoice(invoiceNumber: number, source: .ocr)
                showConfirm = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    vm.reset()
                }
            }
        }
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
