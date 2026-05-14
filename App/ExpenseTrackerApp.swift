import SwiftUI

@main
struct ExpenseTrackerApp: App {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var notificationService = NotificationService()
    @AppStorage("appTheme") private var appTheme: String = ThemeVariant.pink.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(notificationService)
                .id(appTheme)           // 主題切換時重建整個 UI
                .onAppear {
                    notificationService.requestPermission()
                }
        }
    }
}
