import SwiftUI
import Speech
import Vision
import UIKit

struct QuickAddView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Binding var isPresented: Bool
    var existingExpense: Expense? = nil

    @State private var amountText:        String          = ""
    @State private var selectedCategory:  ExpenseCategory = .food
    @State private var note:              String          = ""
    @State private var date:              Date            = Date()
    @State private var showDatePicker:    Bool            = false
    @State private var showReceiptCamera: Bool            = false
    @State private var isOCRScanning:     Bool            = false
    @State private var isIncome:          Bool            = false

    @StateObject private var speechService = SpeechService()

    var isEditing: Bool { existingExpense != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        // 支出 / 收入 切換
                        Picker("", selection: $isIncome) {
                            Text("支出").tag(false)
                            Text("收入").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)
                        .tint(AppTheme.primary)
                        .onChange(of: isIncome) { income in
                            // 切換類型時自動切換到對應的預設分類
                            if income {
                                if !selectedCategory.isIncomeCategory {
                                    selectedCategory = .salary
                                }
                            } else {
                                if selectedCategory.isIncomeCategory {
                                    selectedCategory = .food
                                }
                            }
                        }

                        AmountDisplaySection(amountText: amountText, isIncome: isIncome)
                        CategoryPickerSection(selectedCategory: $selectedCategory, isIncome: isIncome)
                        NoteSection(note: $note)
                        DateSection(date: $date, showPicker: $showDatePicker)
                    }
                    .padding()
                    .padding(.bottom, 8)
                }

                if speechService.isRecording || !speechService.transcript.isEmpty {
                    VoiceStatusBanner(speechService: speechService)
                }

                if isOCRScanning {
                    OCRScanningBanner()
                }

                CalcKeyboard(
                    amountText:  $amountText,
                    isRecording: speechService.isRecording,
                    isValid:     !amountText.isEmpty && Double(amountText) != nil,
                    onCamera:    { showReceiptCamera = true },
                    onSave:      save,
                    onMic:       handleMicTap
                )
            }
            .background(AppTheme.bg)
            .navigationTitle(isEditing ? "編輯記錄" : "快速記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                        .foregroundColor(AppTheme.pink)
                }
            }
            .onAppear {
                if let e = existingExpense {
                    amountText       = String(Int(e.amount))
                    selectedCategory = e.category
                    note             = e.note
                    date             = e.date
                    isIncome         = e.isIncome
                }
                Task {
                    if speechService.authStatus == .notDetermined {
                        await speechService.requestAuthorization()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showReceiptCamera) {
            ReceiptCameraView(isPresented: $showReceiptCamera) { img in
                handleCameraImage(img)
            }
        }
    }

    private func handleMicTap() {
        if speechService.isRecording {
            speechService.stopRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { parseVoice() }
        } else {
            speechService.startRecording()
        }
    }

    private func parseVoice() {
        guard !speechService.transcript.isEmpty else { return }
        let result = viewModel.parseVoiceInput(speechService.transcript)
        if let amt = result.amount { amountText = String(Int(amt)) }
        selectedCategory = result.category
        if !result.note.isEmpty { note = result.note }
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        if let existing = existingExpense {
            let updated = Expense(
                id: existing.id, amount: amount, category: selectedCategory,
                note: note, date: date, isIncome: isIncome,
                receiptImageData: existing.receiptImageData
            )
            viewModel.update(updated)
        } else {
            viewModel.add(Expense(amount: amount, category: selectedCategory,
                                  note: note, date: date, isIncome: isIncome))
        }
        isPresented = false
    }

    // MARK: - Receipt Camera / OCR

    private func handleCameraImage(_ img: UIImage) {
        isOCRScanning = true
        Task {
            let lines = await performOCR(on: img)
            let fullText = lines.joined(separator: " ")

            await MainActor.run {
                // 金額
                if let amt = extractAmount(from: lines) {
                    amountText = String(Int(amt))
                }
                // 分類 + 備註（利用現有的語音解析邏輯）
                let result = viewModel.parseVoiceInput(fullText)
                if result.category != .other { selectedCategory = result.category }
                if !result.note.isEmpty, note.isEmpty { note = result.note }
                isOCRScanning = false
            }
        }
    }

    private func performOCR(on image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let results = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = results.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func extractAmount(from lines: [String]) -> Double? {
        // 貨幣符號 pattern
        let patterns = [
            #"NT\$\s*(\d[\d,]*(?:\.\d+)?)"#,
            #"NTD\s*(\d[\d,]*(?:\.\d+)?)"#,
            #"\$\s*(\d[\d,]*(?:\.\d+)?)"#,
            #"(\d[\d,]*(?:\.\d+)?)\s*元"#,
            #"合計[：:\s]*(\d[\d,]*(?:\.\d+)?)"#,
            #"總計[：:\s]*(\d[\d,]*(?:\.\d+)?)"#,
            #"小計[：:\s]*(\d[\d,]*(?:\.\d+)?)"#,
            #"Total[：:\s]*(\d[\d,]*(?:\.\d+)?)"#,
        ]
        for line in lines {
            for pat in patterns {
                if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let r = Range(match.range(at: 1), in: line) {
                    let numStr = line[r].replacingOccurrences(of: ",", with: "")
                    if let v = Double(numStr), v > 0 { return v }
                }
            }
        }
        // fallback：最大數字
        var biggest: Double = 0
        for line in lines {
            if let regex = try? NSRegularExpression(pattern: #"(\d[\d,]*(?:\.\d+)?)"#),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let r = Range(match.range(at: 1), in: line) {
                let numStr = line[r].replacingOccurrences(of: ",", with: "")
                if let v = Double(numStr), v > biggest { biggest = v }
            }
        }
        return biggest > 0 ? biggest : nil
    }
}

// MARK: - Amount Display

struct AmountDisplaySection: View {
    let amountText: String
    var isIncome: Bool = false

    private var activeColor: Color {
        isIncome ? Color(hex: "34C759") : AppTheme.primary
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isIncome ? "plus.circle.fill" : "minus.circle.fill")
                    .foregroundColor(activeColor)
                    .font(.caption)
                Text("NT$")
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
            Text(amountText.isEmpty ? "0" : amountText)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .foregroundColor(amountText.isEmpty ? AppTheme.border : activeColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal)
        .cuteCard()
    }
}

// MARK: - Voice Status Banner

struct VoiceStatusBanner: View {
    @ObservedObject var speechService: SpeechService

    var body: some View {
        HStack(spacing: 10) {
            if speechService.isRecording {
                Image(systemName: "waveform")
                    .foregroundColor(AppTheme.mint)
                Text("正在聆聽…")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(AppTheme.mint)
            } else if !speechService.transcript.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.mint)
                Text(speechService.transcript)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.mint.opacity(0.15))
        .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
    }
}

// MARK: - OCR Scanning Banner

struct OCRScanningBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(AppTheme.coral)
                .scaleEffect(0.85)
            Text("正在辨識收據…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(AppTheme.coral)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.coral.opacity(0.12))
    }
}

// MARK: - Calculator Keyboard

struct CalcKeyboard: View {
    @Binding var amountText: String
    let isRecording: Bool
    let isValid:     Bool
    let onCamera:    () -> Void
    let onSave:      () -> Void
    let onMic:       () -> Void

    private let rows: [[CalcKey]] = [
        [.digit(7), .digit(8), .digit(9)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(1), .digit(2), .digit(3)],
        [.dot,      .digit(0), .delete  ],
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            VStack(spacing: 8) {
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(spacing: 8) {
                        ForEach(rows[r]) { key in
                            CalcKeyButton(key: key) { handleKey(key) }
                        }
                    }
                }

                HStack(spacing: 8) {
                    // 相機
                    ActionKeyButton(
                        icon: "camera.fill", label: "掃描",
                        gradient: AnyShapeStyle(AppTheme.coralGradient),
                        action: onCamera
                    )
                    // 儲存
                    ActionKeyButton(
                        icon: "checkmark", label: "儲存",
                        gradient: AnyShapeStyle(AppTheme.pinkGradient),
                        action: onSave
                    )
                    .opacity(isValid ? 1 : 0.45)
                    .disabled(!isValid)
                    // 麥克風
                    ActionKeyButton(
                        icon:   isRecording ? "stop.fill" : "mic.fill",
                        label:  isRecording ? "停止"     : "語音",
                        gradient: AnyShapeStyle(isRecording
                            ? LinearGradient(colors: [.red, Color(hex: "FF6B9D")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(hex: "4ECDC4"), Color(hex: "44CF6C")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        ),
                        action: onMic
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .background(AppTheme.surface)
        }
    }

    private func handleKey(_ key: CalcKey) {
        switch key {
        case .digit(let d):
            if amountText == "0" { amountText = String(d); return }
            amountText += String(d)
        case .dot:
            if !amountText.contains(".") {
                if amountText.isEmpty { amountText = "0" }
                amountText += "."
            }
        case .delete:
            if !amountText.isEmpty { amountText.removeLast() }
        }
    }
}

// MARK: - Calc Key Model

enum CalcKey: Identifiable {
    case digit(Int), dot, delete
    var id: String {
        switch self {
        case .digit(let d): return "d\(d)"
        case .dot:          return "dot"
        case .delete:       return "del"
        }
    }
    var label: String {
        switch self {
        case .digit(let d): return String(d)
        case .dot:          return "."
        case .delete:       return "⌫"
        }
    }
}

// MARK: - Number Key Button

struct CalcKeyButton: View {
    let key:    CalcKey
    let action: () -> Void

    private var isDelete: Bool {
        if case .delete = key { return true }
        return false
    }

    var body: some View {
        Button(action: action) {
            Text(key.label)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isDelete ? AppTheme.pinkLight : AppTheme.surface)
                .foregroundColor(isDelete ? AppTheme.pink : AppTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusKey, style: .continuous))
                .shadow(color: AppTheme.pink.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Key Button

struct ActionKeyButton: View {
    let icon:     String
    let label:    String
    let gradient: AnyShapeStyle
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(.white)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusKey, style: .continuous))
            .shadow(color: AppTheme.pink.opacity(0.15), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Picker

struct CategoryPickerSection: View {
    @Binding var selectedCategory: ExpenseCategory
    var isIncome: Bool = false
    let columns = [GridItem(.adaptive(minimum: 70), spacing: 10)]

    private var categories: [ExpenseCategory] {
        ExpenseCategory.allCases.filter { $0.isIncomeCategory == isIncome }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分類")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(categories) { cat in
                    Button { selectedCategory = cat } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectedCategory == cat
                                          ? cat.color
                                          : cat.color.opacity(0.12))
                                    .frame(height: 50)
                                Text(cat.emoji).font(.title2)
                            }
                            Text(cat.rawValue)
                                .font(.caption2)
                                .fontWeight(selectedCategory == cat ? .bold : .regular)
                                .foregroundColor(selectedCategory == cat ? cat.color : AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .cuteCard()
    }
}

// MARK: - Note Section

struct NoteSection: View {
    @Binding var note: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil")
                .foregroundColor(AppTheme.pink)
                .frame(width: 24)
            TextField("備註（選填）", text: $note)
                .font(.system(.body, design: .rounded))
        }
        .padding()
        .cuteCard()
    }
}

// MARK: - Date Section

struct DateSection: View {
    @Binding var date:       Date
    @Binding var showPicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.spring(response: 0.3)) { showPicker.toggle() } } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.pink)
                        .frame(width: 24)
                    Text(formattedDate)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.caption)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if showPicker {
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(AppTheme.pink)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .cuteCard()
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_TW")
        return f.string(from: date)
    }
}
