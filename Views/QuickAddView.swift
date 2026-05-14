import SwiftUI
import Speech

struct QuickAddView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Binding var isPresented: Bool
    var existingExpense: Expense? = nil

    @State private var amountText:       String          = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var note:             String          = ""
    @State private var date:             Date            = Date()
    @State private var showDatePicker:   Bool            = false
    @State private var showScanner:      Bool            = false

    @StateObject private var speechService = SpeechService()

    var isEditing: Bool { existingExpense != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── 可捲動的表單區域 ──────────────────────────────
                ScrollView {
                    VStack(spacing: 16) {
                        AmountDisplaySection(amountText: amountText)
                        CategoryPickerSection(selectedCategory: $selectedCategory)
                        NoteSection(note: $note)
                        DateSection(date: $date, showPicker: $showDatePicker)
                    }
                    .padding()
                    .padding(.bottom, 8)
                }

                // ── 語音狀態列 ───────────────────────────────────
                if speechService.isRecording || !speechService.transcript.isEmpty {
                    VoiceStatusBanner(speechService: speechService)
                }

                // ── 計算機鍵盤（固定底部）────────────────────────
                CalcKeyboard(
                    amountText:  $amountText,
                    isRecording: speechService.isRecording,
                    isValid:     !amountText.isEmpty && Double(amountText) != nil,
                    onCamera:    { showScanner = true },
                    onSave:      save,
                    onMic:       handleMicTap
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "編輯記錄" : "快速記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }
                }
            }
            .onAppear {
                if let e = existingExpense {
                    amountText       = String(Int(e.amount))
                    selectedCategory = e.category
                    note             = e.note
                    date             = e.date
                }
                Task {
                    if speechService.authStatus == .notDetermined {
                        await speechService.requestAuthorization()
                    }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ReceiptScannerView(isPresented: $showScanner)
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        if speechService.isRecording {
            speechService.stopRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                parseVoice()
            }
        } else {
            speechService.startRecording()
        }
    }

    private func parseVoice() {
        guard !speechService.transcript.isEmpty else { return }
        let result = viewModel.parseVoiceInput(speechService.transcript)
        if let amt = result.amount {
            amountText = String(Int(amt))
        }
        selectedCategory = result.category
        if !result.note.isEmpty { note = result.note }
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        if let existing = existingExpense {
            let updated = Expense(
                id:               existing.id,
                amount:           amount,
                category:         selectedCategory,
                note:             note,
                date:             date,
                receiptImageData: existing.receiptImageData
            )
            viewModel.update(updated)
        } else {
            viewModel.add(Expense(
                amount:   amount,
                category: selectedCategory,
                note:     note,
                date:     date
            ))
        }
        isPresented = false
    }
}

// MARK: - Amount Display (read-only)

struct AmountDisplaySection: View {
    let amountText: String

    var body: some View {
        VStack(spacing: 6) {
            Text("NT$")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(amountText.isEmpty ? "0" : amountText)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(height: 70)
                .foregroundColor(amountText.isEmpty ? Color(.systemGray3) : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Voice Status Banner

struct VoiceStatusBanner: View {
    @ObservedObject var speechService: SpeechService

    var body: some View {
        HStack(spacing: 10) {
            if speechService.isRecording {
                Image(systemName: "waveform")
                    .foregroundColor(.teal)
                Text("正在聆聽…")
                    .font(.subheadline)
                    .foregroundColor(.teal)
            } else if !speechService.transcript.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(speechService.transcript)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(speechService.isRecording
                    ? Color.teal.opacity(0.1)
                    : Color.green.opacity(0.08))
        .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
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
            Divider()
            VStack(spacing: 7) {

                // 數字列
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(spacing: 7) {
                        ForEach(rows[r]) { key in
                            CalcKeyButton(key: key) { handleKey(key) }
                        }
                    }
                }

                // 動作列：相機 ｜ 儲存 ｜ 麥克風
                HStack(spacing: 7) {
                    // 相機
                    ActionKeyButton(
                        icon:   "camera.fill",
                        label:  "掃描",
                        color:  .orange,
                        filled: false,
                        action: onCamera
                    )

                    // 儲存
                    ActionKeyButton(
                        icon:   "checkmark.circle.fill",
                        label:  "儲存",
                        color:  .indigo,
                        filled: true,
                        action: onSave
                    )
                    .opacity(isValid ? 1 : 0.45)
                    .disabled(!isValid)

                    // 麥克風
                    ActionKeyButton(
                        icon:   isRecording ? "stop.fill" : "mic.fill",
                        label:  isRecording ? "停止"     : "語音",
                        color:  isRecording ? .red        : .teal,
                        filled: false,
                        action: onMic
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 20)   // 底部安全區留白
            .background(Color(.systemBackground))
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
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDelete ? Color(.systemGray4) : Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Key Button

struct ActionKeyButton: View {
    let icon:   String
    let label:  String
    let color:  Color
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(filled ? color : color.opacity(0.12))
            .foregroundColor(filled ? .white : color)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Re-used sub-sections (kept from original)

struct CategoryPickerSection: View {
    @Binding var selectedCategory: ExpenseCategory

    let columns = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分類")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ExpenseCategory.allCases) { cat in
                    Button { selectedCategory = cat } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedCategory == cat
                                          ? cat.color
                                          : cat.color.opacity(0.15))
                                    .frame(height: 50)
                                Text(cat.emoji).font(.title2)
                            }
                            Text(cat.rawValue)
                                .font(.caption)
                                .foregroundColor(selectedCategory == cat ? cat.color : .secondary)
                                .fontWeight(selectedCategory == cat ? .semibold : .regular)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct NoteSection: View {
    @Binding var note: String

    var body: some View {
        HStack {
            Image(systemName: "note.text")
                .foregroundColor(.secondary)
                .frame(width: 24)
            TextField("備註（選填）", text: $note)
                .font(.body)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct DateSection: View {
    @Binding var date:       Date
    @Binding var showPicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation { showPicker.toggle() } } label: {
                HStack {
                    Image(systemName: "calendar").foregroundColor(.secondary)
                    Text(formattedDate).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if showPicker {
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_TW")
        return f.string(from: date)
    }
}
