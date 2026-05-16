import Foundation

// MARK: - PrizeTier

enum PrizeTier: String, Codable, CaseIterable {
    case special        = "special"
    case grand          = "grand"
    case first          = "first"
    case second         = "second"
    case third          = "third"
    case fourth         = "fourth"
    case fifth          = "fifth"
    case sixth          = "sixth"
    case additional     = "additional"

    var prizeAmount: Int {
        switch self {
        case .special:    return 10_000_000
        case .grand:      return 2_000_000
        case .first:      return 200_000
        case .second:     return 40_000
        case .third:      return 10_000
        case .fourth:     return 4_000
        case .fifth:      return 1_000
        case .sixth:      return 200
        case .additional: return 200
        }
    }

    var emoji: String {
        switch self {
        case .special:    return "🏆"
        case .grand:      return "🥇"
        case .first:      return "🎉"
        case .second:     return "🎊"
        case .third:      return "🎁"
        case .fourth:     return "✨"
        case .fifth:      return "🌟"
        case .sixth:      return "⭐"
        case .additional: return "🎵"
        }
    }

    var displayName: String {
        switch self {
        case .special:    return "特別獎"
        case .grand:      return "特獎"
        case .first:      return "頭獎"
        case .second:     return "二獎"
        case .third:      return "三獎"
        case .fourth:     return "四獎"
        case .fifth:      return "五獎"
        case .sixth:      return "六獎"
        case .additional: return "增開六獎"
        }
    }

    var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: prizeAmount)) ?? "\(prizeAmount)"
        return "NT$ \(formatted)"
    }
}

// MARK: - LotteryResult

enum LotteryResult: Equatable {
    case pending
    case notWon
    case won(PrizeTier)

    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }

    var hasWon: Bool {
        if case .won = self { return true }
        return false
    }
}

extension LotteryResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case prize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pending":
            self = .pending
        case "notWon":
            self = .notWon
        case "won":
            let prize = try container.decode(PrizeTier.self, forKey: .prize)
            self = .won(prize)
        default:
            self = .pending
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pending:
            try container.encode("pending", forKey: .type)
        case .notWon:
            try container.encode("notWon", forKey: .type)
        case .won(let prize):
            try container.encode("won", forKey: .type)
            try container.encode(prize, forKey: .prize)
        }
    }
}

// MARK: - InvoiceItem

struct InvoiceItem: Codable, Identifiable {
    var id: String
    var name: String
    var amount: Double

    init(id: String = UUID().uuidString, name: String, amount: Double) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}

// MARK: - InvoiceSource

enum InvoiceSource: String, Codable {
    case qrCode  = "QR碼"
    case ocr     = "掃描"
    case manual  = "手動"
}

// MARK: - LotteryNumbers

struct LotteryNumbers: Codable, Equatable {
    var special: String
    var grand: String
    var firstPrize: [String]
    var sixthAdditional: [String]
    var fetchedAt: Date

    init(special: String, grand: String, firstPrize: [String], sixthAdditional: [String], fetchedAt: Date = Date()) {
        self.special = special
        self.grand = grand
        self.firstPrize = firstPrize
        self.sixthAdditional = sixthAdditional
        self.fetchedAt = fetchedAt
    }
}

// MARK: - InvoicePeriod

struct InvoicePeriod: Codable, Identifiable, Equatable, Hashable {
    var id: String         // e.g. "11501" (ROC year + 01/03/05/07/09/11)
    var displayName: String  // e.g. "115年1-2月"
    var drawDate: Date
    var numbers: LotteryNumbers?

    var hasDrawn: Bool {
        drawDate < Date()
    }

    static func forDate(_ date: Date) -> InvoicePeriod {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 2024
        let month = comps.month ?? 1

        // Taiwan ROC year
        let rocYear = year - 1911

        // Determine 2-month period (1=Jan-Feb, 2=Mar-Apr, 3=May-Jun, 4=Jul-Aug, 5=Sep-Oct, 6=Nov-Dec)
        let periodIndex = (month - 1) / 2  // 0-5
        let startMonth = periodIndex * 2 + 1
        let endMonth = startMonth + 1

        // Period ID: ROC year + 2-digit period start month (zero-padded)
        let periodId = String(format: "%d%02d", rocYear, startMonth)

        // Display name
        let displayName = "\(rocYear)年\(startMonth)-\(endMonth)月"

        // Draw date: draw is on the 25th of the month 2 months after period end
        // Jan-Feb → Mar 25, Mar-Apr → May 25, May-Jun → Jul 25
        // Jul-Aug → Sep 25, Sep-Oct → Nov 25, Nov-Dec → Jan 25 (next year)
        let drawMonth = endMonth + 1
        var drawYear = year
        if drawMonth > 12 {
            drawYear += 1
        }
        let actualDrawMonth = drawMonth > 12 ? drawMonth - 12 : drawMonth

        var drawComps = DateComponents()
        drawComps.year = drawYear
        drawComps.month = actualDrawMonth
        drawComps.day = 25
        drawComps.hour = 9
        drawComps.minute = 0
        drawComps.second = 0
        let drawDate = cal.date(from: drawComps) ?? date

        return InvoicePeriod(id: periodId, displayName: displayName, drawDate: drawDate, numbers: nil)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Invoice

struct Invoice: Codable, Identifiable {
    var id: String
    var invoiceNumber: String    // uppercase, no dash, e.g. "AB12345678"
    var date: Date
    var sellerName: String
    var sellerTaxID: String
    var amount: Double
    var items: [InvoiceItem]
    var period: InvoicePeriod
    var lotteryResult: LotteryResult
    var source: InvoiceSource
    var note: String

    // MARK: Computed

    /// Last 8 characters (digits only)
    var numberDigits: String {
        if invoiceNumber.count >= 10 {
            return String(invoiceNumber.suffix(8))
        }
        return String(invoiceNumber.suffix(invoiceNumber.count))
    }

    /// Formatted as "XX-XXXXXXXX"
    var formattedNumber: String {
        let n = invoiceNumber.uppercased()
        guard n.count == 10 else { return n }
        let prefix = String(n.prefix(2))
        let digits = String(n.suffix(8))
        return "\(prefix)-\(digits)"
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_TW")
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    var formattedAmount: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        let s = fmt.string(from: NSNumber(value: Int(amount))) ?? "\(Int(amount))"
        return "NT$ \(s)"
    }

    // MARK: Init

    init(
        id: String = Date().timeIntervalSince1970.description,
        invoiceNumber: String,
        date: Date = Date(),
        sellerName: String = "",
        sellerTaxID: String = "",
        amount: Double = 0,
        items: [InvoiceItem] = [],
        lotteryResult: LotteryResult = .pending,
        source: InvoiceSource = .manual,
        note: String = ""
    ) {
        self.id = id
        // Normalize: uppercase, remove dashes
        self.invoiceNumber = invoiceNumber.uppercased().replacingOccurrences(of: "-", with: "")
        self.date = date
        self.sellerName = sellerName
        self.sellerTaxID = sellerTaxID
        self.amount = amount
        self.items = items
        self.period = InvoicePeriod.forDate(date)
        self.lotteryResult = lotteryResult
        self.source = source
        self.note = note
    }
}
