import SwiftUI

// MARK: - InvoiceWalletView

struct InvoiceWalletView: View {
    @EnvironmentObject var invoiceService: InvoiceService

    @State private var showScan = false
    @State private var showLottery = false
    @State private var selectedPeriodForLottery: String? = nil
    @State private var lotteryWinCount: Int = 0
    @State private var showWinAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if invoiceService.invoices.isEmpty {
                    emptyState
                } else {
                    invoiceList
                }
            }
            .navigationTitle("發票夾")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScan = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showScan) {
            InvoiceScanView()
                .environmentObject(invoiceService)
        }
        .sheet(isPresented: $showLottery) {
            LotteryInputSheet(periodId: selectedPeriodForLottery ?? "") { numbers, periodId in
                let won = invoiceService.applyLottery(numbers: numbers, periodId: periodId)
                showLottery = false
                if won > 0 {
                    lotteryWinCount = won
                    showWinAlert = true
                }
            }
            .environmentObject(invoiceService)
        }
        .alert("🎉 恭喜中獎！", isPresented: $showWinAlert) {
            Button("太棒了！", role: .cancel) {}
        } message: {
            Text("您有 \(lotteryWinCount) 張發票中獎，記得在 25 日前至超商或金融機構兌領！")
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("🧾")
                .font(.system(size: 72))
            Text("還沒有任何發票")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("掃描 QR 碼或手動輸入發票號碼")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showScan = true
            } label: {
                Label("掃描發票", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(AppTheme.pinkGradient)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: Invoice List

    private var invoiceList: some View {
        List {
            ForEach(invoiceService.groupedByPeriod, id: \.period.id) { group in
                Section {
                    ForEach(group.invoices) { invoice in
                        NavigationLink {
                            InvoiceDetailView(invoice: invoice)
                                .environmentObject(invoiceService)
                        } label: {
                            InvoiceRow(invoice: invoice)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                invoiceService.delete(invoice)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    PeriodHeaderView(period: group.period) {
                        selectedPeriodForLottery = group.period.id
                        showLottery = true
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - PeriodHeaderView

struct PeriodHeaderView: View {
    let period: InvoicePeriod
    let onCheckLottery: () -> Void
    @EnvironmentObject var invoiceService: InvoiceService

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(period.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    let won = invoiceService.wonCount(in: period.id)
                    let pending = invoiceService.pendingCount(in: period.id)
                    if won > 0 {
                        Text("🎉 中獎 \(won) 張")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if pending > 0 {
                        Text("⏳ 待兌 \(pending) 張")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            Spacer()

            let pending = invoiceService.pendingCount(in: period.id)
            if period.hasDrawn && pending > 0 {
                Button {
                    onCheckLottery()
                } label: {
                    Text("查詢開獎")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                let fmt = DateFormatter()
                let _ = { fmt.locale = Locale(identifier: "zh_TW"); fmt.dateFormat = "M月d日開獎" }()
                Text(fmt.string(from: period.drawDate))
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - InvoiceRow

struct InvoiceRow: View {
    let invoice: Invoice

    var statusColor: Color {
        switch invoice.lotteryResult {
        case .won:    return .orange
        case .notWon: return AppTheme.textSecondary
        case .pending: return AppTheme.primary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left badge: 2-letter prefix + 8 digits
            VStack(spacing: 2) {
                Text(String(invoice.invoiceNumber.prefix(2)))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(invoice.numberDigits)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(invoice.lotteryResult.hasWon ? Color.orange : AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Right info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(invoice.sellerName.isEmpty ? "（未知商家）" : invoice.sellerName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(invoice.formattedAmount)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }

                HStack {
                    Text(invoice.formattedDate)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("·")
                        .foregroundColor(AppTheme.textSecondary)
                        .font(.caption)
                    Text(invoice.source.rawValue)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()

                    // Status icon
                    Group {
                        switch invoice.lotteryResult {
                        case .won(let tier):
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                Text(tier.displayName)
                                    .foregroundColor(.orange)
                            }
                        case .notWon:
                            Image(systemName: "xmark.circle")
                                .foregroundColor(AppTheme.textSecondary)
                        case .pending:
                            Image(systemName: "clock")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - InvoiceDetailView

struct InvoiceDetailView: View {
    @EnvironmentObject var invoiceService: InvoiceService
    @Environment(\.dismiss) private var dismiss
    let invoice: Invoice

    var body: some View {
        List {
            // 發票資訊
            Section("發票資訊") {
                LabeledContent("號碼", value: invoice.formattedNumber)
                LabeledContent("日期", value: invoice.formattedDate)
                LabeledContent("金額", value: invoice.formattedAmount)
                if !invoice.sellerName.isEmpty {
                    LabeledContent("商家", value: invoice.sellerName)
                }
                if !invoice.sellerTaxID.isEmpty {
                    LabeledContent("統編", value: invoice.sellerTaxID)
                }
                LabeledContent("來源", value: invoice.source.rawValue)
            }

            // 兌獎狀態
            Section("兌獎狀態") {
                LabeledContent("期別", value: invoice.period.displayName)

                let fmt = DateFormatter()
                let _ = { fmt.locale = Locale(identifier: "zh_TW"); fmt.dateStyle = .medium }()
                LabeledContent("開獎日", value: fmt.string(from: invoice.period.drawDate))

                HStack {
                    Text("結果")
                    Spacer()
                    switch invoice.lotteryResult {
                    case .pending:
                        Label("待開獎", systemImage: "clock")
                            .foregroundColor(AppTheme.textSecondary)
                    case .notWon:
                        Label("未中獎", systemImage: "xmark.circle")
                            .foregroundColor(AppTheme.textSecondary)
                    case .won(let tier):
                        Label("\(tier.emoji) \(tier.displayName) \(tier.amountText)", systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                }
            }

            // Items
            if !invoice.items.isEmpty {
                Section("品項明細") {
                    ForEach(invoice.items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("NT$ \(Int(item.amount))")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }

            // Note
            if !invoice.note.isEmpty {
                Section("備註") {
                    Text(invoice.note)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .navigationTitle(invoice.formattedNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    invoiceService.delete(invoice)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - LotteryInputSheet

struct LotteryInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    let periodId: String
    let onApply: (LotteryNumbers, String) -> Void

    @State private var special = ""
    @State private var grand = ""
    @State private var first1 = ""
    @State private var first2 = ""
    @State private var first3 = ""
    @State private var add1 = ""
    @State private var add2 = ""
    @State private var add3 = ""
    @State private var isFetching = false
    @State private var fetchError: String? = nil

    private var canApply: Bool {
        special.count == 8 && grand.count == 8 && first1.count == 8
    }

    var body: some View {
        NavigationStack {
            Form {
                // Auto-fetch
                Section {
                    Button {
                        Task { await fetchOfficialNumbers() }
                    } label: {
                        HStack {
                            if isFetching {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Label("自動查詢開獎號碼", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isFetching)

                    if let err = fetchError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Special & grand
                Section("頭彩") {
                    HStack {
                        Text("特別獎")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("8碼", text: $special)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("特獎")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("8碼", text: $grand)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                // First prize
                Section("頭獎（3組）") {
                    HStack {
                        Text("第 1 組")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("8碼", text: $first1)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("第 2 組")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("8碼", text: $first2)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("第 3 組")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("8碼", text: $first3)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                // Additional sixth
                Section("增開六獎（3碼）") {
                    HStack {
                        Text("第 1 組")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("3碼", text: $add1)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("第 2 組")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("3碼", text: $add2)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("第 3 組")
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 80, alignment: .leading)
                        TextField("3碼", text: $add3)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("輸入開獎號碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用比對") {
                        applyNumbers()
                    }
                    .disabled(!canApply)
                }
            }
        }
    }

    private func applyNumbers() {
        var firstPrize: [String] = []
        if !first1.isEmpty { firstPrize.append(first1) }
        if !first2.isEmpty { firstPrize.append(first2) }
        if !first3.isEmpty { firstPrize.append(first3) }

        var sixthAdd: [String] = []
        if !add1.isEmpty { sixthAdd.append(add1) }
        if !add2.isEmpty { sixthAdd.append(add2) }
        if !add3.isEmpty { sixthAdd.append(add3) }

        let numbers = LotteryNumbers(
            special: special,
            grand: grand,
            firstPrize: firstPrize,
            sixthAdditional: sixthAdd
        )
        onApply(numbers, periodId)
        dismiss()
    }

    private func fetchOfficialNumbers() async {
        isFetching = true
        fetchError = nil
        defer { isFetching = false }

        guard let url = URL(string: "https://invoice.etax.nat.gov.tw/") else {
            fetchError = "無效網址"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                fetchError = "無法解析網頁"
                return
            }
            let parsed = parsePrizes(from: html)
            if parsed.special.isEmpty {
                fetchError = "找不到開獎號碼，請手動輸入"
                return
            }
            special = parsed.special
            grand   = parsed.grand
            if parsed.first.count >= 1 { first1 = parsed.first[0] }
            if parsed.first.count >= 2 { first2 = parsed.first[1] }
            if parsed.first.count >= 3 { first3 = parsed.first[2] }
            if parsed.additional.count >= 1 { add1 = parsed.additional[0] }
            if parsed.additional.count >= 2 { add2 = parsed.additional[1] }
            if parsed.additional.count >= 3 { add3 = parsed.additional[2] }
        } catch {
            fetchError = "查詢失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - HTML parser
    // Page has two identical tables (desktop/mobile). We parse row-by-row and stop at first match
    // per prize type to avoid duplicates.
    // Key insight: 頭獎 numbers are split across adjacent <span> tags, e.g.
    //   <span>21677</span><span class="etw-color-red">046</span>
    // Stripping tags WITHOUT adding spaces joins the digits correctly → "21677046".

    private typealias Prizes = (special: String, grand: String, first: [String], additional: [String])

    private func parsePrizes(from html: String) -> Prizes {
        var special = "", grand = ""
        var first: [String] = [], additional: [String] = []
        var specialDone = false, grandDone = false, firstDone = false

        let trRegex  = try! NSRegularExpression(pattern: "<tr[^>]*>(.*?)</tr>",
                                                options: .dotMatchesLineSeparators)
        let re8 = try! NSRegularExpression(pattern: "\\b\\d{8}\\b")
        let re3 = try! NSRegularExpression(pattern: "\\b\\d{3}\\b")

        func nums(_ re: NSRegularExpression, in text: String) -> [String] {
            re.matches(in: text, range: NSRange(text.startIndex..., in: text))
              .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
        }

        for m in trRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let r = Range(m.range(at: 1), in: html) else { continue }
            let rowHtml = String(html[r])
            // Strip tags without inserting spaces so adjacent spans merge their digit content
            let text = rowHtml.replacingOccurrences(of: "<[^>]+>", with: "",
                                                    options: .regularExpression)
            if !specialDone && text.contains("特別獎") {
                let n = nums(re8, in: text)
                if !n.isEmpty { special = n[0]; specialDone = true }
            } else if !grandDone && text.contains("特獎") && !text.contains("特別獎") {
                let n = nums(re8, in: text)
                if !n.isEmpty { grand = n[0]; grandDone = true }
            } else if !firstDone && text.contains("頭獎") {
                first = Array(nums(re8, in: text).prefix(3))
                if !first.isEmpty { firstDone = true }
            } else if text.contains("增開六獎") {
                additional = Array(nums(re3, in: text).prefix(3))
            }
        }
        return (special, grand, first, additional)
    }
}
