import Foundation
import Combine

@MainActor
class ExchangeRateService: ObservableObject {

    /// 1 unit of the current travel currency = rateToTWD TWD
    @Published var rateToTWD:   Double  = 0
    @Published var isLoading:   Bool    = false
    @Published var errorMessage: String? = nil
    @Published var lastUpdated: Date?   = nil

    // ── 近似備援匯率（API 失敗時使用）────────────────────────
    static let fallbackRates: [String: Double] = [
        "USD": 32.5,  "JPY": 0.215,  "EUR": 35.5,  "GBP": 41.5,
        "HKD":  4.15, "SGD": 24.5,   "CNY":  4.5,  "KRW":  0.024,
        "THB":  0.91, "AUD": 21.5,   "CAD": 23.5,  "MYR":  7.3,
        "IDR":  0.0021,"PHP": 0.56,  "VND":  0.0013
    ]

    // ── 擷取即時匯率 ─────────────────────────────────────────
    func fetchRate(for code: String) async {
        guard code != "TWD" else {
            rateToTWD = 1; lastUpdated = Date(); return
        }
        isLoading    = true
        errorMessage = nil

        do {
            let url  = URL(string: "https://open.er-api.com/v6/latest/\(code)")!
            let (data, _) = try await URLSession.shared.data(from: url)

            struct Resp: Decodable {
                let rates: [String: Double]
            }
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
