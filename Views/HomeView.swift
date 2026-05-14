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
                        .background(AppTheme.pinkLight)
                        .clipShape(Circle())
                }
                .disabled(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month))
                .opacity(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
            }

            VStack(spacing: 4) {
                Text("本月支出")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text(formatAmount(viewModel.currentMonthTotal))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            let prevTotal = viewModel.previousMonthTotal()
            if prevTotal > 0 {
                let diff = viewModel.currentMonthTotal - prevTotal
                let pct  = abs(diff) / prevTotal * 100
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "較上月 %.1f%%", pct))
                        .font(.caption)
                }
                .foregroundColor(diff >= 0 ? .red.opacity(0.8) : AppTheme.mint)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background((diff >= 0 ? Color.red : AppTheme.mint).opacity(0.10))
                .clipShape(Capsule())
            }
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

// MARK: - Category Summary Row

struct CategorySummaryRow: View {
    @EnvironmentObject var viewModel: ExpenseViewModel

    var usedCategories: [ExpenseCategory] {
        ExpenseCategory.allCases.filter { viewModel.total(for: $0) > 0 }
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
            Text(expense.formattedAmount)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)
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
            Text("點下方 ＋ 開始記帳吧！")
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
                            Text(expense.formattedAmount)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
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
                            .cornerRadius(12)
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
