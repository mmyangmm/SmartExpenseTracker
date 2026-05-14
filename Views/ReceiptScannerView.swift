import SwiftUI
import Vision
import PhotosUI

struct ReceiptScannerView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Binding var isPresented: Bool

    @State private var scanState: ScanState = .idle
    @State private var scannedText:   String = ""
    @State private var parsedAmount:  Double? = nil
    @State private var amountText:    String = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var note:          String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showCamera      = false
    @State private var photoItem:      PhotosPickerItem? = nil

    enum ScanState {
        case idle, scanning, done, error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 圖片預覽 / 選擇區
                    ImageSelectionArea(
                        image: selectedImage,
                        scanState: scanState,
                        onCamera: { showCamera = true },
                        onLibrary: { showImagePicker = true }
                    )

                    // OCR 狀態
                    switch scanState {
                    case .idle:
                        EmptyView()
                    case .scanning:
                        HStack {
                            ProgressView()
                            Text("正在辨識收據…")
                                .foregroundColor(.secondary)
                        }
                    case .done:
                        ScannedResultForm(
                            amountText:       $amountText,
                            selectedCategory: $selectedCategory,
                            note:             $note,
                            rawText:          scannedText,
                            onSave:           save
                        )
                    case .error(let msg):
                        Text("辨識失敗：\(msg)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("掃描收據")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                }
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: $photoItem,
                matching: .images
            )
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        selectedImage = img
                        await performOCR(on: img)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { img in
                    selectedImage = img
                    Task { await performOCR(on: img) }
                }
            }
        }
    }

    // MARK: - OCR

    private func performOCR(on image: UIImage) async {
        await MainActor.run { scanState = .scanning }

        guard let cgImage = image.cgImage else {
            await MainActor.run { scanState = .error("無法讀取圖片") }
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel  = .accurate
        request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            await MainActor.run { scanState = .error(error.localizedDescription) }
            return
        }

        let observations = request.results ?? []
        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string }
        let fullText = lines.joined(separator: "\n")

        let amount = extractAmount(from: fullText)

        await MainActor.run {
            scannedText      = fullText
            parsedAmount     = amount
            amountText       = amount.map { String(Int($0)) } ?? ""
            selectedCategory = viewModel.inferCategory(from: fullText)
            // 取最可能是店名的那行作備註
            note = lines.first(where: { $0.count > 2 && $0.count < 30 }) ?? ""
            scanState = .done
        }
    }

    // 從 OCR 文字中找金額
    private func extractAmount(from text: String) -> Double? {
        // 常見收據格式：總計、合計、金額、Total、Amount
        let totalPatterns = [
            #"(?:總計|合計|小計|Total|Amount|金額|應付)[^\d]*(\d{1,6}(?:[.,]\d{1,2})?)"#,
            #"NT\$\s*(\d+(?:[.,]\d{1,2})?)"#,
            #"\$\s*(\d{1,6}(?:\.\d{1,2})?)"#,
        ]

        for pattern in totalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let r = Range(match.range(at: 1), in: text) {
                    let numStr = text[r].replacingOccurrences(of: ",", with: "")
                    if let v = Double(numStr) { return v }
                }
            }
        }

        // fallback：找最大數字（通常是總金額）
        let numPat = #"(\d{2,6})"#
        if let regex = try? NSRegularExpression(pattern: numPat) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            let numbers = matches.compactMap { match -> Double? in
                guard let r = Range(match.range(at: 1), in: text) else { return nil }
                return Double(text[r])
            }
            // 合理範圍 10~9999
            return numbers.filter { $0 >= 10 && $0 <= 9999 }.max()
        }

        return nil
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        let expense = Expense(
            amount:          amount,
            category:        selectedCategory,
            note:            note,
            receiptImageData: selectedImage?.jpegData(compressionQuality: 0.6)
        )
        viewModel.add(expense)
        isPresented = false
    }
}

// MARK: - Image Selection Area

struct ImageSelectionArea: View {
    let image:     UIImage?
    let scanState: ReceiptScannerView.ScanState
    let onCamera:  () -> Void
    let onLibrary: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 180)
                    VStack(spacing: 8) {
                        Image(systemName: "receipt")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("拍攝或上傳收據")
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: onCamera) {
                    Label("拍攝", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Button(action: onLibrary) {
                    Label("相簿", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Scanned Result Form

struct ScannedResultForm: View {
    @Binding var amountText:     String
    @Binding var selectedCategory: ExpenseCategory
    @Binding var note:           String
    let rawText: String
    let onSave:  () -> Void

    @State private var showRawText = false

    var body: some View {
        VStack(spacing: 16) {
            Text("辨識完成")
                .font(.headline)
                .foregroundColor(.green)

            // 金額
            HStack {
                Text("NT$").foregroundColor(.secondary)
                TextField("金額", text: $amountText)
                    .keyboardType(.numberPad)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // 分類
            Picker("分類", selection: $selectedCategory) {
                ForEach(ExpenseCategory.allCases) { cat in
                    Label(cat.rawValue, systemImage: "").tag(cat)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // 備註
            TextField("備註", text: $note)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

            // 展開原始 OCR 文字
            DisclosureGroup("查看原始辨識文字", isExpanded: $showRawText) {
                Text(rawText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)

            Button(action: onSave) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("儲存記錄")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(!amountText.isEmpty ? Color.indigo : Color.secondary.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(amountText.isEmpty)
        }
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType  = .camera
        picker.delegate    = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage {
                onCapture(img)
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
