import Foundation
import Combine
import UserNotifications
import os.log

#if DEBUG
private let invLog = Logger(subsystem: "com.Felix.SmartExpenseTracker", category: "QRScan")
private func invDebug(_ msg: @autoclosure () -> String) {
    let text = msg()
    invLog.debug("\(text, privacy: .private)")
}
#else
private func invDebug(_ msg: @autoclosure () -> String) {}
#endif

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
        // Schedule draw-day notification for this period
        let count = pendingCount(in: invoice.period.id)
        if count > 0 {
            scheduleLotteryNotification(for: invoice.period, count: count)
        }
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
    /// Supports two formats:
    ///   Colon-separated: INVOICENO:ROCDATE:AMTHEX:TAXHEX:BUYERID:SELLERID:RANDOM:...
    ///   Fixed-width (no colons): [10 invoice][7 ROC date][4 random][8 hex sales][8 hex total][8 buyer ID][8 seller ID]...
    func parseQRCode(_ raw: String) -> Invoice? {
        invDebug("parseQRCode len=\(raw.count)")
        let parts = raw.components(separatedBy: ":")
        invDebug("parts.count=\(parts.count)")

        let invoiceNo: String
        let rocDateStr: String
        let amtStr: String
        let taxStr: String
        let sellerTaxID: String

        if parts.count >= 7 {
            // Colon-separated format
            invoiceNo = parts[0]
            let noPattern = "^[A-Za-z]{2}\\d{8}$"
            guard invoiceNo.range(of: noPattern, options: .regularExpression) != nil else {
                invDebug("colon format invoiceNo regex failed")
                return nil
            }
            rocDateStr  = parts[1]
            amtStr      = parts[2]
            taxStr      = parts[3]
            sellerTaxID = parts[5]
        } else if raw.count >= 53 {
            // Fixed-width format: validate header first
            let header = String(raw.prefix(10))
            let noPattern = "^[A-Za-z]{2}\\d{8}$"
            invDebug("fixed-width candidate")
            guard header.range(of: noPattern, options: .regularExpression) != nil else {
                invDebug("fixed-width header regex failed")
                return nil
            }
            let chars = Array(raw)
            invoiceNo   = header
            rocDateStr  = String(chars[10..<17])
            amtStr      = String(chars[21..<29])
            taxStr      = String(chars[29..<37])
            sellerTaxID = String(chars[45..<53])
            invDebug("fixed-width parsed date=\(rocDateStr)")
        } else {
            invDebug("no branch matched len=\(raw.count) parts=\(parts.count)")
            return nil
        }

        // ROC date: 7 chars, e.g. "1091231" = ROC109 Dec31 = 2020/12/31
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

        let amt = parseIntHexOrDec(amtStr)
        let tax = parseIntHexOrDec(taxStr)
        let total = Double(amt + tax)

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

    // MARK: - Right QR Code Parsing

    /// Parse Taiwan e-invoice right QR code.
    /// Format: **:encode:sellerName:buyerName:item1Name:item1Qty:item1UnitPrice:...
    /// Returns seller name and item list extracted from the right QR.
    func parseRightQRCode(_ raw: String) -> (sellerName: String, items: [InvoiceItem]) {
        guard raw.hasPrefix("**") else { return ("", []) }
        let parts = raw.components(separatedBy: ":")
        // parts[0] = "**", parts[1] = encode, parts[2] = sellerName, parts[3] = buyerName
        guard parts.count >= 3 else { return ("", []) }

        let sellerName = parts.count > 2 ? cleanText(parts[2]) : ""
        var items: [InvoiceItem] = []

        // Items start at index 4 (after **, encode, sellerName, buyerName)
        let itemStart = 4
        var i = itemStart
        while i + 2 < parts.count {
            let name = cleanText(parts[i])
            let qty  = Double(parts[i + 1]) ?? 1
            let unitPrice = Double(parts[i + 2]) ?? 0
            let amount = qty * unitPrice
            if !name.isEmpty {
                items.append(InvoiceItem(name: name, amount: amount))
            }
            i += 3
        }
        return (sellerName, items)
    }

    private func cleanText(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Returns the number of winning invoices found.
    @discardableResult
    func applyLottery(numbers: LotteryNumbers, periodId: String) -> Int {
        var winCount = 0
        for i in invoices.indices {
            guard invoices[i].period.id == periodId else { continue }
            let result = checkLottery(for: invoices[i], numbers: numbers)
            invoices[i].lotteryResult = result
            invoices[i].period.numbers = numbers
            if result.hasWon { winCount += 1 }
        }
        save()
        if winCount > 0 {
            scheduleWinNotification(count: winCount)
        }
        return winCount
    }

    private func scheduleWinNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 恭喜！發票中獎了！"
        content.body = "您有 \(count) 張發票中獎，快去查看吧！"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "invoice_win_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
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
