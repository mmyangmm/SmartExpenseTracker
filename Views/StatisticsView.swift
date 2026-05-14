import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @State private var chartType: ChartType = .pie

    enum ChartType: String, CaseIterable {
        case pie  = "圓餅圖"
        case line = "折線圖"
        case bar  = "長條圖"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MonthNavBar()
                        .padding(.horizontal)
                    TotalSummaryCard()
                        .padding(.horizontal)
                    Picker("圖表類型", selection: $chartType) {
                        ForEach(ChartType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    Group {
                        switch chartType {
                        case .pie:  PieChartCard()
                        case .line: LineChartCard()
                        case .bar:  BarChartCard()
                        }
                    }
                    .padding(.horizontal)
                    CategoryBreakdownList()
                        .padding(.horizontal)
                }
                .padding(.top)
                .padding(.bottom, 40)
            }
            .background(AppTheme.bg)
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Month Nav Bar

struct MonthNavBar: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    private var label: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        f.locale = Locale(identifier: "zh_TW")
        return f.string(from: viewModel.selectedMonth)
    }

    var body: some View {
        HStack {
            Button { viewModel.changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.pink)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.pinkLight)
                    .clipShape(Circle())
            }
            Spacer()
            Text(label)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Button { viewModel.changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.pink)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.pinkLight)
                    .clipShape(Circle())
            }
            .disabled(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month))
            .opacity(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
        }
    }
}

// MARK: - Total Summary Card

struct TotalSummaryCard: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var changeLabel: String {
        let prev = viewModel.previousMonthTotal()
        guard prev > 0 else { return "" }
        let diff = viewModel.currentMonthTotal - prev
        let pct  = abs(diff) / prev * 100
        return String(format: "%@ %.1f%%", diff >= 0 ? "▲" : "▼", pct)
    }
    var changeColor: Color {
        viewModel.currentMonthTotal >= viewModel.previousMonthTotal() ? .red : AppTheme.mint
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("本月支出")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("NT$\(Int(viewModel.currentMonthTotal))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                if !changeLabel.isEmpty {
                    Text(changeLabel).font(.caption).foregroundColor(changeColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("筆數")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(viewModel.currentMonthExpenses.count) 筆")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                let avg = viewModel.currentMonthExpenses.isEmpty ? 0.0
                          : viewModel.currentMonthTotal / Double(viewModel.currentMonthExpenses.count)
                Text("平均 NT$\(Int(avg))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding()
        .cuteCard()
    }
}

// MARK: - Pie Chart

struct PieChartCard: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var data: [(category: ExpenseCategory, amount: Double)] {
        ExpenseCategory.allCases
            .map { (category: $0, amount: viewModel.total(for: $0)) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出分佈")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            if data.isEmpty {
                statsEmptyState
            } else {
                Chart(data, id: \.category) { item in
                    SectorMark(
                        angle: .value("金額", item.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.category.color)
                    .annotation(position: .overlay) {
                        if viewModel.percentage(for: item.category) > 0.07 {
                            Text(String(format: "%.0f%%", viewModel.percentage(for: item.category) * 100))
                                .font(.caption2).fontWeight(.bold).foregroundColor(.white)
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .center, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
                        ForEach(data, id: \.category) { item in
                            HStack(spacing: 6) {
                                Circle().fill(item.category.color).frame(width: 8, height: 8)
                                Text("\(item.category.emoji) \(item.category.rawValue)")
                                    .font(.caption).foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("NT$\(Int(item.amount))")
                                    .font(.caption).fontWeight(.medium).foregroundColor(AppTheme.textPrimary)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .cuteCard()
    }
}

// MARK: - Line Chart

struct LineChartCard: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日花費趨勢")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            let daily = viewModel.dailyTotals()
            if daily.isEmpty {
                statsEmptyState
            } else {
                Chart(daily, id: \.date) { point in
                    LineMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("金額", point.amount)
                    )
                    .foregroundStyle(AppTheme.pink)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("金額", point.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.pink.opacity(0.25), AppTheme.pink.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("金額", point.amount)
                    )
                    .foregroundStyle(AppTheme.pink)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, daily.count / 5))) { v in
                        if let date = v.as(Date.self) {
                            AxisValueLabel {
                                Text(dayLabel(date)).font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        if let amount = v.as(Double.self) {
                            AxisValueLabel { Text("NT$\(Int(amount))").font(.caption2) }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .cuteCard()
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d日"; return f.string(from: date)
    }
}

// MARK: - Bar Chart

struct BarChartCard: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var data: [(category: ExpenseCategory, amount: Double)] {
        ExpenseCategory.allCases
            .map { (category: $0, amount: viewModel.total(for: $0)) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分類比較")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            if data.isEmpty {
                statsEmptyState
            } else {
                Chart(data, id: \.category) { item in
                    BarMark(
                        x: .value("分類", item.category.rawValue),
                        y: .value("金額", item.amount)
                    )
                    .foregroundStyle(item.category.color)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text("NT$\(Int(item.amount))")
                            .font(.caption2).foregroundColor(AppTheme.textSecondary)
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .cuteCard()
    }
}

// MARK: - Category Breakdown List

struct CategoryBreakdownList: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var sortedCategories: [ExpenseCategory] {
        ExpenseCategory.allCases
            .filter { viewModel.total(for: $0) > 0 }
            .sorted { viewModel.total(for: $0) > viewModel.total(for: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分類明細")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
            if sortedCategories.isEmpty {
                statsEmptyState.frame(maxWidth: .infinity)
            } else {
                ForEach(sortedCategories) { cat in
                    CategoryBreakdownRow(
                        category: cat,
                        amount:   viewModel.total(for: cat),
                        pct:      viewModel.percentage(for: cat),
                        count:    viewModel.currentMonthExpenses.filter { $0.category == cat }.count
                    )
                }
            }
        }
        .padding()
        .cuteCard()
    }
}

struct CategoryBreakdownRow: View {
    let category: ExpenseCategory
    let amount:   Double
    let pct:      Double
    let count:    Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(category.emoji).font(.title3)
                Text(category.rawValue)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NT$\(Int(amount))")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(count) 筆  \(String(format: "%.1f%%", pct * 100))")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.border).frame(height: 6)
                    Capsule()
                        .fill(category.color)
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shared empty state

private var statsEmptyState: some View {
    VStack(spacing: 10) {
        Text("📊").font(.system(size: 44))
        Text("本月尚無資料")
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
    }
    .padding(.vertical, 30)
    .frame(maxWidth: .infinity)
}
