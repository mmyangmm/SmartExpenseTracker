import Foundation
import SwiftUI
import Combine

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var selectedMonth: Date = Date()
    @Published var isSyncing: Bool = false
    @Published var syncError: String? = nil

    private let cloudKitService = CloudKitService()
    private let storageKey = "expenses_v1"

    init() {
        loadLocal()
        Task { await syncFromCloud() }
    }

    // MARK: - CRUD

    func add(_ expense: Expense) {
        expenses.insert(expense, at: 0)
        saveLocal()
        Task { await cloudKitService.save(expense) }
    }

    func delete(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveLocal()
        Task { await cloudKitService.delete(expense) }
    }

    func update(_ expense: Expense) {
        guard let idx = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[idx] = expense
        saveLocal()
        Task { await cloudKitService.save(expense) }
    }

    // MARK: - Derived Data

    var currentMonthExpenses: [Expense] {
        let cal = Calendar.current
        return expenses.filter {
            cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }.sorted { $0.date > $1.date }
    }

    var currentMonthTotal: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    func total(for category: ExpenseCategory) -> Double {
        currentMonthExpenses
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    func percentage(for category: ExpenseCategory) -> Double {
        guard currentMonthTotal > 0 else { return 0 }
        return total(for: category) / currentMonthTotal
    }

    /// 每日支出加總，用於折線圖
    func dailyTotals() -> [(date: Date, amount: Double)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: currentMonthExpenses) {
            cal.startOfDay(for: $0.date)
        }
        return grouped
            .map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date < $1.date }
    }

    /// 上個月同期比較
    func previousMonthTotal() -> Double {
        guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return 0 }
        let cal = Calendar.current
        return expenses
            .filter { cal.isDate($0.date, equalTo: prevMonth, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }

    func goToCurrentMonth() {
        selectedMonth = Date()
    }

    // MARK: - AI Category Inference

    func inferCategory(from text: String) -> ExpenseCategory {
        let lower = text.lowercased()
        for category in ExpenseCategory.allCases where category != .other {
            if category.keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return .other
    }

    /// 解析語音輸入，回傳金額、分類、備註（備註已去除金額部分）
    func parseVoiceInput(_ text: String) -> (amount: Double?, category: ExpenseCategory, note: String) {
        var amount: Double?
        var amountMatchRange: Range<String.Index>? = nil

        // 各種金額格式的 regex
        let patterns: [(pattern: String, group: Int)] = [
            (#"(\d+(?:\.\d+)?)\s*(?:元|塊|块|円)"#,          1),
            (#"(?:NT\$|NTD|TWD)\s*(\d+(?:\.\d+)?)"#,         1),
            (#"(?:\$|＄)\s*(\d+(?:\.\d+)?)"#,                1),
            (#"(\d+(?:\.\d+)?)\s*(?:dollar|dollars|USD)"#,   1),
        ]

        outer: for (pat, group) in patterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                let nsText = text as NSString
                let range = NSRange(location: 0, length: nsText.length)
                if let match = regex.firstMatch(in: text, range: range) {
                    let numRange = match.range(at: group)
                    if numRange.location != NSNotFound,
                       let swiftRange = Range(numRange, in: text) {
                        amount = Double(text[swiftRange])
                        if let fullRange = Range(match.range, in: text) {
                            amountMatchRange = fullRange
                        }
                        break outer
                    }
                }
            }
        }

        // 若無貨幣符號，嘗試單純數字
        if amount == nil {
            let numPat = #"(\d+(?:\.\d+)?)"#
            if let regex = try? NSRegularExpression(pattern: numPat),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let r = Range(match.range(at: 1), in: text) {
                amount = Double(text[r])
                amountMatchRange = r
            }
        }

        // 從原文移除金額部分，得到乾淨備註
        var cleanNote = text
        if let matchRange = amountMatchRange {
            cleanNote.removeSubrange(matchRange)
        }
        cleanNote = cleanNote
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        let category = inferCategory(from: text)
        return (amount, category, cleanNote)
    }

    // MARK: - Persistence

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadLocal() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let saved = try? JSONDecoder().decode([Expense].self, from: data)
        else { return }
        expenses = saved
    }

    private func syncFromCloud() async {
        isSyncing = true
        syncError = nil
        do {
            let cloudExpenses = try await cloudKitService.fetchAll()
            let localIDs = Set(expenses.map { $0.id })
            let newOnes = cloudExpenses.filter { !localIDs.contains($0.id) }
            expenses.append(contentsOf: newOnes)
            expenses.sort { $0.date > $1.date }
            saveLocal()
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    func manualSync() {
        Task { await syncFromCloud() }
    }
}
