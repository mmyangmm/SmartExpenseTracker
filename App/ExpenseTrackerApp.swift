import SwiftUI

@main
struct ExpenseTrackerApp: App {
    @StateObject private var viewModel            = ExpenseViewModel()
    @StateObject private var notificationService  = NotificationService()
    @StateObject private var exchangeRateService  = ExchangeRateService()
    @AppStorage("appTheme")          private var appTheme: String = ThemeVariant.pink.rawValue
    @AppStorage("travelModeEnabled") private var travelModeEnabled: Bool = false
    @AppStorage("travelModeCurrency") private var travelModeCurrency: String = "JPY"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(notificationService)
                .environmentObject(exchangeRateService)
                .id(appTheme)
                .onAppear {
                    notificationService.requestPermission()
                    // 若上次仍在出國模式，重新取得匯率
                    if travelModeEnabled {
                        Task { await exchangeRateService.fetchRate(for: travelModeCurrency) }
                    }
                }
        }
    }
}
