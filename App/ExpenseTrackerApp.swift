import SwiftUI

@main
struct ExpenseTrackerApp: App {
    @StateObject private var viewModel            = ExpenseViewModel()
    @StateObject private var notificationService  = NotificationService()
    @StateObject private var exchangeRateService  = ExchangeRateService()
    @StateObject private var invoiceService       = InvoiceService()
    @AppStorage("appTheme")          private var appTheme: String = ThemeVariant.pink.rawValue
    @AppStorage("travelModeEnabled") private var travelModeEnabled: Bool = false
    @AppStorage("travelModeCurrency") private var travelModeCurrency: String = "JPY"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(notificationService)
                .environmentObject(exchangeRateService)
                .environmentObject(invoiceService)
                .id(appTheme)
                .onAppear {
                    notificationService.requestPermission()
                    invoiceService.load()
                    // 若上次仍在出國模式，重新取得匯率
                    if travelModeEnabled {
                        Task { await exchangeRateService.fetchRate(for: travelModeCurrency) }
                    }
                }
        }
    }
}
