import SwiftUI

// MARK: - Trip Record（旅行結算自動儲存）

struct TripRecord: Codable, Identifiable {
    let id:           String   // = travelSessionId
    let currencyCode: String
    let startDate:    Date
    let endDate:      Date

    private static let key = "completedTripRecords_v1"

    static func loadAll() -> [TripRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([TripRecord].self, from: data)
        else { return [] }
        return records.sorted { $0.endDate > $1.endDate }
    }

    static func append(_ record: TripRecord) {
        var all = loadAll()
        // 避免重複
        all.removeAll { $0.id == record.id }
        all.insert(record, at: 0)
        // 最多保留 50 筆
        if all.count > 50 { all = Array(all.prefix(50)) }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var formattedDateRange: String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy/M/d"
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return f.string(from: startDate)
        }
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var viewModel:           ExpenseViewModel
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @State private var showClearConfirm  = false
    @State private var showExportSheet   = false
    @State private var exportURL: URL?   = nil
    @State private var showSyncAlert     = false
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName
    @State private var iconSwitchError: String? = nil
    @AppStorage("appTheme") private var appTheme: String = ThemeVariant.pink.rawValue

    // 出國模式
    @AppStorage("travelModeEnabled")   private var travelModeEnabled:   Bool   = false
    @AppStorage("travelModeCurrency")  private var travelModeCurrency:  String = "JPY"
    @AppStorage("travelModeStartTs")   private var travelModeStartTs:   Double = 0
    @AppStorage("travelModeSessionId") private var travelModeSessionId: String = ""
    @State private var showCurrencyPicker   = false
    @State private var showTravelSummary    = false
    @State private var summarySessionId     = ""
    @State private var summaryCurrencyCode  = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 主題色彩
                Section {
                    HStack(spacing: 6) {
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

                // MARK: 出國模式
                Section {
                    // 主開關
                    Toggle(isOn: $travelModeEnabled) {
                        Label("出國模式", systemImage: "airplane")
                    }
                    .tint(AppTheme.primary)
                    .onChange(of: travelModeEnabled) { _, enabled in
                        if enabled {
                            // 開啟：建立新旅程 session
                            travelModeStartTs   = Date().timeIntervalSince1970
                            travelModeSessionId = UUID().uuidString
                            Task { await exchangeRateService.fetchRate(for: travelModeCurrency) }
                        } else {
                            // 關閉：自動儲存旅行結算紀錄
                            let sid = travelModeSessionId
                            let cur = travelModeCurrency
                            if !sid.isEmpty {
                                let record = TripRecord(
                                    id:           sid,
                                    currencyCode: cur,
                                    startDate:    Date(timeIntervalSince1970: travelModeStartTs),
                                    endDate:      Date()
                                )
                                TripRecord.append(record)
                                summarySessionId    = sid
                                summaryCurrencyCode = cur
                                showTravelSummary   = true
                            }
                        }
                    }

                    if travelModeEnabled {
                        // 幣別選擇
                        Button {
                            showCurrencyPicker = true
                        } label: {
                            HStack {
                                if let tc = TravelCurrency.find(travelModeCurrency) {
                                    Label {
                                        Text("\(tc.flag)  \(tc.name)（\(tc.code)）")
                                            .foregroundColor(AppTheme.textPrimary)
                                    } icon: {
                                        Image(systemName: "dollarsign.circle")
                                            .foregroundColor(AppTheme.primary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }

                        // 即時匯率
                        HStack {
                            Label("即時匯率", systemImage: "arrow.2.circlepath")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            if exchangeRateService.isLoading {
                                ProgressView().scaleEffect(0.75)
                            } else {
                                VStack(alignment: .trailing, spacing: 2) {
                                    if exchangeRateService.rateToTWD > 0 {
                                        let rateStr = exchangeRateService.rateToTWD >= 1
                                            ? String(format: "NT$ %.2f", exchangeRateService.rateToTWD)
                                            : String(format: "NT$ %.4f", exchangeRateService.rateToTWD)
                                        Text("1 \(travelModeCurrency) = \(rateStr)")
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                    if let err = exchangeRateService.errorMessage {
                                        Text(err)
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }

                        // 重新整理按鈕
                        Button {
                            Task { await exchangeRateService.fetchRate(for: travelModeCurrency) }
                        } label: {
                            Label("重新整理匯率", systemImage: "arrow.triangle.2.circlepath")
                                .font(.callout)
                        }
                        .foregroundColor(AppTheme.primary)

                        // 出發日期
                        if travelModeStartTs > 0 {
                            LabeledContent("出發日期") {
                                Text(Date(timeIntervalSince1970: travelModeStartTs),
                                     style: .date)
                                    .font(.callout)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }

                    // 過去旅行記錄
                    let pastTrips = TripRecord.loadAll()
                    if !pastTrips.isEmpty {
                        NavigationLink {
                            PastTripsView()
                        } label: {
                            Label("過去旅行記錄（\(pastTrips.count) 筆）",
                                  systemImage: "clock.arrow.circlepath")
                        }
                    }
                } header: {
                    Text("✈️  出國模式")
                } footer: {
                    if travelModeEnabled {
                        Text("出國模式進行中，記帳金額以 \(travelModeCurrency) 計算，自動換算台幣。關閉後將顯示旅行結算。")
                    } else {
                        Text("開啟後以外幣記帳，並即時顯示台幣換算。")
                    }
                }

                // MARK: 工具
                Section {
                    NavigationLink {
                        CurrencyConverterView()
                    } label: {
                        Label("匯率換算", systemImage: "arrow.left.arrow.right.circle.fill")
                    }
                } header: {
                    Text("💱  工具")
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
            // 幣別選擇器
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerSheet(selected: $travelModeCurrency) {
                    // 幣別變更後重新取匯率
                    Task { await exchangeRateService.fetchRate(for: travelModeCurrency) }
                }
            }
            // 旅行結算
            .sheet(isPresented: $showTravelSummary) {
                TravelModeSummaryView(
                    sessionId:    summarySessionId,
                    currencyCode: summaryCurrencyCode
                )
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

    /// Accent colour that represents this variant in the preview
    private var themeColor: Color {
        switch variant {
        case .pink:        return Color(hex: "FF6B9D")
        case .blue:        return Color(hex: "3B82F6")
        case .systemLight: return Color(hex: "007AFF")
        case .systemDark:  return Color(hex: "0A84FF")
        }
    }

    /// Background of the preview box
    private var themeBg: Color {
        switch variant {
        case .pink:        return Color(hex: "FFF5F9")
        case .blue:        return Color(hex: "EFF6FF")
        case .systemLight: return Color(hex: "F2F2F7")
        case .systemDark:  return Color(hex: "3A3A3C")
        }
    }

    /// Label text colour inside the preview box
    private var iconTextColor: Color {
        variant == .systemDark ? .white : Color(hex: "3D3D3D")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(themeBg)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? themeColor : Color.gray.opacity(0.2), lineWidth: 2.5)
                        )
                    VStack(spacing: 3) {
                        Text(variant.icon).font(.title3)
                        Circle().fill(themeColor).frame(width: 14, height: 14)
                    }
                }
                .shadow(color: themeColor.opacity(isSelected ? 0.22 : 0.06), radius: 6, y: 2)

                Text(variant.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? themeColor : AppTheme.textSecondary)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeColor)
                    .font(.caption2)
                    .opacity(isSelected ? 1 : 0)
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

// MARK: - Currency Picker Sheet

struct CurrencyPickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) var dismiss
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            List(TravelCurrency.all) { tc in
                Button {
                    selected = tc.code
                    onSelect()
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        CurrencyFlagView(tc: tc, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tc.name)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(tc.code)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        if tc.code == selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("選擇幣別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
}

// MARK: - Past Trips View

struct PastTripsView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @State private var records: [TripRecord] = []
    @State private var selectedRecord: TripRecord? = nil

    var body: some View {
        List {
            ForEach(records) { record in
                let tc = TravelCurrency.find(record.currencyCode)
                // 計算這趟旅程的支出筆數與金額
                let expenses = viewModel.expenses.filter {
                    $0.travelSessionId == record.id && !$0.isIncome
                }
                let totalTWD = expenses.reduce(0) { $0 + $1.amount }

                Button {
                    selectedRecord = record
                } label: {
                    HStack(spacing: 14) {
                        if let tc = tc {
                            CurrencyFlagView(tc: tc, size: 40)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(tc?.name ?? record.currencyCode)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("旅行")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Text(record.formattedDateRange)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("NT$\(Int(totalTWD))")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("\(expenses.count) 筆")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("過去旅行記錄")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { records = TripRecord.loadAll() }
        .sheet(item: $selectedRecord) { record in
            TravelModeSummaryView(sessionId: record.id,
                                  currencyCode: record.currencyCode)
        }
        .overlay {
            if records.isEmpty {
                VStack(spacing: 12) {
                    Text("✈️").font(.system(size: 52))
                    Text("尚無旅行記錄")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
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
