import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @State private var showQuickAdd = false
    @State private var selectedTab  = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("首頁", systemImage: "house.fill") }
                    .tag(0)
                StatisticsView()
                    .tabItem { Label("統計", systemImage: "chart.pie.fill") }
                    .tag(1)
                SettingsView()
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
                    .tag(2)
            }
            .accentColor(AppTheme.pink)

            if selectedTab == 0 {
                Button { showQuickAdd = true } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.pinkGradient)
                            .frame(width: 64, height: 64)
                            .shadow(color: AppTheme.pink.opacity(0.40), radius: 12, y: 6)
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 80)
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView(isPresented: $showQuickAdd)
        }
    }
}
