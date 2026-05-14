import SwiftUI

// MARK: - TWD Custom Icon & Shared Flag View

/// 顯示幣別圖示：TWD 使用自製藍色圓形徽章，其他顯示 emoji 國旗
struct CurrencyFlagView: View {
    let tc:   TravelCurrency
    var size: CGFloat = 32

    var body: some View {
        if tc.code == "TWD" {
            // 自訂台幣圖示：藍底白字「元」
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1565C0"), Color(hex: "1E88E5")],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                // 外圈細環
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: size * 0.05)
                    .frame(width: size * 0.82, height: size * 0.82)
                Text("元")
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        } else {
            Text(tc.flag)
                .font(.system(size: size * 0.68))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Currency Converter View

struct CurrencyConverterView: View {
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    @AppStorage("converterCurrencies")   private var savedCurrencies: String = "TWD,USD,JPY,EUR,CNY,HKD"
    @AppStorage("converterBaseCurrency") private var baseCurrency:    String = "TWD"

    @State private var inputText:  String = "1"
    @State private var showManage: Bool   = false

    private var selectedCodes: [String] {
        savedCurrencies.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private var inputAmount: Double { Double(inputText) ?? 0 }

    private func convertedAmount(for code: String) -> Double {
        guard code != baseCurrency else { return inputAmount }
        guard let rate = exchangeRateService.allRates[code], rate > 0 else { return 0 }
        return inputAmount * rate
    }

    private func formattedConverted(for code: String) -> String {
        let amount = convertedAmount(for: code)
        guard let tc = TravelCurrency.find(code) else { return "\(Int(amount))" }
        return tc.format(amount)
    }

    var body: some View {
        VStack(spacing: 0) {
            updateBar
            Divider().opacity(0.4)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(selectedCodes, id: \.self) { code in
                        ConverterCurrencyRow(
                            code:         code,
                            isBase:       code == baseCurrency,
                            displayValue: code == baseCurrency
                                            ? (inputText.isEmpty ? "0" : inputText)
                                            : formattedConverted(for: code)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { switchBase(to: code) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider().opacity(0.4)

            ConverterNumpad(text: $inputText)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("匯率換算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 18) {
                    Button {
                        Task { await exchangeRateService.fetchAllRates(base: baseCurrency) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button { showManage = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                .foregroundColor(AppTheme.primary)
            }
        }
        .sheet(isPresented: $showManage) {
            ManageCurrenciesSheet(savedCurrencies: $savedCurrencies,
                                  baseCurrency: baseCurrency)
        }
        .task {
            if exchangeRateService.allRates.isEmpty
                || exchangeRateService.converterBase != baseCurrency {
                await exchangeRateService.fetchAllRates(base: baseCurrency)
            }
        }
    }

    @ViewBuilder
    private var updateBar: some View {
        HStack(spacing: 6) {
            if exchangeRateService.isLoading {
                ProgressView().scaleEffect(0.7).tint(AppTheme.primary)
                Text("匯率更新中…")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            } else if let ts = exchangeRateService.lastUpdated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2).foregroundColor(.green)
                Text("更新於 \(RelativeDateTimeFormatter().localizedString(for: ts, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                if let err = exchangeRateService.errorMessage {
                    Text("（\(err)）")
                        .font(.caption2).foregroundColor(.orange)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 16)
        .background(AppTheme.surface)
    }

    private func switchBase(to code: String) {
        guard code != baseCurrency else { return }
        let converted = convertedAmount(for: code)
        baseCurrency  = code
        if converted <= 0 {
            inputText = "1"
        } else if converted.truncatingRemainder(dividingBy: 1) == 0 {
            inputText = "\(Int(converted))"
        } else {
            var s = String(format: "%.4f", converted)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            inputText = s
        }
        Task { await exchangeRateService.fetchAllRates(base: code) }
    }
}

// MARK: - Converter Currency Row

struct ConverterCurrencyRow: View {
    let code:         String
    let isBase:       Bool
    let displayValue: String

    private var tc: TravelCurrency? { TravelCurrency.find(code) }

    var body: some View {
        HStack(spacing: 14) {
            // 幣別圖示
            ZStack {
                Circle()
                    .fill(isBase ? AppTheme.primaryLight : AppTheme.bg)
                    .frame(width: 46, height: 46)
                if let tc = tc {
                    CurrencyFlagView(tc: tc, size: 30)
                } else {
                    Text(code).font(.caption2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tc?.name ?? code)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                Text(code)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text(displayValue)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(isBase ? AppTheme.primary : AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isBase ? AppTheme.primaryLight.opacity(0.55) : AppTheme.surface)
                .shadow(color: Color.black.opacity(isBase ? 0.07 : 0.03), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isBase ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Number Pad

struct ConverterNumpad: View {
    @Binding var text: String

    private let rows: [[String]] = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["C",".","0","⌫"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button { handleKey(key) } label: {
                            Text(key)
                                .font(.system(size: key == "C" ? 18 : 22,
                                              weight: key == "C" ? .bold : .medium,
                                              design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            key == "C"  ? Color.orange.opacity(0.15) :
                                            key == "⌫" ? Color(hex: "FF3B30").opacity(0.1) :
                                                          AppTheme.surface
                                        )
                                        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
                                )
                                .foregroundColor(
                                    key == "C"  ? .orange :
                                    key == "⌫" ? Color(hex: "FF3B30") :
                                                  AppTheme.textPrimary
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        switch key {
        case "C":
            text = ""
        case "⌫":
            guard !text.isEmpty else { return }
            text.removeLast()
        case ".":
            guard !text.contains(".") else { return }
            text = text.isEmpty ? "0." : text + "."
        default:
            if text == "0" { text = key }
            else {
                let parts = text.split(separator: ".", maxSplits: 1)
                if parts.count == 2, parts[1].count >= 4 { return }
                if text.count < 12 { text += key }
            }
        }
    }
}

// MARK: - Manage Currencies Sheet（支援排序）

struct ManageCurrenciesSheet: View {
    @Binding var savedCurrencies: String
    let baseCurrency: String
    @Environment(\.dismiss) var dismiss

    // 目前選中的有序清單
    @State private var selectedOrder: [String] = []

    private var unselectedCurrencies: [TravelCurrency] {
        TravelCurrency.all.filter { !selectedOrder.contains($0.code) }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── 已選擇（可拖動排序）──────────────────────────
                Section {
                    ForEach(selectedOrder, id: \.self) { code in
                        if let tc = TravelCurrency.find(code) {
                            currencyRowSelected(tc: tc)
                        }
                    }
                    .onMove { from, to in
                        selectedOrder.move(fromOffsets: from, toOffset: to)
                        persist()
                    }
                } header: {
                    Text("顯示中（拖動 ≡ 調整順序）")
                } footer: {
                    Text("至少保留 2 個幣別")
                }

                // ── 更多幣別 ──────────────────────────────────────
                if !unselectedCurrencies.isEmpty {
                    Section("新增幣別") {
                        ForEach(unselectedCurrencies) { tc in
                            Button { addCurrency(tc.code) } label: {
                                currencyRowUnselected(tc: tc)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("管理幣別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .onAppear {
            selectedOrder = savedCurrencies
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        }
    }

    // ── 已選列 ─────────────────────────────────────────────────
    @ViewBuilder
    private func currencyRowSelected(tc: TravelCurrency) -> some View {
        HStack(spacing: 14) {
            CurrencyFlagView(tc: tc, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tc.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                    if tc.code == baseCurrency {
                        Text("基準")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.primary).clipShape(Capsule())
                    }
                }
                Text(tc.code)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        // 左滑移除（基準幣別不可刪）
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if tc.code != baseCurrency {
                Button(role: .destructive) { removeCurrency(tc.code) } label: {
                    Label("移除", systemImage: "minus.circle")
                }
            }
        }
    }

    // ── 未選列 ─────────────────────────────────────────────────
    @ViewBuilder
    private func currencyRowUnselected(tc: TravelCurrency) -> some View {
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
            Image(systemName: "plus.circle.fill")
                .foregroundColor(AppTheme.primary)
                .font(.title3)
        }
        .contentShape(Rectangle())
    }

    // ── helpers ────────────────────────────────────────────────
    private func addCurrency(_ code: String) {
        guard !selectedOrder.contains(code) else { return }
        selectedOrder.append(code)
        persist()
    }

    private func removeCurrency(_ code: String) {
        guard selectedOrder.count > 2 else { return }
        selectedOrder.removeAll { $0 == code }
        persist()
    }

    private func persist() {
        savedCurrencies = selectedOrder.joined(separator: ",")
    }
}
