import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @State private var selectedExpense: Expense? = nil

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MonthSummaryCard()
                        .padding(.horizontal)
                    CategorySummaryRow()
                        .padding(.horizontal)
                    RecentExpensesList(selectedExpense: $selectedExpense)
                        .padding(.horizontal)
                }
                .padding(.top)
                .padding(.bottom, 120)
            }
            .background(AppTheme.bg)
            // ── 左右滑切換月份 ─────────────────────────────
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let h = value.translation.width
                        let v = value.translation.height
                        guard abs(h) > abs(v) else { return }  // 確保是水平滑動
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if h > 0 {
                                viewModel.changeMonth(by: -1)  // 右滑 → 上個月
                            } else if !isCurrentMonth {
                                viewModel.changeMonth(by: 1)   // 左滑 → 下個月
                            }
                        }
                    }
            )
            .navigationTitle("i 記帳")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSyncing {
                        ProgressView().scaleEffect(0.8).tint(AppTheme.primary)
                    }
                }
            }
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseDetailView(expense: expense)
        }
    }
}

// MARK: - Month Summary Card

struct MonthSummaryCard: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    private var monthText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        f.locale = Locale(identifier: "zh_TW")
        return f.string(from: viewModel.selectedMonth)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { withAnimation(.spring(response: 0.35)) { viewModel.changeMonth(by: -1) } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.primaryLight)
                        .clipShape(Circle())
                }
                Spacer()
                // 月份標題 + 回到本月按鈕
                VStack(spacing: 4) {
                    Text(monthText)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textSecondary)
                    if !isCurrentMonth {
                        Button {
                            withAnimation(.spring(response: 0.35)) { viewModel.goToCurrentMonth() }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("回到本月")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.primaryLight)
                            .clipShape(Capsule())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                Spacer()
                Button { withAnimation(.spring(response: 0.35)) { viewModel.changeMonth(by: 1) } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.primaryLight)
                        .clipShape(Circle())
                }
                .disabled(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month))
                .opacity(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
            }

            // ── 支出 / 收入 ─────────────────────────────────────
            HStack(spacing: 0) {
                // 支出
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "FF6B6B")).frame(width: 8, height: 8)
                        Text("支出")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Text(formatAmount(viewModel.currentMonthExpenseTotal))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 44)

                // 收入
                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "34C759")).frame(width: 8, height: 8)
                        Text("收入")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Text(formatAmount(viewModel.currentMonthIncomeTotal))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "34C759"))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // ── 消費比較 ─────────────────────────────────────────
            ConsumptionComparisonBar(
                current: viewModel.currentMonthExpenseTotal,
                average: viewModel.sixMonthAverageExpense()
            )
        }
        .padding(20)
        .cuteCard()
    }

    private func formatAmount(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "NT$"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "NT$\(Int(v))"
    }
}

// MARK: - Consumption Comparison Bar

struct ConsumptionComparisonBar: View {
    let current: Double
    let average: Double

    private var hasHistory: Bool { average > 0 }
    private var isOverBudget: Bool { hasHistory && current > average }
    private var barColor: Color { isOverBudget ? Color(hex: "FF3B30") : AppTheme.primary }

    /// current / average ratio, capped at 1 for the bar width
    private var fillRatio: Double {
        guard average > 0 else { return current > 0 ? 1.0 : 0.0 }
        return min(current / average, 1.0)
    }

    private var pctText: String {
        guard average > 0 else { return "" }
        return String(format: " (%.0f%%)", current / average * 100)
    }

    private func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "NT$"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "NT$\(Int(v))"
    }

    var body: some View {
        VStack(spacing: 8) {
            // 標題列
            HStack {
                Text("本月消費")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                if hasHistory {
                    Text("6個月平均")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            // 進度條
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 底色（代表 6 個月平均 = 100%）
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AppTheme.border)
                        .frame(height: 9)

                    // 本月消費填色
                    RoundedRectangle(cornerRadius: 5)
                        .fill(barColor)
                        .frame(width: max(geo.size.width * fillRatio, 4), height: 9)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fillRatio)
                }
            }
            .frame(height: 9)

            // 金額列
            HStack {
                // 本月金額 + 百分比
                HStack(spacing: 0) {
                    Text(fmt(current))
                        .fontWeight(.semibold)
                    Text(pctText)
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(isOverBudget ? Color(hex: "FF3B30") : AppTheme.textPrimary)

                Spacer()

                if hasHistory {
                    Text(fmt(average))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Category Summary Row

struct CategorySummaryRow: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var usedCategories: [ExpenseCategory] {
        ExpenseCategory.allCases.filter { !$0.isIncomeCategory && viewModel.total(for: $0) > 0 }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(usedCategories) { cat in
                    CategoryChip(
                        category: cat,
                        amount:   viewModel.total(for: cat),
                        pct:      viewModel.percentage(for: cat)
                    )
                }
            }
        }
    }
}

struct CategoryChip: View {
    let category: ExpenseCategory
    let amount:   Double
    let pct:      Double

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(category.emoji)
                    .font(.title3)
            }
            Text(category.rawValue)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
            Text("NT$\(Int(amount))")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .cuteRow()
    }
}

// MARK: - Recent Expenses List

struct RecentExpensesList: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Binding var selectedExpense: Expense?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近記錄")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 4)

            if viewModel.currentMonthExpenses.isEmpty {
                EmptyStateView()
            } else {
                ForEach(viewModel.currentMonthExpenses) { expense in
                    ExpenseRow(expense: expense)
                        .onTapGesture { selectedExpense = expense }
                }
            }
        }
    }
}

struct ExpenseRow: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    let expense: Expense

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(expense.category.emoji)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.note.isEmpty ? expense.category.rawValue : expense.note)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(expense.formattedDate)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            Text((expense.isIncome ? "+" : "") + expense.formattedAmount)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(expense.isIncome ? Color(hex: "34C759") : AppTheme.textPrimary)
        }
        .padding(14)
        .cuteRow()
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.delete(expense)
            } label: {
                Label("刪除", systemImage: "trash")
            }
            .tint(AppTheme.pink)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("💸")
                .font(.system(size: 56))
            Text("本月還沒有記錄")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textSecondary)
            Text("點下方「記帳」開始記帳吧！")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

// MARK: - Expense Detail

struct ExpenseDetailView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Environment(\.dismiss) var dismiss
    let expense: Expense
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(expense.category.color.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Text(expense.category.emoji)
                                    .font(.system(size: 40))
                            }
                            // 收入顯示綠色，支出顯示主題色
                            Text((expense.isIncome ? "+" : "") + expense.formattedAmount)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(expense.isIncome ? Color(hex: "34C759") : AppTheme.textPrimary)
                            // 類型標籤
                            Text(expense.isIncome ? "收入" : "支出")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(expense.isIncome ? Color(hex: "34C759") : AppTheme.primary)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding()
                }
                .listRowBackground(expense.category.color.opacity(0.08))

                Section("詳細資訊") {
                    LabeledContent("分類", value: "\(expense.category.emoji) \(expense.category.rawValue)")
                    LabeledContent("備註", value: expense.note.isEmpty ? "—" : expense.note)
                    LabeledContent("日期", value: expense.formattedDate)
                }

                if let imgData = expense.receiptImageData,
                   let uiImage = UIImage(data: imgData) {
                    Section("收據") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("刪除此筆記錄", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("記錄詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") { dismiss() }.foregroundColor(AppTheme.pink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("編輯") { showEdit = true }.foregroundColor(AppTheme.pink)
                }
            }
            .confirmationDialog("確認刪除", isPresented: $showDeleteConfirm) {
                Button("刪除", role: .destructive) {
                    viewModel.delete(expense)
                    dismiss()
                }
            }
            .sheet(isPresented: $showEdit) {
                QuickAddView(isPresented: $showEdit, existingExpense: expense)
            }
        }
    }
}
