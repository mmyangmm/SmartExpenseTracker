import SwiftUI
import Speech

struct VoiceInputView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Binding var isPresented: Bool
    @StateObject private var speechService = SpeechService()

    @State private var parsedAmount:   Double?   = nil
    @State private var parsedCategory: ExpenseCategory = .other
    @State private var amountText:     String    = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var note:           String    = ""
    @State private var selectedDate:   Date      = Date()
    @State private var showConfirm:    Bool      = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                // 狀態圖示
                MicAnimationView(isRecording: speechService.isRecording)

                // 提示文字
                VStack(spacing: 8) {
                    if speechService.isRecording {
                        Text("正在聆聽…")
                            .font(.title3)
                            .foregroundColor(.teal)
                    } else if !speechService.transcript.isEmpty {
                        Text("已辨識：")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(speechService.transcript)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text("說出「午餐 150 元」")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("支援金額、分類關鍵字自動辨識")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }

                // 錯誤提示
                if let error = speechService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // 錄音按鈕
                if speechService.authStatus == .denied || speechService.authStatus == .restricted {
                    PermissionDeniedView()
                } else {
                    RecordButton(isRecording: speechService.isRecording) {
                        if speechService.isRecording {
                            speechService.stopRecording()
                            // 給 SFSpeechRecognizer 0.6 秒吐出最終 transcript
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                parseTranscript()
                            }
                        } else {
                            showConfirm = false
                            speechService.startRecording()
                        }
                    }
                }

                // 辨識結果快速確認
                if showConfirm {
                    ParsedResultCard(
                        amountText:       $amountText,
                        selectedCategory: $selectedCategory,
                        note:             $note,
                        selectedDate:     $selectedDate,
                        onSave:           saveExpense
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("語音記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        speechService.stopRecording()
                        isPresented = false
                    }
                }
            }
            .onAppear {
                Task {
                    if speechService.authStatus == .notDetermined {
                        await speechService.requestAuthorization()
                    }
                }
            }
        }
    }

    private func parseTranscript() {
        guard !speechService.transcript.isEmpty else { return }
        let result = viewModel.parseVoiceInput(speechService.transcript)
        parsedAmount     = result.amount
        parsedCategory   = result.category
        amountText       = result.amount.map { String(Int($0)) } ?? ""
        selectedCategory = result.category
        note             = result.note   // 使用去除金額後的乾淨備註
        selectedDate     = Date()

        withAnimation(.spring()) {
            showConfirm = true
        }
    }

    private func saveExpense() {
        guard let amount = Double(amountText), amount > 0 else { return }
        let expense = Expense(
            amount:   amount,
            category: selectedCategory,
            note:     note,
            date:     selectedDate
        )
        viewModel.add(expense)
        isPresented = false
    }
}

// MARK: - Mic Animation

struct MicAnimationView: View {
    let isRecording: Bool
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            if isRecording {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.teal.opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                        .frame(width: 80 + CGFloat(i) * 30, height: 80 + CGFloat(i) * 30)
                        .scaleEffect(isRecording ? pulse : 1)
                        .animation(
                            .easeInOut(duration: 1.2)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                            value: pulse
                        )
                }
            }
            Circle()
                .fill(isRecording ? Color.teal : Color(.systemGray5))
                .frame(width: 80, height: 80)
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 32))
                .foregroundColor(isRecording ? .white : .secondary)
        }
        .onAppear { pulse = 1.3 }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                Text(isRecording ? "停止錄音" : "開始錄音")
                    .fontWeight(.semibold)
            }
            .frame(width: 200)
            .padding()
            .background(isRecording ? Color.red : Color.teal)
            .foregroundColor(.white)
            .cornerRadius(30)
            .shadow(color: (isRecording ? Color.red : Color.teal).opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Parsed Result Card

struct ParsedResultCard: View {
    @Binding var amountText:      String
    @Binding var selectedCategory: ExpenseCategory
    @Binding var note:            String
    @Binding var selectedDate:    Date
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("辨識結果")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                // 金額
                VStack(alignment: .leading, spacing: 4) {
                    Text("金額").font(.caption2).foregroundColor(.secondary)
                    HStack {
                        Text("NT$").foregroundColor(.secondary)
                        TextField("金額", text: $amountText)
                            .keyboardType(.numberPad)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // 分類
                VStack(alignment: .leading, spacing: 4) {
                    Text("分類").font(.caption2).foregroundColor(.secondary)
                    Menu {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Label(cat.rawValue, systemImage: "")
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory.emoji)
                            Text(selectedCategory.rawValue)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(8)
                        .background(selectedCategory.color.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }

            // 消費日期時間
            VStack(alignment: .leading, spacing: 4) {
                Text("消費時間").font(.caption2).foregroundColor(.secondary)
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // 備註
            TextField("備註（可選）", text: $note)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            Button(action: onSave) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("確認儲存")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

// MARK: - Permission Denied

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("需要麥克風與語音辨識權限")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("前往設定") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
