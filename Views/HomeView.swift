import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @State private var selectedExpense: Expense? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 月份選擇器 + 總金額
                    MonthSummaryCard()
                        .padding(.horizontal)

                    // 分類快速列
                    CategorySummaryRow()
                        .padding(.horizontal)

                    // 最近記錄
                    RecentExpensesList(selectedExpense: $selectedExpense)
                        .padding(.horizontal)
                }
                .padding(.top)
                .padding(.bottom, 120) // 讓 FAB 不遮住最後一筆
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("智慧記帳")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSyncing {
                        ProgressView().scaleEffect(0.8)
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

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        f.locale = Locale(identifier: "zh_TW")
        return f
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { viewModel.changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundColor(.indigo.opacity(0.7))
                }
                Spacer()
                Text(monthFormatter.string(from: viewModel.selectedMonth))
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button { viewModel.changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.indigo.opacity(0.7))
                }
                .disabled(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month))
                .opacity(Calendar.current.isDate(viewModel.selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
            }

            Text(formatAmount(viewModel.currentMonthTotal))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            let prevTotal = viewModel.previousMonthTotal()
            if prevTotal > 0 {
                let diff = viewModel.currentMonthTotal - prevTotal
                let pct  = abs(diff) / prevTotal * 100
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "較上月 %.1f%%", pct))
                }
                .font(.caption)
                .foregroundColor(diff >= 0 ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
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
            HStack(spacing: 12) {
                ForEach(usedCategories) { cat in
                    CategoryChip(
                        category: cat,
                        amount: viewModel.total(for: cat),
                        pct: viewModel.percentage(for: cat)
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
                    .fill(category.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(category.emoji)
                    .font(.title3)
            }
            Text(category.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("NT$\(Int(amount))")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Recent Expenses List

struct RecentExpensesList: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @Binding var selectedExpense: Expense?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近記錄")
                .font(.headline)
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
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(expense.category.emoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? expense.category.rawValue : expense.note)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(expense.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(expense.formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.delete(expense)
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.5))
            Text("本月尚無記錄")
                .foregroundColor(.secondary)
                .font(.subheadline)
            Text("點下方＋按鈕開始記帳")
                .foregroundColor(.secondary.opacity(0.7))
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
                        VStack(spacing: 8) {
                            Text(expense.category.emoji)
                                .font(.system(size: 56))
                            Text(expense.formattedAmount)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        Spacer()
                    }
                    .padding()
                }
                .listRowBackground(expense.category.color.opacity(0.1))

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
                            .cornerRadius(8)
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
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("編輯") { showEdit = true }
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
