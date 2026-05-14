import SwiftUI

@main
struct ExpenseTrackerApp: App {
    @StateObject private var viewModel = ExpenseViewModel()
    @StateObject private var notificationService = NotificationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(notificationService)
                .onAppear {
                    notificationService.requestPermission()
                }
        }
    }
}
