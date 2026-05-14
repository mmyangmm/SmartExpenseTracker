import SwiftUI

struct TravelModeSummaryView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Environment(\.dismiss) var dismiss

    let sessionId:    String
    let currencyCode: String

    private var tc: TravelCurrency? { TravelCurrency.find(currencyCode) }

    // ── 旅程所有支出（不含收入）────────────────────────────────
    private var items: [Expense] {
        viewModel.expenses.filter { $0.travelSessionId == sessionId && !$0.isIncome }
            .sorted { $0.date < $1.date }
    }
    private var allItems: [Expense] {
        viewModel.expenses.filter { $0.travelSessionId == sessionId }
            .sorted { $0.date < $1.date }
    }

    private var totalOriginal: Double {
        items.compactMap { $0.originalAmount }.reduce(0, +)
    }
    private var totalTWD: Double { items.reduce(0) { $0 + $1.amount } }

    private var dateRange: String {
        guard let first = items.first?.date, let last = items.last?.date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        f.locale = Locale(identifier: "zh_TW")
        if Calendar.current.isDate(first, inSameDayAs: last) { return f.string(from: first) }
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }
    private var dayCount: Int {
        guard let first = items.first?.date, let last = items.last?.date else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: first, to: last).day! + 1)
    }

    // ── 分類加總（支出）──────────────────────────────────────
    private var categoryTotals: [(category: ExpenseCategory, twd: Double, original: Double)] {
        let expCats = ExpenseCategory.allCases.filter { !$0.isIncomeCategory }
        return expCats.compactMap { cat in
            let catItems = items.filter { $0.category == cat }
            guard !catItems.isEmpty else { return nil }
            let twd  = catItems.reduce(0) { $0 + $1.amount }
            let orig = catItems.compactMap { $0.originalAmount }.reduce(0, +)
            return (cat, twd, orig)
        }.sorted { $0.twd > $1.twd }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Hero 總覽卡 ────────────────────────────
                    VStack(spacing: 14) {
                        Text("\(tc?.flag ?? "✈️")  旅程結算")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(dateRange)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)

                        Divider()

                        HStack(spacing: 0) {
                            // 外幣合計
                            VStack(spacing: 6) {
                                Text("總支出")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                                if let tc = tc, totalOriginal > 0 {
                                    Text(tc.format(totalOriginal))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                } else {
                                    Text("NT$0")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Rectangle().fill(AppTheme.border).frame(width: 1, height: 40)

                            // 台幣換算
                            VStack(spacing: 6) {
                                Text("換算台幣")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                                Text("NT$\(Int(totalTWD))")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        Divider()

                        HStack(spacing: 0) {
                            summaryStatCell(label: "天數", value: "\(dayCount) 天")
                            Rectangle().fill(AppTheme.border).frame(width: 1, height: 28)
                            summaryStatCell(label: "筆數", value: "\(items.count) 筆")
                            Rectangle().fill(AppTheme.border).frame(width: 1, height: 28)
                            summaryStatCell(
                                label: "日均消費",
                                value: tc != nil && totalOriginal > 0
                                    ? tc!.format(totalOriginal / Double(dayCount))
                                    : "—"
                            )
                        }
                    }
                    .padding(20)
                    .cuteCard()
                    .padding(.horizontal)

                    // ── 分類圓餅圖替代：橫條清單 ──────────────
                    if !categoryTotals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("消費分類")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 4)

                            ForEach(categoryTotals, id: \.category) { row in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(row.category.color.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Text(row.category.emoji).font(.body)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(row.category.rawValue)
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppTheme.textPrimary)
                                        // 進度條
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(AppTheme.border).frame(height: 5)
                                                let ratio = totalTWD > 0 ? row.twd / totalTWD : 0
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(row.category.color)
                                                    .frame(width: geo.size.width * ratio, height: 5)
                                            }
                                        }
                                        .frame(height: 5)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if let tc = tc, row.original > 0 {
                                            Text(tc.format(row.original))
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(.bold)
                                                .foregroundColor(AppTheme.textPrimary)
                                        }
                                        if totalTWD > 0 {
                                            Text(String(format: "%.0f%%", row.twd / totalTWD * 100))
                                                .font(.caption2)
                                                .foregroundColor(AppTheme.textSecondary)
                                        }
                                    }
                                }
                                .padding(12)
                                .cuteRow()
                            }
                        }
                        .padding(.horizontal)
                    }

                    // ── 明細清單 ──────────────────────────────
                    if !allItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("消費明細")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 4)

                            ForEach(allItems) { exp in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(exp.category.color.opacity(0.15))
                                            .frame(width: 38, height: 38)
                                        Text(exp.category.emoji).font(.callout)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exp.note.isEmpty ? exp.category.rawValue : exp.note)
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundColor(exp.isIncome ? Color(hex: "34C759") : AppTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(exp.formattedDate)
                                            .font(.caption)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text((exp.isIncome ? "+" : "") + exp.formattedAmount)
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(exp.isIncome ? Color(hex: "34C759") : AppTheme.textPrimary)
                                        Text(exp.formattedAmountTWD)
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                                .padding(12)
                                .cuteRow()
                            }
                        }
                        .padding(.horizontal)
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.top)
            }
            .background(AppTheme.bg)
            .navigationTitle("旅行結算 \(tc?.flag ?? "✈️")")
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

    @ViewBuilder
    private func summaryStatCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(AppTheme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
