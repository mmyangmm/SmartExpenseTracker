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
            .accentColor(.indigo)

            // 懸浮記帳按鈕
            if selectedTab == 0 {
                Button { showQuickAdd = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.indigo.opacity(0.4), radius: 8, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .semibold))
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
