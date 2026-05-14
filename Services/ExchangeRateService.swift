import Foundation
import Combine

@MainActor
class ExchangeRateService: ObservableObject {

    /// 1 unit of the current travel currency = rateToTWD TWD
    @Published var rateToTWD:    Double  = 0
    @Published var isLoading:    Bool    = false
    @Published var errorMessage: String? = nil
    @Published var lastUpdated:  Date?   = nil

    /// 幣值換算器：以 converterBase 為基準的所有匯率
    /// allRates["USD"] = 0.031 means 1 TWD = 0.031 USD (when base=TWD)
    @Published var allRates:     [String: Double] = [:]
    @Published var converterBase: String = ""

    // ── 近似備援匯率（1 外幣 = X 新台幣）────────────────────
    static let fallbackRates: [String: Double] = [
        "TWD":  1.0,
        "USD": 32.5,  "JPY":  0.215,  "EUR": 35.5,   "GBP": 41.5,
        "HKD":  4.15, "SGD": 24.5,    "CNY":  4.5,   "KRW":  0.024,
        "THB":  0.91, "AUD": 21.5,    "CAD": 23.5,   "MYR":  7.3,
        "IDR":  0.0021,"PHP": 0.56,   "VND":  0.0013, "MOP":  4.01,
    ]

    // ── 擷取出國模式匯率（→ TWD）─────────────────────────────
    func fetchRate(for code: String) async {
        guard code != "TWD" else {
            rateToTWD = 1; lastUpdated = Date(); return
        }
        isLoading    = true
        errorMessage = nil

        do {
            let url  = URL(string: "https://open.er-api.com/v6/latest/\(code)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Decodable { let rates: [String: Double] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            guard let rate = resp.rates["TWD"] else { throw URLError(.badServerResponse) }
            rateToTWD   = rate
            lastUpdated = Date()
        } catch {
            rateToTWD   = Self.fallbackRates[code] ?? 1.0
            lastUpdated = Date()
            errorMessage = "無法取得即時匯率，使用近似值"
        }
        isLoading = false
    }

    // ── 擷取幣值換算器全幣別匯率 ──────────────────────────────
    func fetchAllRates(base: String) async {
        isLoading    = true
        errorMessage = nil
        converterBase = base

        do {
            let url = URL(string: "https://open.er-api.com/v6/latest/\(base)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Decodable { let rates: [String: Double] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            var rates = resp.rates
            rates[base] = 1.0   // 自身 = 1
            allRates    = rates
            lastUpdated = Date()
        } catch {
            // 從備援表換算：baseTWD = 1 base 等於幾台幣
            let baseTWD = Self.fallbackRates[base] ?? 1.0
            var fallback: [String: Double] = [:]
            for (code, rateToTWD) in Self.fallbackRates {
                fallback[code] = baseTWD / rateToTWD
            }
            fallback[base] = 1.0
            allRates    = fallback
            errorMessage = "無法取得即時匯率，使用近似值"
            lastUpdated = Date()
        }
        isLoading = false
    }

    /// 外幣金額 → 台幣
    func toTWD(_ amount: Double) -> Double { amount * max(rateToTWD, 0) }

    /// 台幣換算文字，例如 "≈ NT$264"
    func twdText(from amount: Double) -> String? {
        guard rateToTWD > 0 else { return nil }
        let twd = toTWD(amount)
        let f = NumberFormatter()
        f.numberStyle     = .currency
        f.currencySymbol  = "NT$"
        f.maximumFractionDigits = 0
        return "≈ " + (f.string(from: NSNumber(value: twd)) ?? "NT$\(Int(twd))")
    }
}
