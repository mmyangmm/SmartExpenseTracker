import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ExpenseViewModel
    @State private var showQuickAdd = false
    // @AppStorage 確保主題切換重建 ContentView 時，選中的 tab 不會被重置
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @AppStorage("appTheme") private var appTheme: String = ThemeVariant.pink.rawValue

    private var activeColorScheme: ColorScheme {
        ThemeVariant(rawValue: appTheme)?.preferredColorScheme ?? .light
    }

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

            // ── 記帳 FAB ─────────────────────────────────────────
            if selectedTab == 0 {
                Button { showQuickAdd = true } label: {
                    Text("記帳")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 15)
                        .background(AppTheme.pinkGradient)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.pink.opacity(0.38), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 82)
            }
        }
        .preferredColorScheme(activeColorScheme)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView(isPresented: $showQuickAdd)
        }
    }
}
