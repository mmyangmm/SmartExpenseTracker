import SwiftUI

// MARK: - Currency Converter View

struct CurrencyConverterView: View {
    @EnvironmentObject var exchangeRateService: ExchangeRateService

    /// 顯示中的幣別（逗號分隔），預設 TWD/USD/JPY/EUR/CNY/HKD
    @AppStorage("converterCurrencies")   private var savedCurrencies: String = "TWD,USD,JPY,EUR,CNY,HKD"
    /// 目前作為基準的幣別
    @AppStorage("converterBaseCurrency") private var baseCurrency:    String = "TWD"

    @State private var inputText:   String = "1"
    @State private var showManage:  Bool   = false

    // ── helpers ──────────────────────────────────────────────
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

    // ── view ─────────────────────────────────────────────────
    var body: some View {
        VStack(spacing: 0) {

            // 更新時間 / loading 提示
            updateBar

            Divider().opacity(0.4)

            // 幣別清單
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

            // 數字鍵盤
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
                    // 重新整理
                    Button {
                        Task { await exchangeRateService.fetchAllRates(base: baseCurrency) }
                    } label: {
                        Image(systemName: exchangeRateService.isLoading
                              ? "arrow.clockwise" : "arrow.clockwise")
                            .rotationEffect(exchangeRateService.isLoading ? .degrees(360) : .zero)
                            .animation(exchangeRateService.isLoading
                                       ? .linear(duration: 1).repeatForever(autoreverses: false)
                                       : .default, value: exchangeRateService.isLoading)
                    }
                    // 管理幣別
                    Button { showManage = true } label: {
                        Image(systemName: "plus")
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
            // 初次進入或 base 已變更，才重新抓
            if exchangeRateService.allRates.isEmpty
                || exchangeRateService.converterBase != baseCurrency {
                await exchangeRateService.fetchAllRates(base: baseCurrency)
            }
        }
    }

    // ── 頂端更新列 ────────────────────────────────────────────
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
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("更新於 \(RelativeDateTimeFormatter().localizedString(for: ts, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                if let err = exchangeRateService.errorMessage {
                    Text("（\(err)）")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .padding(.horizontal, 16)
        .background(AppTheme.surface)
    }

    // ── 切換基準幣別 ──────────────────────────────────────────
    private func switchBase(to code: String) {
        guard code != baseCurrency else { return }
        let converted = convertedAmount(for: code)
        baseCurrency  = code
        // 格式化成輸入字串
        if converted <= 0 {
            inputText = "1"
        } else if converted.truncatingRemainder(dividingBy: 1) == 0 {
            inputText = "\(Int(converted))"
        } else {
            // 最多保留 4 位小數，去除尾零
            var s = String(format: "%.4f", converted)
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
            inputText = s
        }
        Task { await exchangeRateService.fetchAllRates(base: code) }
    }
}

// MARK: - Currency Row

struct ConverterCurrencyRow: View {
    let code:         String
    let isBase:       Bool
    let displayValue: String

    private var tc: TravelCurrency? { TravelCurrency.find(code) }

    var body: some View {
        HStack(spacing: 14) {
            // 國旗圓形
            ZStack {
                Circle()
                    .fill(isBase ? AppTheme.primaryLight : AppTheme.bg)
                    .frame(width: 46, height: 46)
                Text(tc?.flag ?? "🏳️").font(.title3)
            }

            // 名稱 + 代碼
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

            // 金額
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
                .fill(isBase
                      ? AppTheme.primaryLight.opacity(0.55)
                      : AppTheme.surface)
                .shadow(color: Color.black.opacity(isBase ? 0.07 : 0.03),
                        radius: 4, y: 2)
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
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button { handleKey(key) } label: {
                            Text(key)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(key == "⌫"
                                              ? Color(hex: "FF3B30").opacity(0.1)
                                              : AppTheme.surface)
                                        .shadow(color: Color.black.opacity(0.04),
                                                radius: 3, y: 1)
                                )
                                .foregroundColor(
                                    key == "⌫" ? Color(hex: "FF3B30") : AppTheme.textPrimary
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
        case "⌫":
            guard !text.isEmpty else { return }
            text.removeLast()
            if text.isEmpty { text = "" }

        case ".":
            guard !text.contains(".") else { return }
            text = text.isEmpty ? "0." : text + "."

        default:  // 數字
            if text == "0" {
                text = key
            } else {
                // 小數點後最多 4 位；整體最多 12 字元
                let parts = text.split(separator: ".", maxSplits: 1)
                if parts.count == 2, parts[1].count >= 4 { return }
                if text.count < 12 { text += key }
            }
        }
    }
}

// MARK: - Manage Currencies Sheet

struct ManageCurrenciesSheet: View {
    @Binding var savedCurrencies: String
    let baseCurrency: String
    @Environment(\.dismiss) var dismiss

    private var selectedCodes: [String] {
        savedCurrencies.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List(TravelCurrency.all) { tc in
                let isSelected = selectedCodes.contains(tc.code)
                let isBase     = tc.code == baseCurrency

                Button { toggle(tc.code) } label: {
                    HStack(spacing: 14) {
                        Text(tc.flag).font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(tc.name)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.textPrimary)
                                if isBase {
                                    Text("基準")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.primary)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(tc.code)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? AppTheme.primary
                                             : AppTheme.textSecondary.opacity(0.35))
                            .font(.title3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBase)   // 基準幣別不可移除
            }
            .navigationTitle("管理顯示幣別")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
    }

    private func toggle(_ code: String) {
        var codes = selectedCodes
        if codes.contains(code) {
            guard codes.count > 2 else { return }   // 至少保留 2 個
            codes.removeAll { $0 == code }
        } else {
            codes.append(code)
        }
        savedCurrencies = codes.joined(separator: ",")
    }
}
