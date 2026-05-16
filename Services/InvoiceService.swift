import Foundation
import Combine
import UserNotifications

@MainActor
class InvoiceService: ObservableObject {

    @Published var invoices: [Invoice] = []
    @Published var isFetching: Bool = false
    @Published var fetchError: String? = nil

    private let udKey = "invoices_v1"

    // MARK: - Persistence

    func load() {
        guard let data = UserDefaults.standard.data(forKey: udKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        if let decoded = try? decoder.decode([Invoice].self, from: data) {
            invoices = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(invoices) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }

    // MARK: - CRUD

    func add(_ invoice: Invoice) {
        // Deduplicate by invoiceNumber
        invoices.removeAll { $0.invoiceNumber == invoice.invoiceNumber }
        invoices.insert(invoice, at: 0)
        invoices.sort { $0.date > $1.date }
        save()
    }

    func delete(_ invoice: Invoice) {
        invoices.removeAll { $0.id == invoice.id }
        save()
    }

    func update(_ invoice: Invoice) {
        if let idx = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[idx] = invoice
            save()
        }
    }

    // MARK: - Grouping

    var groupedByPeriod: [(period: InvoicePeriod, invoices: [Invoice])] {
        var dict: [String: (period: InvoicePeriod, invoices: [Invoice])] = [:]
        for inv in invoices {
            let pid = inv.period.id
            if dict[pid] == nil {
                dict[pid] = (period: inv.period, invoices: [])
            }
            dict[pid]!.invoices.append(inv)
        }
        return dict.values
            .sorted { $0.period.id > $1.period.id }
            .map { (period: $0.period, invoices: $0.invoices) }
    }

    // MARK: - QR Code Parsing

    /// Parse Taiwan e-invoice left QR code.
    /// Format: INVOICENO:ROCDATE:AMTHEX:TAXHEX:BUYERID:SELLERID:RANDOM:...
    func parseQRCode(_ raw: String) -> Invoice? {
        let parts = raw.components(separatedBy: ":")
        guard parts.count >= 7 else { return nil }

        let invoiceNo = parts[0]
        // Validate: 2 uppercase letters + 8 digits
        let pattern = "^[A-Za-z]{2}\\d{8}$"
        guard invoiceNo.range(of: pattern, options: .regularExpression) != nil else { return nil }

        // ROC date: 7 chars, e.g. "1091231" = ROC109 Dec31 = 2020/12/31
        let rocDateStr = parts[1]
        let date: Date
        if rocDateStr.count == 7,
           let rocYear = Int(String(rocDateStr.prefix(3))),
           let month = Int(String(rocDateStr.dropFirst(3).prefix(2))),
           let day = Int(String(rocDateStr.suffix(2))) {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
            var comps = DateComponents()
            comps.year = rocYear + 1911
            comps.month = month
            comps.day = day
            date = cal.date(from: comps) ?? Date()
        } else {
            date = Date()
        }

        // Amount: may be hex or decimal
        let amtStr = parts[2]
        let taxStr = parts[3]
        let amt = parseIntHexOrDec(amtStr)
        let tax = parseIntHexOrDec(taxStr)
        let total = Double(amt + tax)

        let sellerTaxID = parts[5]

        return Invoice(
            invoiceNumber: invoiceNo,
            date: date,
            sellerName: "",
            sellerTaxID: sellerTaxID,
            amount: total,
            items: [],
            lotteryResult: .pending,
            source: .qrCode,
            note: ""
        )
    }

    private func parseIntHexOrDec(_ s: String) -> Int {
        // Try hex first if it contains non-numeric chars
        let upper = s.uppercased()
        let hexChars = CharacterSet(charactersIn: "0123456789ABCDEF")
        let alphas = upper.unicodeScalars.filter { !CharacterSet.decimalDigits.contains($0) }
        if !alphas.isEmpty {
            // Has letters, try hex
            if let v = Int(upper, radix: 16) { return v }
        }
        // Try decimal
        if let v = Int(s) { return v }
        // Try hex anyway
        if let v = Int(upper, radix: 16) { return v }
        return 0
    }

    // MARK: - OCR Invoice Number Extraction

    func extractInvoiceNumber(from text: String) -> String? {
        let pattern = "[A-Za-z]{2}[-\\s]?\\d{8}"
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(text[range])
        return match.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
    }

    // MARK: - Lottery Checking

    func checkLottery(for invoice: Invoice, numbers: LotteryNumbers) -> LotteryResult {
        let digits = invoice.numberDigits  // last 8 digits

        guard digits.count == 8 else { return .notWon }

        // Special prize: exact 8 digits
        if numbers.special.count == 8 && digits == numbers.special {
            return .won(.special)
        }

        // Grand prize: exact 8 digits
        if numbers.grand.count == 8 && digits == numbers.grand {
            return .won(.grand)
        }

        // First prize array
        for fp in numbers.firstPrize where fp.count == 8 {
            if digits == fp {
                return .won(.first)
            }
            if fp.count >= 7 && digits.hasSuffix(String(fp.suffix(7))) {
                return .won(.second)
            }
            if fp.count >= 6 && digits.hasSuffix(String(fp.suffix(6))) {
                return .won(.third)
            }
            if fp.count >= 5 && digits.hasSuffix(String(fp.suffix(5))) {
                return .won(.fourth)
            }
            if fp.count >= 4 && digits.hasSuffix(String(fp.suffix(4))) {
                return .won(.fifth)
            }
            if fp.count >= 3 && digits.hasSuffix(String(fp.suffix(3))) {
                return .won(.sixth)
            }
        }

        // Sixth additional: suffix 3
        for sa in numbers.sixthAdditional where sa.count == 3 {
            if digits.hasSuffix(sa) {
                return .won(.additional)
            }
        }

        return .notWon
    }

    // MARK: - Apply Lottery to Batch

    func applyLottery(numbers: LotteryNumbers, periodId: String) {
        for i in invoices.indices {
            guard invoices[i].period.id == periodId else { continue }
            let result = checkLottery(for: invoices[i], numbers: numbers)
            invoices[i].lotteryResult = result
            invoices[i].period.numbers = numbers
        }
        save()
    }

    // MARK: - Notifications

    func scheduleLotteryNotification(for period: InvoicePeriod, count: Int) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "統一發票開獎提醒"
        content.body = "\(period.displayName) 今天開獎！您有 \(count) 張發票待兌獎"
        content.sound = .default

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        var comps = cal.dateComponents([.year, .month, .day], from: period.drawDate)
        comps.hour = 9
        comps.minute = 0
        comps.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "invoice_lottery_\(period.id)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Counts

    func wonCount(in periodId: String) -> Int {
        invoices.filter { $0.period.id == periodId && $0.lotteryResult.hasWon }.count
    }

    func pendingCount(in periodId: String) -> Int {
        invoices.filter { $0.period.id == periodId && $0.lotteryResult.isPending }.count
    }
}
