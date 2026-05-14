import Foundation
import SwiftUI
import CloudKit

// MARK: - Category

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    // ── 支出分類 ──────────────────────────────────────────────────
    case food          = "餐飲"
    case transport     = "交通"
    case shopping      = "購物"
    case entertainment = "娛樂"
    case medical       = "醫療"
    case home          = "居家"
    case other         = "其他"
    // ── 收入分類 ──────────────────────────────────────────────────
    case salary        = "薪資"
    case bonus         = "獎金"
    case partTime      = "兼職"
    case investment    = "投資"
    case incomeOther   = "其他收入"

    var id: String { rawValue }

    var isIncomeCategory: Bool {
        switch self {
        case .salary, .bonus, .partTime, .investment, .incomeOther: return true
        default: return false
        }
    }

    var emoji: String {
        switch self {
        case .food:          return "🍜"
        case .transport:     return "🚗"
        case .shopping:      return "🛍️"
        case .entertainment: return "🎮"
        case .medical:       return "💊"
        case .home:          return "🏠"
        case .other:         return "📦"
        case .salary:        return "💰"
        case .bonus:         return "🎁"
        case .partTime:      return "💼"
        case .investment:    return "📈"
        case .incomeOther:   return "💵"
        }
    }

    var color: Color {
        switch self {
        case .food:          return Color(hex: "FF6B6B")
        case .transport:     return Color(hex: "4ECDC4")
        case .shopping:      return Color(hex: "45B7D1")
        case .entertainment: return Color(hex: "96CEB4")
        case .medical:       return Color(hex: "FF9FF3")
        case .home:          return Color(hex: "FFEAA7")
        case .other:         return Color(hex: "B2BEC3")
        case .salary:        return Color(hex: "34C759")
        case .bonus:         return Color(hex: "30D158")
        case .partTime:      return Color(hex: "5AC8FA")
        case .investment:    return Color(hex: "AF52DE")
        case .incomeOther:   return Color(hex: "9ACD32")
        }
    }

    // 關鍵字對應，用於 AI 自動分類
    var keywords: [String] {
        switch self {
        case .food:
            return ["午餐","早餐","晚餐","飯","食","吃","咖啡","飲料","餐廳","便當",
                    "麵","超商","711","全家","早午餐","下午茶","甜點","奶茶","珍奶",
                    "燒烤","火鍋","pizza","漢堡","壽司","拉麵","小吃","夜市"]
        case .transport:
            return ["捷運","公車","計程車","uber","taxi","油費","停車","高鐵","火車",
                    "交通","加油","機票","台鐵","悠遊","YouBike","scooter","摩托"]
        case .shopping:
            return ["購物","買","衣服","鞋子","包包","3c","電腦","手機","服飾",
                    "momo","蝦皮","網購","amazon","ikea","百貨","超市","costco"]
        case .entertainment:
            return ["電影","遊戲","ktv","娛樂","netflix","旅遊","玩","音樂","書",
                    "展覽","concert","演唱會","劇場","桌遊","健身","gym","spa"]
        case .medical:
            return ["醫院","藥局","看病","醫療","診所","藥","健身","健檢","牙科",
                    "眼科","掛號","門診","保健","維他命","口罩"]
        case .home:
            return ["水電","房租","家具","裝潢","修繕","家居","清潔","居家",
                    "網路","瓦斯","保險","管理費","電費","水費"]
        case .other:
            return []
        case .salary:
            return ["薪水","薪資","月薪","工資","底薪","發薪","入帳","salary"]
        case .bonus:
            return ["獎金","年終","績效","紅包","禮金","bonus"]
        case .partTime:
            return ["兼職","打工","接案","freelance","外快","副業","稿費"]
        case .investment:
            return ["股票","股利","投資","基金","利息","配息","dividend","利潤","收益"]
        case .incomeOther:
            return []
        }
    }
}

// MARK: - Expense Model

struct Expense: Identifiable, Codable {
    var id: String
    var amount: Double
    var category: ExpenseCategory
    var note: String
    var date: Date
    var isIncome: Bool
    var receiptImageData: Data?
    var cloudKitRecordName: String?

    init(
        id: String = UUID().uuidString,
        amount: Double,
        category: ExpenseCategory,
        note: String = "",
        date: Date = Date(),
        isIncome: Bool = false,
        receiptImageData: Data? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.isIncome = isIncome
        self.receiptImageData = receiptImageData
    }

    // Backward-compatible decoding (old records have no isIncome field)
    enum CodingKeys: String, CodingKey {
        case id, amount, category, note, date, isIncome, receiptImageData, cloudKitRecordName
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self,           forKey: .id)
        amount           = try c.decode(Double.self,           forKey: .amount)
        category         = try c.decode(ExpenseCategory.self,  forKey: .category)
        note             = try c.decode(String.self,           forKey: .note)
        date             = try c.decode(Date.self,             forKey: .date)
        isIncome         = (try? c.decode(Bool.self,           forKey: .isIncome)) ?? false
        receiptImageData = try? c.decode(Data.self,            forKey: .receiptImageData)
        cloudKitRecordName = try? c.decode(String.self,        forKey: .cloudKitRecordName)
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.currencySymbol = "NT$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$\(Int(amount))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}

// MARK: - CloudKit Conversion

extension Expense {
    static nonisolated let ckRecordType = "Expense"

    nonisolated func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)
        record["amount"]   = amount as CKRecordValue
        record["category"] = category.rawValue as CKRecordValue
        record["note"]     = note as CKRecordValue
        record["date"]     = date as CKRecordValue
        record["isIncome"] = (isIncome ? 1 : 0) as CKRecordValue
        return record
    }

    nonisolated static func fromCKRecord(_ record: CKRecord) -> Expense? {
        guard
            let amount      = record["amount"] as? Double,
            let categoryRaw = record["category"] as? String,
            let category    = ExpenseCategory(rawValue: categoryRaw),
            let note        = record["note"] as? String,
            let date        = record["date"] as? Date
        else { return nil }

        let isIncome = (record["isIncome"] as? Int64 ?? 0) != 0
        var expense = Expense(
            id: record.recordID.recordName,
            amount: amount,
            category: category,
            note: note,
            date: date,
            isIncome: isIncome
        )
        expense.cloudKitRecordName = record.recordID.recordName
        return expense
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
