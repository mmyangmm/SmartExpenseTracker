import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @EnvironmentObject var notificationService: NotificationService
    @State private var showClearConfirm  = false
    @State private var showExportSheet   = false
    @State private var exportURL: URL?   = nil
    @State private var showSyncAlert     = false
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName
    @State private var iconSwitchError: String? = nil
    @AppStorage("appTheme") private var appTheme: String = ThemeVariant.pink.rawValue

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 主題色彩
                Section {
                    HStack(spacing: 16) {
                        ForEach(ThemeVariant.allCases) { variant in
                            ThemeOptionCell(
                                variant: variant,
                                isSelected: appTheme == variant.rawValue
                            ) {
                                appTheme = variant.rawValue
                            }
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("🎨  主題色彩")
                } footer: {
                    Text("切換後立即生效，整個介面配色將同步更新。")
                }

                // MARK: iCloud 同步
                Section {
                    HStack {
                        Label("iCloud 同步", systemImage: "icloud.fill")
                        Spacer()
                        if viewModel.isSyncing {
                            ProgressView().scaleEffect(0.8).tint(AppTheme.pink)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    Button {
                        viewModel.manualSync()
                        showSyncAlert = true
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if let err = viewModel.syncError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                } header: {
                    Text("☁️  備份與同步")
                }

                // MARK: 通知提醒
                Section {
                    Toggle(isOn: $notificationService.reminderEnabled) {
                        Label("每日記帳提醒", systemImage: "bell.fill")
                    }
                    .tint(AppTheme.pink)
                    if notificationService.reminderEnabled {
                        HStack {
                            Label("提醒時間", systemImage: "clock")
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: {
                                        var c = Calendar.current.dateComponents([.hour, .minute], from: Date())
                                        c.hour   = notificationService.reminderHour
                                        c.minute = notificationService.reminderMinute
                                        return Calendar.current.date(from: c) ?? Date()
                                    },
                                    set: { newDate in
                                        let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                        notificationService.reminderHour   = c.hour ?? 21
                                        notificationService.reminderMinute = c.minute ?? 0
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }
                    if !notificationService.isAuthorized {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("前往設定開啟通知權限", systemImage: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("🔔  通知提醒")
                }

                // MARK: 資料管理
                Section {
                    Button { exportData() } label: {
                        Label("匯出 JSON", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("清空所有資料", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("📊  資料管理")
                } footer: {
                    Text("共 \(viewModel.expenses.count) 筆記錄")
                }

                // MARK: App 圖示
                Section {
                    HStack(spacing: 16) {
                        ForEach(AppIconOption.allCases) { option in
                            AppIconCell(
                                option: option,
                                isSelected: currentIconName == option.alternateIconName
                            ) {
                                switchIcon(to: option)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    if let err = iconSwitchError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                } header: {
                    Text("🎨  App 圖示")
                } footer: {
                    Text("選擇您喜歡的 App 圖示，更換後立即生效。")
                }

                // MARK: 關於
                Section {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("最低系統需求", value: "iOS 16.0")
                    LabeledContent("iCloud Container", value: "iCloud.com.yourcompany.SmartExpenseTracker")
                        .font(.caption)
                } header: {
                    Text("ℹ️  關於")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .accentColor(AppTheme.pink)
            .confirmationDialog("確認清空", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空所有資料", role: .destructive) {
                    viewModel.expenses.removeAll()
                    UserDefaults.standard.removeObject(forKey: "expenses_v1")
                }
            } message: {
                Text("此操作不可復原，確認要刪除所有記錄嗎？")
            }
            .alert("同步已啟動", isPresented: $showSyncAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("正在從 iCloud 同步資料，請稍候。")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL { ShareSheet(items: [url]) }
            }
        }
    }

    private func exportData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(viewModel.expenses) else { return }
        let fileName = "expenses_\(formattedDate()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            exportURL = url
            showExportSheet = true
        } catch {
            print("[Export] error: \(error)")
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }

    private func switchIcon(to option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconSwitchError = "此裝置不支援更換圖示"; return
        }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            DispatchQueue.main.async {
                if let error { iconSwitchError = "更換失敗：\(error.localizedDescription)" }
                else { currentIconName = option.alternateIconName; iconSwitchError = nil }
            }
        }
    }
}

// MARK: - Theme Option Cell

struct ThemeOptionCell: View {
    let variant:    ThemeVariant
    let isSelected: Bool
    let onTap:      () -> Void

    private var themeColor: Color {
        variant == .pink ? Color(hex: "FF6B9D") : Color(hex: "3B82F6")
    }
    private var themeBg: Color {
        variant == .pink ? Color(hex: "FFF5F9") : Color(hex: "EFF6FF")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themeBg)
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? themeColor : Color.clear, lineWidth: 3)
                        )
                    VStack(spacing: 4) {
                        Text(variant.icon).font(.title2)
                        Circle().fill(themeColor).frame(width: 20, height: 20)
                    }
                }
                .shadow(color: themeColor.opacity(isSelected ? 0.25 : 0.08), radius: 8, y: 3)

                Text(variant.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? themeColor : AppTheme.textSecondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeColor)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - App Icon Option

enum AppIconOption: String, CaseIterable, Identifiable {
    case `default` = "預設"
    case cat       = "貓咪"
    var id: String { rawValue }
    var alternateIconName: String? { self == .default ? nil : "AppIconAlt" }
    var previewAsset: String { self == .default ? "AppIcon" : "AppIconAlt" }
    var label: String { rawValue }
}

// MARK: - App Icon Cell

struct AppIconCell: View {
    let option:     AppIconOption
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Group {
                    if let img = UIImage(named: option.previewAsset) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(option == .default ? AppTheme.purple : AppTheme.mint)
                            .overlay(
                                Image(systemName: option == .default ? "yensign.circle.fill" : "cat.fill")
                                    .font(.largeTitle).foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? AppTheme.pink : Color.clear, lineWidth: 3)
                )
                .shadow(color: AppTheme.pink.opacity(isSelected ? 0.25 : 0.08), radius: 8, y: 3)

                Text(option.label)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? AppTheme.pink : AppTheme.textSecondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.pink)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
