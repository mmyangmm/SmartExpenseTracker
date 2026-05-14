import Foundation

struct TravelCurrency: Identifiable, Hashable {
    let code:   String   // "JPY"
    let name:   String   // "日圓"
    let flag:   String   // "🇯🇵"
    let symbol: String   // "¥"

    var id: String { code }

    /// 格式化金額，日圓/韓元/越南盾/印尼盾不顯示小數
    func format(_ amount: Double) -> String {
        let noDecimal = ["JPY","KRW","VND","IDR","TWD"]
        let f = NumberFormatter()
        f.numberStyle           = .decimal
        f.maximumFractionDigits = noDecimal.contains(code) ? 0 : 2
        f.minimumFractionDigits = 0
        let num = f.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "\(symbol)\(num)"
    }

    // ── 常用旅遊幣別（含台幣） ─────────────────────────────────
    static let all: [TravelCurrency] = [
        .init(code: "TWD", name: "新台幣",       flag: "🇹🇼", symbol: "NT$"),
        .init(code: "JPY", name: "日圓",          flag: "🇯🇵", symbol: "¥"),
        .init(code: "USD", name: "美元",          flag: "🇺🇸", symbol: "$"),
        .init(code: "EUR", name: "歐元",          flag: "🇪🇺", symbol: "€"),
        .init(code: "GBP", name: "英鎊",          flag: "🇬🇧", symbol: "£"),
        .init(code: "HKD", name: "港幣",          flag: "🇭🇰", symbol: "HK$"),
        .init(code: "MOP", name: "澳門幣",        flag: "🇲🇴", symbol: "MOP$"),
        .init(code: "CNY", name: "人民幣",        flag: "🇨🇳", symbol: "¥"),
        .init(code: "KRW", name: "韓元",          flag: "🇰🇷", symbol: "₩"),
        .init(code: "SGD", name: "新加坡幣",      flag: "🇸🇬", symbol: "S$"),
        .init(code: "THB", name: "泰銖",          flag: "🇹🇭", symbol: "฿"),
        .init(code: "AUD", name: "澳幣",          flag: "🇦🇺", symbol: "A$"),
        .init(code: "CAD", name: "加幣",          flag: "🇨🇦", symbol: "C$"),
        .init(code: "MYR", name: "馬幣",          flag: "🇲🇾", symbol: "RM"),
        .init(code: "IDR", name: "印尼盾",        flag: "🇮🇩", symbol: "Rp"),
        .init(code: "PHP", name: "菲律賓披索",    flag: "🇵🇭", symbol: "₱"),
        .init(code: "VND", name: "越南盾",        flag: "🇻🇳", symbol: "₫"),
    ]

    static func find(_ code: String) -> TravelCurrency? {
        all.first { $0.code == code }
    }
}
