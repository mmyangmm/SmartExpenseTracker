const STORAGE_KEY = "i-expense-pwa-v1";
const SETTINGS_KEY = "i-expense-pwa-settings-v1";
const TRIPS_KEY = "i-expense-pwa-trips-v1";
const RATE_CACHE_KEY = "i-expense-pwa-rates-v1";
const DEFAULT_THEME_COLOR = "#ff6b9d";

let reminderTimer = null;

const categories = [
  { id: "food", name: "餐飲", type: "expense", emoji: "🍜", color: "#ff6b6b", keywords: ["午餐", "早餐", "晚餐", "飯", "食", "吃", "餐廳", "便當", "麵", "小吃", "夜市", "火鍋", "壽司", "拉麵", "漢堡", "pizza"] },
  { id: "drinks", name: "飲料", type: "expense", emoji: "🧋", color: "#c27a3a", keywords: ["飲料", "咖啡", "奶茶", "珍奶", "茶", "手搖", "星巴克", "可樂", "果汁", "酒", "啤酒"] },
  { id: "groceries", name: "超市", type: "expense", emoji: "🛒", color: "#4f9f52", keywords: ["超市", "全聯", "家樂福", "costco", "好市多", "菜", "水果", "生鮮", "雜貨", "採買"] },
  { id: "transport", name: "交通", type: "expense", emoji: "🚗", color: "#4ecdc4", keywords: ["捷運", "公車", "計程車", "uber", "taxi", "油費", "停車", "高鐵", "火車", "交通", "加油", "機票", "台鐵", "悠遊", "youbike", "摩托"] },
  { id: "shopping", name: "購物", type: "expense", emoji: "🛍️", color: "#45b7d1", keywords: ["購物", "買", "3c", "電腦", "手機", "momo", "蝦皮", "網購", "amazon", "百貨", "日用品"] },
  { id: "clothing", name: "服飾", type: "expense", emoji: "👗", color: "#ff8fb3", keywords: ["衣服", "服飾", "鞋子", "包包", "外套", "褲子", "uniqlo", "zara", "穿搭"] },
  { id: "entertainment", name: "娛樂", type: "expense", emoji: "🎮", color: "#96ceb4", keywords: ["電影", "遊戲", "ktv", "娛樂", "玩", "音樂", "書", "展覽", "演唱會", "劇場", "桌遊"] },
  { id: "subscription", name: "訂閱", type: "expense", emoji: "📱", color: "#8f7ae5", keywords: ["訂閱", "netflix", "spotify", "youtube", "icloud", "app", "會員", "月費", "方案"] },
  { id: "travel", name: "旅遊", type: "expense", emoji: "✈️", color: "#2f80ed", keywords: ["旅遊", "旅行", "住宿", "飯店", "hotel", "民宿", "機票", "行李", "門票", "出國"] },
  { id: "medical", name: "醫療", type: "expense", emoji: "💊", color: "#ff9ff3", keywords: ["醫院", "藥局", "看病", "醫療", "診所", "藥", "健檢", "牙科", "眼科", "掛號", "保健", "維他命"] },
  { id: "beauty", name: "美容", type: "expense", emoji: "💅", color: "#d66fc4", keywords: ["美容", "美甲", "美髮", "剪髮", "染髮", "保養", "化妝", "保養品", "按摩", "spa"] },
  { id: "fitness", name: "運動", type: "expense", emoji: "🏋️", color: "#ff9f1c", keywords: ["健身", "gym", "運動", "瑜伽", "球", "游泳", "課程", "教練", "跑步"] },
  { id: "home", name: "居家", type: "expense", emoji: "🏠", color: "#ffeaa7", keywords: ["房租", "家具", "裝潢", "修繕", "家居", "清潔", "管理費", "房貸"] },
  { id: "utilities", name: "水電", type: "expense", emoji: "💡", color: "#f4b942", keywords: ["水電", "電費", "水費", "瓦斯", "網路", "電話費", "手機費", "第四台", "帳單"] },
  { id: "education", name: "學習", type: "expense", emoji: "📚", color: "#7a65b7", keywords: ["學習", "課程", "補習", "書", "教材", "學費", "線上課", "udemy", "語言"] },
  { id: "family", name: "家庭", type: "expense", emoji: "👨‍👩‍👧", color: "#ff7f50", keywords: ["家庭", "小孩", "孩子", "爸媽", "家人", "孝親", "托嬰", "奶粉", "尿布"] },
  { id: "pets", name: "寵物", type: "expense", emoji: "🐾", color: "#a66a45", keywords: ["寵物", "貓", "狗", "飼料", "獸醫", "貓砂", "美容"] },
  { id: "gifts", name: "禮物", type: "expense", emoji: "🎁", color: "#ff6f91", keywords: ["禮物", "生日", "請客", "紅包", "禮金", "送禮", "聚餐"] },
  { id: "insurance", name: "保險", type: "expense", emoji: "🛡️", color: "#607d8b", keywords: ["保險", "保費", "壽險", "醫療險", "車險"] },
  { id: "tax", name: "稅費", type: "expense", emoji: "🧾", color: "#8d6e63", keywords: ["稅", "稅金", "所得稅", "牌照稅", "燃料稅", "手續費", "罰單"] },
  { id: "other", name: "其他", type: "expense", emoji: "📦", color: "#b2bec3", keywords: [] },
  { id: "salary", name: "薪資", type: "income", emoji: "💰", color: "#34c759", keywords: ["薪水", "薪資", "月薪", "工資", "底薪", "發薪", "入帳", "salary"] },
  { id: "bonus", name: "獎金", type: "income", emoji: "🏆", color: "#30d158", keywords: ["獎金", "年終", "績效", "紅包", "禮金", "bonus"] },
  { id: "partTime", name: "兼職", type: "income", emoji: "💼", color: "#5ac8fa", keywords: ["兼職", "打工", "接案", "freelance", "外快", "副業", "稿費"] },
  { id: "investment", name: "投資", type: "income", emoji: "📈", color: "#af52de", keywords: ["股票", "股利", "投資", "基金", "利息", "配息", "dividend", "收益"] },
  { id: "refund", name: "退款", type: "income", emoji: "↩️", color: "#00a896", keywords: ["退款", "退費", "退貨", "回饋", "折讓", "補助", "退稅"] },
  { id: "rental", name: "租金", type: "income", emoji: "🏘️", color: "#4e9f3d", keywords: ["租金", "房租收入", "收租", "租屋"] },
  { id: "incomeOther", name: "其他收入", type: "income", emoji: "💵", color: "#9acd32", keywords: [] }
];

const travelCurrencies = [
  { code: "TWD", name: "新台幣", flag: "NT$", symbol: "NT$" },
  { code: "JPY", name: "日圓", flag: "🇯🇵", symbol: "¥" },
  { code: "USD", name: "美元", flag: "🇺🇸", symbol: "$" },
  { code: "EUR", name: "歐元", flag: "🇪🇺", symbol: "€" },
  { code: "GBP", name: "英鎊", flag: "🇬🇧", symbol: "£" },
  { code: "CHF", name: "瑞士法郎", flag: "🇨🇭", symbol: "CHF" },
  { code: "HKD", name: "港幣", flag: "🇭🇰", symbol: "HK$" },
  { code: "MOP", name: "澳門幣", flag: "🇲🇴", symbol: "MOP$" },
  { code: "CNY", name: "人民幣", flag: "🇨🇳", symbol: "¥" },
  { code: "KRW", name: "韓元", flag: "🇰🇷", symbol: "₩" },
  { code: "SGD", name: "新加坡幣", flag: "🇸🇬", symbol: "S$" },
  { code: "THB", name: "泰銖", flag: "🇹🇭", symbol: "฿" },
  { code: "AUD", name: "澳幣", flag: "🇦🇺", symbol: "A$" },
  { code: "CAD", name: "加幣", flag: "🇨🇦", symbol: "C$" },
  { code: "MYR", name: "馬幣", flag: "🇲🇾", symbol: "RM" },
  { code: "IDR", name: "印尼盾", flag: "🇮🇩", symbol: "Rp" },
  { code: "PHP", name: "菲律賓披索", flag: "🇵🇭", symbol: "₱" },
  { code: "VND", name: "越南盾", flag: "🇻🇳", symbol: "₫" }
];

const fallbackTwdRates = {
  TWD: 1,
  USD: 32.5,
  JPY: 0.215,
  EUR: 35.5,
  GBP: 41.5,
  CHF: 37.2,
  HKD: 4.15,
  SGD: 24.5,
  CNY: 4.5,
  KRW: 0.024,
  THB: 0.91,
  AUD: 21.5,
  CAD: 23.5,
  MYR: 7.3,
  IDR: 0.0021,
  PHP: 0.56,
  VND: 0.0013,
  MOP: 4.01
};

const themeOptions = [
  { id: "pink", name: "蜜桃", color: "#ff6b9d", swatch: "linear-gradient(135deg, #ff6b9d, #f06f3f)" },
  { id: "ocean", name: "海藍", color: "#2f8edb", swatch: "linear-gradient(135deg, #2f8edb, #14a38b)" },
  { id: "matcha", name: "抹茶", color: "#54a45f", swatch: "linear-gradient(135deg, #54a45f, #d28b2f)" },
  { id: "graphite", name: "黑曜", color: "#15171c", swatch: "linear-gradient(135deg, #f07aa7, #4d5f84)" }
];

const iconOptions = [
  { id: "default", name: "經典", symbol: "i", bg: "linear-gradient(135deg, #ff6b9d, #f06f3f)" },
  { id: "coin", name: "金幣", symbol: "$", bg: "linear-gradient(135deg, #f8b64c, #e56d46)" },
  { id: "travel", name: "旅行", symbol: "✈", bg: "linear-gradient(135deg, #2f8edb, #14a38b)" },
  { id: "cat", name: "貓咪", image: "./assets/app-icon-cat.png", bg: "linear-gradient(135deg, #2dd4bf, #ff7aa8)" },
  { id: "night", name: "夜間", symbol: "月", bg: "linear-gradient(135deg, #20242d, #7a50d6)" }
];

const converterDefaultCodes = ["TWD", "USD", "JPY", "EUR", "CNY", "HKD", "KRW", "THB"];

const state = {
  expenses: loadExpenses(),
  settings: loadSettings(),
  trips: loadTrips(),
  rateCache: loadRateCache(),
  selectedMonth: startOfMonth(new Date()),
  currentTab: "home",
  statsMode: "category",
  recognition: null,
  isRecording: false,
  voiceTranscript: "",
  voiceMessage: "",
  shouldParseOnStop: false,
  scanMessage: "",
  isScanning: false,
  activeEntryCurrency: null,
  converterMessage: "",
  travelMessage: ""
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

const els = {
  todayLabel: $("#todayLabel"),
  homeTitle: $("#homeTitle"),
  goCurrentMonth: $("#goCurrentMonth"),
  monthExpense: $("#monthExpense"),
  monthIncome: $("#monthIncome"),
  currentExpenseLabel: $("#currentExpenseLabel"),
  averageLabel: $("#averageLabel"),
  averageMeter: $("#averageMeter"),
  categoryStrip: $("#categoryStrip"),
  transactionList: $("#transactionList"),
  recordCount: $("#recordCount"),
  chartCanvas: $("#chartCanvas"),
  statsList: $("#statsList"),
  statsCount: $("#statsCount"),
  statsMode: $("#statsMode"),
  dialog: $("#entryDialog"),
  entryForm: $("#entryForm"),
  dialogTitle: $("#dialogTitle"),
  entryId: $("#entryId"),
  amountInput: $("#amountInput"),
  amountDisplay: $("#amountDisplay"),
  amountCard: $(".amount-card"),
  amountSign: $("#amountSign"),
  currencySymbol: $("#currencySymbol"),
  twdHint: $("#twdHint"),
  amountError: $("#amountError"),
  categoryInput: $("#categoryInput"),
  categoryGrid: $("#categoryGrid"),
  noteInput: $("#noteInput"),
  dateInput: $("#dateInput"),
  deleteEntry: $("#deleteEntry"),
  saveEntry: $("#saveEntry"),
  voiceButton: $("#voiceButton"),
  voiceIcon: $("#voiceIcon"),
  voiceLabel: $("#voiceLabel"),
  voiceBanner: $("#voiceBanner"),
  scanReceipt: $("#scanReceipt"),
  receiptInput: $("#receiptInput"),
  scanBanner: $("#scanBanner"),
  brandIcon: $("#brandIcon"),
  themeSummary: $("#themeSummary"),
  iconSummary: $("#iconSummary"),
  themeOptions: $("#themeOptions"),
  iconOptions: $("#iconOptions"),
  travelModeEnabled: $("#travelModeEnabled"),
  travelCurrency: $("#travelCurrency"),
  travelRateLabel: $("#travelRateLabel"),
  travelStatus: $("#travelStatus"),
  refreshTravelRate: $("#refreshTravelRate"),
  refreshConverterRates: $("#refreshConverterRates"),
  converterList: $("#converterList"),
  converterStatus: $("#converterStatus"),
  converterAddCurrency: $("#converterAddCurrency"),
  addConverterCurrency: $("#addConverterCurrency"),
  reminderEnabled: $("#reminderEnabled"),
  reminderTime: $("#reminderTime"),
  requestNotification: $("#requestNotification"),
  testNotification: $("#testNotification"),
  notificationStatus: $("#notificationStatus"),
  dataCount: $("#dataCount"),
  copyJson: $("#copyJson")
};

init();

function init() {
  els.entryForm.noValidate = true;
  els.todayLabel.textContent = new Intl.DateTimeFormat("zh-TW", {
    month: "long",
    day: "numeric",
    weekday: "long"
  }).format(new Date());

  applySettings();
  populateCurrencySelects();
  bindEvents();
  renderCategoryPicker();
  renderAmountDisplay();
  renderSettings();
  render();
  refreshRatesForSettings(false);
  scheduleReminder();
  registerServiceWorker();
}

function bindEvents() {
  $$("[data-month]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedMonth = addMonths(state.selectedMonth, Number(button.dataset.month));
      render();
    });
  });

  els.goCurrentMonth.addEventListener("click", () => {
    state.selectedMonth = startOfMonth(new Date());
    render();
  });

  $$(".tab").forEach((button) => {
    button.addEventListener("click", () => {
      state.currentTab = button.dataset.tab;
      renderTabs();
    });
  });

  $("#addButton").addEventListener("click", () => openEntryDialog());
  $("#cancelEntry").addEventListener("click", () => closeDialog());

  $$("input[name='entryType']").forEach((radio) => {
    radio.addEventListener("change", () => {
      const nextType = entryType();
      if (!categoryMatchesType(els.categoryInput.value, nextType)) {
        els.categoryInput.value = defaultCategoryId(nextType);
      }
      inferCategoryFromNote();
      renderCategoryPicker();
      renderAmountDisplay();
    });
  });

  els.noteInput.addEventListener("input", inferCategoryFromNote);
  els.entryForm.addEventListener("submit", saveEntry);
  els.deleteEntry.addEventListener("click", deleteEntry);
  els.statsMode.addEventListener("change", () => {
    state.statsMode = els.statsMode.value;
    renderStats();
  });

  $$(".calc-key").forEach((button) => {
    button.addEventListener("click", () => handleCalcKey(button.dataset.key));
  });

  els.voiceButton.addEventListener("click", handleVoiceTap);
  els.scanReceipt.addEventListener("click", () => els.receiptInput.click());
  els.receiptInput.addEventListener("change", handleReceiptInput);

  els.refreshConverterRates.addEventListener("click", () => refreshConverterRates(true));
  els.addConverterCurrency.addEventListener("click", addSelectedConverterCurrency);
  els.refreshTravelRate.addEventListener("click", () => refreshTravelRate(true));
  els.travelModeEnabled.addEventListener("change", () => toggleTravelMode(els.travelModeEnabled.checked));
  els.travelCurrency.addEventListener("change", () => {
    state.settings.travelCurrency = els.travelCurrency.value;
    saveSettings();
    renderSettings();
    refreshTravelRate(false);
    renderAmountDisplay();
  });
  els.reminderEnabled.addEventListener("change", () => updateReminderEnabled(els.reminderEnabled.checked));
  els.reminderTime.addEventListener("change", () => {
    state.settings.reminderTime = els.reminderTime.value || "21:00";
    saveSettings();
    renderNotificationSettings();
    scheduleReminder();
  });
  els.requestNotification.addEventListener("click", requestNotificationPermission);
  els.testNotification.addEventListener("click", () => showReminderNotification(true));
  $("#exportJson").addEventListener("click", exportJson);
  els.copyJson.addEventListener("click", copyJson);
  $("#exportCsv").addEventListener("click", exportCsv);
  $("#importJson").addEventListener("change", importJson);
  $("#clearData").addEventListener("click", clearData);

}

function render() {
  renderHome();
  renderStats();
  renderSettings();
  renderTabs();
}

function renderTabs() {
  $$(".view").forEach((view) => view.classList.toggle("active", view.id === `${state.currentTab}View`));
  $$(".tab").forEach((tab) => {
    const active = tab.dataset.tab === state.currentTab;
    tab.classList.toggle("active", active);
    tab.setAttribute("aria-current", active ? "page" : "false");
  });
  $("#addButton").hidden = state.currentTab !== "home";
}

function populateCurrencySelects() {
  const options = travelCurrencies.map((currency) => `
    <option value="${currency.code}">${currencyLabelText(currency)}</option>
  `).join("");
  els.travelCurrency.innerHTML = options;
  els.converterAddCurrency.innerHTML = "";
}

function renderSettings() {
  renderThemeSettings();
  renderIconSettings();
  renderTravelSettings();
  renderConverter();
  renderNotificationSettings();
  updateDataManagement();
}

function renderThemeSettings() {
  const theme = validThemeId(state.settings.theme);
  const themeName = themeOptions.find((option) => option.id === theme)?.name || "蜜桃";
  els.themeSummary.textContent = themeName;

  els.themeOptions.innerHTML = themeOptions.map((option) => `
    <button class="option-button ${option.id === theme ? "selected" : ""}" type="button" data-theme="${option.id}" aria-pressed="${option.id === theme}">
      <span class="swatch" style="background:${option.swatch}" aria-hidden="true"></span>
      <span>${escapeHtml(option.name)}</span>
    </button>
  `).join("");

  $$("#themeOptions [data-theme]").forEach((button) => {
    button.addEventListener("click", () => {
      state.settings.theme = button.dataset.theme;
      saveSettings();
      applySettings();
      renderThemeSettings();
    });
  });
}

function renderIconSettings() {
  const icon = validIconId(state.settings.icon);
  const iconName = iconOptions.find((option) => option.id === icon)?.name || "經典";
  els.iconSummary.textContent = iconName;

  els.iconOptions.innerHTML = iconOptions.map((option) => `
    <button class="option-button ${option.id === icon ? "selected" : ""}" type="button" data-icon="${option.id}" aria-pressed="${option.id === icon}">
      <span class="icon-preview" style="background:${option.bg}" aria-hidden="true">${iconMarkup(option)}</span>
      <span>${escapeHtml(option.name)}</span>
    </button>
  `).join("");

  $$("#iconOptions [data-icon]").forEach((button) => {
    button.addEventListener("click", () => {
      state.settings.icon = button.dataset.icon;
      saveSettings();
      applySettings();
      renderIconSettings();
    });
  });
}

function applySettings() {
  const theme = validThemeId(state.settings.theme);
  const themeOption = themeOptions.find((option) => option.id === theme) || themeOptions[0];
  const icon = iconOptions.find((option) => option.id === validIconId(state.settings.icon)) || iconOptions[0];
  document.body.dataset.theme = theme;
  document.body.style.setProperty("--app-icon-bg", icon.bg);
  els.brandIcon.innerHTML = iconMarkup(icon);

  const themeMeta = document.querySelector("meta[name='theme-color']");
  if (themeMeta) themeMeta.setAttribute("content", themeOption.color || DEFAULT_THEME_COLOR);
}

function renderTravelSettings() {
  const currency = currencyInfoFor(state.settings.travelCurrency);
  const rate = twdRateFor(currency.code);
  const activeItems = state.settings.travelSessionId
    ? state.expenses.filter((item) => item.travelSessionId === state.settings.travelSessionId)
    : [];
  els.travelModeEnabled.checked = Boolean(state.settings.travelModeEnabled);
  els.travelCurrency.value = currency.code;
  els.travelStatus.textContent = state.settings.travelModeEnabled
    ? `${currency.code} · ${activeItems.length} 筆`
    : `${state.trips.length} 次旅行`;
  els.travelRateLabel.textContent = currency.code === "TWD"
    ? "1 TWD = NT$1"
    : `1 ${currency.code} ≈ ${formatTwdRate(rate)}${state.travelMessage ? ` · ${state.travelMessage}` : ""}`;
}

function renderConverter() {
  const codes = selectedConverterCodes();
  const base = currencyInfoFor(state.settings.converterBase);
  const amount = Number(state.settings.converterAmount || 0);
  const baseRate = twdRateFor(base.code);
  const available = travelCurrencies.filter((currency) => !codes.includes(currency.code));

  els.converterStatus.textContent = state.converterMessage || `基準 ${base.code} · ${codes.length} 幣別`;
  els.converterList.innerHTML = codes.map((code, index) => {
    const currency = currencyInfoFor(code);
    const isBase = code === base.code;
    const converted = isBase ? amount : amount > 0 ? (amount * baseRate) / twdRateFor(code) : 0;
    return `
      <div class="converter-row ${isBase ? "base-row" : ""}" data-code="${escapeAttr(code)}">
        <div class="converter-meta">
          ${currencyIconMarkup(currency, "currency-icon")}
          <div>
            <strong>${escapeHtml(currency.name)}</strong>
            <span class="currency-code-line">${escapeHtml(code)}${isBase ? " · 基準" : ""}</span>
          </div>
        </div>
        <div class="converter-controls" aria-label="${escapeAttr(`${currency.name} 排序與刪除`)}">
          <button class="row-tool" data-move="up" data-code="${escapeAttr(code)}" type="button" ${index === 0 ? "disabled" : ""} aria-label="上移 ${escapeAttr(currency.name)}">↑</button>
          <button class="row-tool" data-move="down" data-code="${escapeAttr(code)}" type="button" ${index === codes.length - 1 ? "disabled" : ""} aria-label="下移 ${escapeAttr(currency.name)}">↓</button>
          <button class="row-tool danger-tool" data-remove="${escapeAttr(code)}" type="button" ${isBase || codes.length <= 2 ? "disabled" : ""} aria-label="刪除 ${escapeAttr(currency.name)}">×</button>
        </div>
        <label class="converter-input-wrap">
          <span>${escapeHtml(currency.symbol)}</span>
          <input
            class="converter-input"
            data-code="${escapeAttr(code)}"
            inputmode="decimal"
            autocomplete="off"
            aria-label="${escapeAttr(`${currency.name}金額`)}"
            value="${escapeAttr(isBase ? (state.settings.converterAmount || "") : formatConverterInput(code, converted))}"
          >
        </label>
      </div>
    `;
  }).join("");

  if (available.length) {
    els.converterAddCurrency.innerHTML = available.map((currency) => `
      <option value="${currency.code}">${currencyLabelText(currency)}</option>
    `).join("");
    els.converterAddCurrency.disabled = false;
    els.addConverterCurrency.disabled = false;
  } else {
    els.converterAddCurrency.innerHTML = `<option value="">已加入所有幣別</option>`;
    els.converterAddCurrency.disabled = true;
    els.addConverterCurrency.disabled = true;
  }

  bindConverterRows();
}

function bindConverterRows() {
  $$(".converter-input").forEach((input) => {
    input.addEventListener("focus", () => setConverterBase(input.dataset.code));
    input.addEventListener("input", () => handleConverterInput(input));
  });

  $$("[data-move]").forEach((button) => {
    button.addEventListener("click", () => moveConverterCurrency(button.dataset.code, button.dataset.move));
  });

  $$("[data-remove]").forEach((button) => {
    button.addEventListener("click", () => removeConverterCurrency(button.dataset.remove));
  });
}

function handleConverterInput(input) {
  const code = currencyInfoFor(input.dataset.code).code;
  const normalized = normalizeConverterText(input.value);
  input.value = normalized;
  state.settings.converterBase = code;
  state.settings.converterAmount = normalized;
  saveSettings();
  updateConverterBaseState();
  updateConverterAmounts();
}

function setConverterBase(code) {
  const next = currencyInfoFor(code).code;
  if (state.settings.converterBase === next) return;
  const input = document.querySelector(`.converter-input[data-code="${cssEscape(next)}"]`);
  state.settings.converterBase = next;
  state.settings.converterAmount = normalizeConverterText(input?.value || "1");
  saveSettings();
  updateConverterBaseState();
  updateConverterAmounts();
}

function updateConverterBaseState() {
  const base = currencyInfoFor(state.settings.converterBase).code;
  const codes = selectedConverterCodes();
  els.converterStatus.textContent = state.converterMessage || `基準 ${base} · ${codes.length} 幣別`;
  $$(".converter-row").forEach((row) => {
    const isBase = row.dataset.code === base;
    const currency = currencyInfoFor(row.dataset.code);
    row.classList.toggle("base-row", isBase);
    const codeLine = row.querySelector(".currency-code-line");
    if (codeLine) codeLine.textContent = `${currency.code}${isBase ? " · 基準" : ""}`;
    const remove = row.querySelector("[data-remove]");
    if (remove) remove.disabled = isBase || codes.length <= 2;
  });
}

function updateConverterAmounts() {
  const base = currencyInfoFor(state.settings.converterBase).code;
  const amount = Number(state.settings.converterAmount || 0);
  const baseRate = twdRateFor(base);
  $$(".converter-input").forEach((input) => {
    const code = currencyInfoFor(input.dataset.code).code;
    if (code === base) return;
    const converted = amount > 0 ? (amount * baseRate) / twdRateFor(code) : 0;
    input.value = formatConverterInput(code, converted);
  });
}

function addSelectedConverterCurrency() {
  const code = currencyInfoFor(els.converterAddCurrency.value).code;
  if (!code) return;
  const codes = selectedConverterCodes();
  if (codes.includes(code)) return;
  state.settings.converterCurrencies = [...codes, code];
  saveSettings();
  refreshConverterRates(false);
  renderConverter();
}

function moveConverterCurrency(code, direction) {
  const codes = selectedConverterCodes();
  const index = codes.indexOf(currencyInfoFor(code).code);
  if (index < 0) return;
  const nextIndex = direction === "up" ? index - 1 : index + 1;
  if (nextIndex < 0 || nextIndex >= codes.length) return;
  const next = [...codes];
  [next[index], next[nextIndex]] = [next[nextIndex], next[index]];
  state.settings.converterCurrencies = next;
  saveSettings();
  renderConverter();
}

function removeConverterCurrency(code) {
  const target = currencyInfoFor(code).code;
  const codes = selectedConverterCodes();
  if (target === state.settings.converterBase || codes.length <= 2) return;
  state.settings.converterCurrencies = codes.filter((item) => item !== target);
  saveSettings();
  renderConverter();
}

function renderNotificationSettings() {
  const supported = "Notification" in window;
  const permission = supported ? Notification.permission : "unsupported";
  const granted = permission === "granted";
  const locked = granted || permission === "denied" || permission === "unsupported";
  els.reminderEnabled.checked = Boolean(state.settings.reminderEnabled);
  els.reminderTime.value = state.settings.reminderTime || "21:00";
  els.notificationStatus.textContent = notificationStatusText(permission);
  els.requestNotification.disabled = locked;
  els.requestNotification.classList.toggle("success-action", granted);
  els.requestNotification.textContent = granted ? "✅ 已允許" : permission === "denied" ? "通知已封鎖" : supported ? "允許通知" : "不支援通知";
}

function updateDataManagement() {
  const bytes = new Blob([JSON.stringify(createBackupPayload())]).size;
  const kb = Math.max(1, Math.ceil(bytes / 1024));
  els.dataCount.textContent = `${state.expenses.length} 筆 · ${state.trips.length} 次旅行 · ${kb} KB`;
}

function toggleTravelMode(enabled) {
  const wasEnabled = Boolean(state.settings.travelModeEnabled);
  state.settings.travelModeEnabled = enabled;

  if (enabled && !wasEnabled) {
    state.settings.travelSessionId = makeId();
    state.settings.travelStartedAt = new Date().toISOString();
  }

  if (!enabled && wasEnabled) {
    finishTravelSession();
  }

  saveSettings();
  renderSettings();
  renderAmountDisplay();
  if (enabled) refreshTravelRate(false);
}

function finishTravelSession() {
  const sessionId = state.settings.travelSessionId;
  if (!sessionId) return;
  const items = state.expenses.filter((item) => item.travelSessionId === sessionId);
  if (items.length) {
    const trip = {
      id: sessionId,
      startedAt: state.settings.travelStartedAt || items[items.length - 1].date,
      endedAt: new Date().toISOString(),
      currency: state.settings.travelCurrency,
      count: items.length,
      expenseTotal: sum(items.filter((item) => !item.isIncome)),
      incomeTotal: sum(items.filter((item) => item.isIncome))
    };
    state.trips = [trip, ...state.trips.filter((item) => item.id !== sessionId)];
    saveTrips();
  }
  state.settings.travelSessionId = "";
  state.settings.travelStartedAt = "";
}

function activeTravelCurrency() {
  return state.settings.travelModeEnabled ? currencyInfoFor(state.settings.travelCurrency).code : "TWD";
}

async function refreshTravelRate(force) {
  const currency = currencyInfoFor(state.settings.travelCurrency);
  state.travelMessage = "更新中";
  renderTravelSettings();
  try {
    await fetchTwdRate(currency.code, force);
    state.travelMessage = "已更新";
  } catch {
    state.travelMessage = "使用估算";
  } finally {
    renderTravelSettings();
    renderAmountDisplay();
  }
}

async function refreshRatesForSettings(force) {
  await Promise.allSettled([
    refreshTravelRate(force),
    refreshConverterRates(force)
  ]);
}

async function refreshConverterRates(force) {
  const base = currencyInfoFor(state.settings.converterBase).code;
  const targetCodes = selectedConverterCodes();
  state.converterMessage = "匯率更新中";
  els.refreshConverterRates.disabled = true;
  renderConverter();
  try {
    await Promise.all(targetCodes.map((code) => fetchTwdRate(code, force)));
    state.converterMessage = `已更新 ${timeShort(new Date())}`;
  } catch {
    state.converterMessage = "使用離線估算";
  } finally {
    els.refreshConverterRates.disabled = false;
    renderConverter();
  }
}

async function fetchTwdRate(code, force = false) {
  const currency = currencyInfoFor(code).code;
  if (currency === "TWD") {
    state.rateCache.TWD = { rate: 1, updatedAt: new Date().toISOString(), source: "base" };
    saveRateCache();
    return 1;
  }

  const cached = state.rateCache[currency];
  const fresh = cached && Date.now() - new Date(cached.updatedAt).getTime() < 12 * 60 * 60 * 1000;
  if (!force && fresh) return cached.rate;

  try {
    const response = await fetch(`https://open.er-api.com/v6/latest/${currency}`, { cache: force ? "reload" : "default" });
    if (!response.ok) throw new Error("Rate fetch failed");
    const payload = await response.json();
    const rate = Number(payload?.rates?.TWD);
    if (!Number.isFinite(rate) || rate <= 0) throw new Error("Missing TWD rate");
    state.rateCache[currency] = { rate, updatedAt: new Date().toISOString(), source: "live" };
    saveRateCache();
    return rate;
  } catch (error) {
    const fallback = fallbackTwdRates[currency];
    if (!Number.isFinite(fallback)) throw error;
    state.rateCache[currency] = {
      rate: fallback,
      updatedAt: cached?.updatedAt || new Date().toISOString(),
      source: "fallback"
    };
    saveRateCache();
    return fallback;
  }
}

function twdRateFor(code) {
  const currency = currencyInfoFor(code).code;
  return Number(state.rateCache[currency]?.rate || fallbackTwdRates[currency] || 1);
}

async function updateReminderEnabled(enabled) {
  if (!enabled) {
    state.settings.reminderEnabled = false;
    saveSettings();
    renderNotificationSettings();
    scheduleReminder();
    return;
  }

  const granted = await requestNotificationPermission();
  state.settings.reminderEnabled = granted;
  saveSettings();
  renderNotificationSettings();
  scheduleReminder();
}

async function requestNotificationPermission() {
  if (!("Notification" in window)) {
    state.settings.reminderEnabled = false;
    saveSettings();
    renderNotificationSettings();
    return false;
  }

  if (Notification.permission === "granted") {
    renderNotificationSettings();
    return true;
  }

  if (Notification.permission === "denied") {
    state.settings.reminderEnabled = false;
    saveSettings();
    renderNotificationSettings();
    return false;
  }

  const permission = await Notification.requestPermission();
  renderNotificationSettings();
  return permission === "granted";
}

function scheduleReminder() {
  if (reminderTimer) {
    clearTimeout(reminderTimer);
    reminderTimer = null;
  }
  if (!state.settings.reminderEnabled || !("Notification" in window) || Notification.permission !== "granted") return;

  const next = nextReminderDate(state.settings.reminderTime || "21:00");
  reminderTimer = window.setTimeout(() => {
    showReminderNotification(false);
    scheduleReminder();
  }, next.getTime() - Date.now());
}

async function showReminderNotification(test) {
  const granted = await requestNotificationPermission();
  if (!granted) {
    window.alert("通知尚未允許。");
    return;
  }

  try {
    new Notification(test ? "測試通知" : "記帳提醒", {
      body: test ? "通知功能已可使用。" : "別忘了記錄今天的花費。",
      icon: "./assets/icon-192.png",
      badge: "./assets/icon-192.png"
    });
  } catch {
    window.alert(test ? "通知功能已可使用。" : "別忘了記錄今天的花費。");
  }
}

function notificationStatusText(permission) {
  if (permission === "unsupported") return "此瀏覽器不支援";
  if (permission === "denied") return "通知被封鎖";
  if (state.settings.reminderEnabled && permission === "granted") return `每天 ${state.settings.reminderTime || "21:00"}`;
  if (permission === "granted") return "已允許";
  return "尚未允許";
}

function nextReminderDate(value) {
  const [hour = "21", minute = "00"] = String(value).split(":");
  const next = new Date();
  next.setHours(Number(hour), Number(minute), 0, 0);
  if (next.getTime() <= Date.now()) next.setDate(next.getDate() + 1);
  return next;
}

function renderHome() {
  const monthItems = currentMonthItems();
  const expenseItems = monthItems.filter((item) => !item.isIncome);
  const incomeItems = monthItems.filter((item) => item.isIncome);
  const expenseTotal = sum(expenseItems);
  const incomeTotal = sum(incomeItems);
  const average = sixMonthAverageExpense();
  const isCurrent = sameMonth(state.selectedMonth, new Date());

  els.homeTitle.textContent = formatMonth(state.selectedMonth);
  els.goCurrentMonth.hidden = isCurrent;
  document.querySelector("[data-month='1']").disabled = isCurrent;
  els.monthExpense.textContent = formatCurrency(expenseTotal);
  els.monthIncome.textContent = formatCurrency(incomeTotal);
  els.currentExpenseLabel.textContent = formatCurrency(expenseTotal);
  els.averageLabel.textContent = average > 0 ? formatCurrency(average) : "無歷史資料";
  els.averageMeter.style.width = `${Math.min(100, average > 0 ? (expenseTotal / average) * 100 : expenseTotal > 0 ? 100 : 0)}%`;
  els.recordCount.textContent = `${monthItems.length} 筆`;

  renderCategoryStrip(expenseItems, expenseTotal);
  renderTransactions(monthItems);
}

function renderCategoryStrip(expenseItems, expenseTotal) {
  const totals = categoryTotals(expenseItems);
  const used = categories
    .filter((category) => category.type === "expense" && totals[category.id] > 0)
    .sort((a, b) => totals[b.id] - totals[a.id]);

  if (!used.length) {
    els.categoryStrip.innerHTML = "";
    return;
  }

  els.categoryStrip.innerHTML = used.map((category) => {
    const pct = expenseTotal > 0 ? Math.round((totals[category.id] / expenseTotal) * 100) : 0;
    return `
      <div class="category-chip">
        <span class="emoji" style="background:${hexToSoft(category.color)}">${category.emoji}</span>
        <span class="name">${escapeHtml(category.name)} · ${pct}%</span>
        <strong>${formatCurrency(totals[category.id])}</strong>
      </div>
    `;
  }).join("");
}

function renderTransactions(items) {
  if (!items.length) {
    els.transactionList.innerHTML = $("#emptyTemplate").innerHTML;
    return;
  }

  els.transactionList.innerHTML = items
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .map((item) => {
      const category = findCategory(item.category);
      const travelCopy = travelAmountCopy(item);
      const subline = `${formatDateTime(item.date)} · ${category.name}${travelCopy ? ` · ${travelCopy}` : ""}`;
      return `
        <button class="transaction-row" type="button" data-id="${escapeAttr(item.id)}" aria-label="${escapeAttr(`${item.note || category.name} ${formatCurrency(item.amount)}`)}">
          <span class="row-icon" style="background:${hexToSoft(category.color)}">${category.emoji}</span>
          <span class="row-main">
            <strong>${escapeHtml(item.note || category.name)}</strong>
            <time class="row-subline">${escapeHtml(subline)}</time>
          </span>
          <span class="row-amount ${item.isIncome ? "income" : "expense"}">${item.isIncome ? "+" : ""}${formatCurrency(item.amount)}</span>
        </button>
      `;
    }).join("");

  $$(".transaction-row").forEach((row) => {
    row.addEventListener("click", () => openEntryDialog(row.dataset.id));
  });
}

function renderStats() {
  els.statsMode.value = state.statsMode;
  const expenseItems = currentMonthItems().filter((item) => !item.isIncome);
  if (state.statsMode === "daily") {
    renderDailyStats(expenseItems);
  } else {
    renderCategoryStats(expenseItems);
  }
}

function renderCategoryStats(expenseItems) {
  const total = sum(expenseItems);
  const totals = categoryTotals(expenseItems);
  const rows = categories
    .filter((category) => category.type === "expense" && totals[category.id] > 0)
    .sort((a, b) => totals[b.id] - totals[a.id]);

  els.statsCount.textContent = rows.length ? `${rows.length} 類` : "";

  if (!rows.length) {
    els.chartCanvas.removeAttribute("role");
    els.chartCanvas.removeAttribute("aria-label");
    els.chartCanvas.innerHTML = $("#emptyTemplate").innerHTML;
    els.statsList.innerHTML = "";
    return;
  }

  els.chartCanvas.setAttribute("role", "img");
  els.chartCanvas.setAttribute("aria-label", `本月支出共 ${formatCurrency(total)}，最高分類為 ${rows[0].name}`);
  els.chartCanvas.innerHTML = renderPieChart(rows, totals, total);

  els.statsList.innerHTML = rows.map((category) => `
    <div class="stats-item">
      <div>
        <strong>${category.emoji} ${escapeHtml(category.name)}</strong>
        <div class="stats-meta">${currentMonthItems().filter((item) => item.category === category.id).length} 筆</div>
      </div>
      <strong>${formatCurrency(totals[category.id])}</strong>
    </div>
  `).join("");
}

function renderPieChart(rows, totals, total) {
  const radius = 72;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;
  const slices = rows.map((category) => {
    const amount = totals[category.id];
    const length = total > 0 ? (amount / total) * circumference : 0;
    const dash = rows.length === 1 ? circumference : Math.max(0.8, length);
    const circle = `
      <circle
        cx="100"
        cy="100"
        r="${radius}"
        stroke="${category.color}"
        stroke-dasharray="${dash} ${circumference - dash}"
        stroke-dashoffset="${-offset}"
        transform="rotate(-90 100 100)"
      ></circle>
    `;
    offset += length;
    return circle;
  }).join("");

  const legend = rows.map((category) => {
    const amount = totals[category.id];
    const pct = Math.round((amount / total) * 100);
    return `
      <div class="pie-legend-item">
        <span class="pie-dot" style="background:${category.color}" aria-hidden="true"></span>
        <strong>${category.emoji} ${escapeHtml(category.name)}</strong>
        <span>${pct}%</span>
      </div>
    `;
  }).join("");

  return `
    <div class="pie-wrap">
      <svg class="pie-chart" viewBox="0 0 200 200" aria-hidden="true">
        <circle cx="100" cy="100" r="${radius}" stroke="var(--border)"></circle>
        ${slices}
        <circle class="pie-hole" cx="100" cy="100" r="48"></circle>
        <text class="pie-caption" x="100" y="88">支出分佈</text>
        <text class="pie-center" x="100" y="106">${escapeHtml(compactCurrency(total))}</text>
      </svg>
      <div class="pie-legend">${legend}</div>
    </div>
  `;
}

function renderDailyStats(expenseItems) {
  const daily = dailyTotals(expenseItems);
  const max = Math.max(...daily.map((item) => item.amount), 0);
  els.statsCount.textContent = daily.length ? `${daily.length} 天` : "";

  if (!daily.length) {
    els.chartCanvas.removeAttribute("role");
    els.chartCanvas.removeAttribute("aria-label");
    els.chartCanvas.innerHTML = $("#emptyTemplate").innerHTML;
    els.statsList.innerHTML = "";
    return;
  }

  els.chartCanvas.setAttribute("role", "img");
  els.chartCanvas.setAttribute("aria-label", `本月共有 ${daily.length} 天支出紀錄，最高單日 ${formatCurrency(max)}`);
  els.chartCanvas.innerHTML = daily.map((day) => {
    const pct = max > 0 ? Math.round((day.amount / max) * 100) : 0;
    return `
      <div class="bar-row">
        <strong>${escapeHtml(day.label)}</strong>
        <span class="bar-track"><span class="bar-fill" style="width:${pct}%;background:var(--primary)"></span></span>
        <span>${formatCurrency(day.amount)}</span>
      </div>
    `;
  }).join("");

  els.statsList.innerHTML = daily.map((day) => `
    <div class="stats-item">
      <div>
        <strong>${escapeHtml(day.label)}</strong>
        <div class="stats-meta">${day.count} 筆</div>
      </div>
      <strong>${formatCurrency(day.amount)}</strong>
    </div>
  `).join("");
}

function openEntryDialog(id = "") {
  const item = state.expenses.find((expense) => expense.id === id);
  const isEditing = Boolean(item);
  resetTransientEntryState();
  els.dialogTitle.textContent = isEditing ? "編輯記錄" : "快速記帳";
  els.entryId.value = item?.id || "";
  state.activeEntryCurrency = item ? (item.currency || "TWD") : activeTravelCurrency();
  els.amountInput.value = item ? trimAmount(item.originalAmount || item.amount) : "";
  els.noteInput.value = item?.note || "";
  els.dateInput.value = toLocalInputValue(item ? new Date(item.date) : new Date());
  setEntryType(item?.isIncome ? "income" : "expense");
  els.categoryInput.value = categoryMatchesType(item?.category, entryType()) ? item.category : defaultCategoryId(entryType());
  els.deleteEntry.hidden = !isEditing;
  renderCategoryPicker();
  renderAmountDisplay();
  renderVoiceStatus();
  renderScanStatus();
  els.dialog.showModal();
}

function closeDialog() {
  stopVoiceRecognition(false);
  els.dialog.close();
  els.entryForm.reset();
  resetTransientEntryState();
}

function resetTransientEntryState() {
  state.voiceTranscript = "";
  state.voiceMessage = "";
  state.scanMessage = "";
  state.isScanning = false;
  state.shouldParseOnStop = false;
  state.activeEntryCurrency = null;
  els.amountError.hidden = true;
  els.receiptInput.value = "";
}

function saveEntry(event) {
  event.preventDefault();
  const enteredAmount = Number(els.amountInput.value.replace(/,/g, ""));
  if (!Number.isFinite(enteredAmount) || enteredAmount <= 0) {
    els.amountError.hidden = false;
    renderAmountDisplay();
    return;
  }

  const id = els.entryId.value || makeId();
  const currency = state.activeEntryCurrency || activeTravelCurrency();
  const rate = twdRateFor(currency);
  const isForeign = currency !== "TWD";
  const convertedAmount = isForeign ? roundMoney(enteredAmount * rate) : enteredAmount;
  const next = {
    id,
    amount: convertedAmount,
    category: els.categoryInput.value,
    note: els.noteInput.value.trim(),
    date: new Date(els.dateInput.value).toISOString(),
    isIncome: entryType() === "income"
  };

  if (isForeign) {
    next.originalAmount = enteredAmount;
    next.currency = currency;
    next.exchangeRate = rate;
    next.travelSessionId = state.settings.travelSessionId || "";
  }

  const index = state.expenses.findIndex((item) => item.id === id);
  if (index >= 0) {
    state.expenses[index] = next;
  } else {
    state.expenses.unshift(next);
  }

  persist();
  closeDialog();
  render();
}

function deleteEntry() {
  const id = els.entryId.value;
  if (!id) return;
  const ok = window.confirm("刪除此筆記錄？");
  if (!ok) return;
  state.expenses = state.expenses.filter((item) => item.id !== id);
  persist();
  closeDialog();
  render();
}

function renderCategoryPicker() {
  const type = entryType();
  if (!categoryMatchesType(els.categoryInput.value, type)) {
    els.categoryInput.value = defaultCategoryId(type);
  }

  const selected = els.categoryInput.value;
  els.categoryGrid.innerHTML = categories
    .filter((category) => category.type === type)
    .map((category) => `
      <button
        class="category-option ${category.id === selected ? "selected" : ""}"
        type="button"
        role="radio"
        aria-checked="${category.id === selected ? "true" : "false"}"
        data-category="${escapeAttr(category.id)}"
        style="--category-color:${category.color};--category-soft:${hexToSoft(category.color)}"
      >
        <span class="category-emoji">${category.emoji}</span>
        <span>${escapeHtml(category.name)}</span>
      </button>
    `).join("");

  $$(".category-option").forEach((button) => {
    button.addEventListener("click", () => {
      els.categoryInput.value = button.dataset.category;
      renderCategoryPicker();
    });
  });
}

function inferCategoryFromNote() {
  const text = els.noteInput.value.trim().toLowerCase();
  if (!text) return;
  const type = entryType();
  const matched = matchCategory(text, type);
  if (matched) {
    els.categoryInput.value = matched.id;
    renderCategoryPicker();
  }
}

function handleCalcKey(key) {
  let value = els.amountInput.value;
  if (key === "delete") {
    value = value.slice(0, -1);
  } else if (key === ".") {
    if (!value.includes(".")) value = value ? `${value}.` : "0.";
  } else if (/^\d$/.test(key)) {
    if (value === "0") {
      value = key;
    } else if (value.length < 10) {
      value += key;
    }
  }

  els.amountInput.value = normalizeAmountText(value);
  els.amountError.hidden = true;
  renderAmountDisplay();
}

function renderAmountDisplay() {
  const amountText = els.amountInput.value;
  const isIncome = entryType() === "income";
  const hasValue = Number(amountText) > 0;
  const currency = state.activeEntryCurrency || activeTravelCurrency();
  const rate = twdRateFor(currency);
  const currencyInfo = currencyInfoFor(currency);
  const amount = Number(amountText);
  els.amountDisplay.textContent = amountText ? formatAmountForDisplay(amountText) : "0";
  els.amountSign.textContent = isIncome ? "+" : "−";
  els.currencySymbol.textContent = currencyInfo.symbol;
  els.amountCard.classList.toggle("income-amount", isIncome);
  els.amountDisplay.style.color = hasValue ? "" : "var(--border)";
  els.saveEntry.disabled = !hasValue;
  els.twdHint.hidden = !(currency !== "TWD" && hasValue);
  els.twdHint.textContent = currency !== "TWD" && hasValue ? `約 ${formatCurrency(amount * rate)} · 1 ${currency} ≈ ${formatTwdRate(rate)}` : "";
}

function handleVoiceTap() {
  if (state.isRecording) {
    stopVoiceRecognition(true);
  } else {
    startVoiceRecognition();
  }
}

function startVoiceRecognition() {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!Recognition) {
    state.voiceMessage = "此瀏覽器暫不支援語音辨識";
    state.voiceTranscript = "";
    renderVoiceStatus();
    return;
  }

  stopVoiceRecognition(false);
  state.voiceTranscript = "";
  state.voiceMessage = "正在聆聽…";
  state.shouldParseOnStop = false;
  state.isRecording = true;

  const recognition = new Recognition();
  recognition.lang = "zh-TW";
  recognition.interimResults = true;
  recognition.continuous = true;

  recognition.onresult = (event) => {
    const transcript = Array.from(event.results)
      .map((result) => result[0]?.transcript || "")
      .join("")
      .trim();
    state.voiceTranscript = transcript;
    state.voiceMessage = transcript || "正在聆聽…";
    renderVoiceStatus();
  };

  recognition.onerror = () => {
    state.voiceMessage = "語音辨識中斷，請再試一次";
    state.isRecording = false;
    renderVoiceStatus();
  };

  recognition.onend = () => {
    const shouldParse = state.shouldParseOnStop;
    state.isRecording = false;
    renderVoiceStatus();
    if (shouldParse) parseVoiceTranscript();
  };

  state.recognition = recognition;
  renderVoiceStatus();
  try {
    recognition.start();
  } catch {
    state.voiceMessage = "語音辨識啟動失敗";
    state.isRecording = false;
    renderVoiceStatus();
  }
}

function stopVoiceRecognition(shouldParse) {
  state.shouldParseOnStop = shouldParse;
  if (!state.recognition) {
    state.isRecording = false;
    if (shouldParse) parseVoiceTranscript();
    return;
  }

  try {
    state.recognition.stop();
  } catch {
    state.isRecording = false;
    if (shouldParse) parseVoiceTranscript();
  }
}

function parseVoiceTranscript() {
  const transcript = state.voiceTranscript.trim();
  if (!transcript) {
    state.voiceMessage = "沒有聽到內容";
    renderVoiceStatus();
    return;
  }

  const amount = extractAmount(transcript);
  const type = inferEntryType(transcript);
  setEntryType(type);
  if (amount) els.amountInput.value = trimAmount(amount);

  const matched = matchCategory(transcript.toLowerCase(), type);
  els.categoryInput.value = matched?.id || defaultCategoryId(type);
  const cleanedNote = cleanVoiceNote(transcript);
  if (cleanedNote) els.noteInput.value = cleanedNote;

  state.voiceMessage = `已解析：${transcript}`;
  renderCategoryPicker();
  renderAmountDisplay();
  renderVoiceStatus();
}

function renderVoiceStatus() {
  els.voiceButton.classList.toggle("recording", state.isRecording);
  els.voiceIcon.textContent = state.isRecording ? "■" : "●";
  els.voiceLabel.textContent = state.isRecording ? "停止" : "語音";
  const message = state.voiceMessage || state.voiceTranscript;
  els.voiceBanner.hidden = !message;
  els.voiceBanner.textContent = message ? `${state.isRecording ? "◌" : "✓"} ${message}` : "";
}

async function handleReceiptInput(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  state.isScanning = true;
  state.scanMessage = "正在辨識收據…";
  renderScanStatus();

  try {
    const result = await detectReceipt(file);
    if (result.amount) {
      els.amountInput.value = trimAmount(result.amount);
      if (!els.noteInput.value.trim()) els.noteInput.value = result.note || "掃描收據";
      const matched = matchCategory(`${result.note || ""} ${file.name}`.toLowerCase(), entryType());
      if (matched) els.categoryInput.value = matched.id;
      state.scanMessage = `已帶入金額 ${formatCurrency(result.amount)}`;
    } else {
      state.scanMessage = result.message || "未辨識到金額，請手動輸入";
    }
  } catch {
    state.scanMessage = "掃描失敗，請手動輸入";
  } finally {
    state.isScanning = false;
    els.receiptInput.value = "";
    renderCategoryPicker();
    renderAmountDisplay();
    renderScanStatus();
  }
}

async function detectReceipt(file) {
  if (!("BarcodeDetector" in window) || !("createImageBitmap" in window)) {
    return { amount: extractAmount(file.name), note: "掃描收據", message: "此瀏覽器暫不支援收據辨識，請手動輸入" };
  }

  const supported = await window.BarcodeDetector.getSupportedFormats?.();
  const preferred = ["qr_code", "aztec", "pdf417", "code_128", "ean_13", "ean_8"];
  const formats = Array.isArray(supported) ? preferred.filter((format) => supported.includes(format)) : preferred;
  if (!formats.length) {
    return { amount: extractAmount(file.name), note: "掃描收據", message: "此瀏覽器暫不支援收據辨識，請手動輸入" };
  }

  const detector = new window.BarcodeDetector({ formats });
  const bitmap = await createImageBitmap(file);
  const codes = await detector.detect(bitmap);
  bitmap.close?.();
  const text = codes.map((code) => code.rawValue || "").join(" ");
  const amount = extractReceiptAmount(text) || extractAmount(file.name);
  return {
    amount,
    note: text.includes("**") || /^[A-Z]{2}\d{8}/.test(text) ? "電子發票" : "掃描收據",
    message: amount ? "" : "未辨識到金額，請手動輸入"
  };
}

function renderScanStatus() {
  els.scanBanner.hidden = !state.scanMessage;
  els.scanBanner.textContent = state.scanMessage ? `${state.isScanning ? "◌" : "✓"} ${state.scanMessage}` : "";
}

function entryType() {
  return document.querySelector("input[name='entryType']:checked")?.value || "expense";
}

function setEntryType(type) {
  const target = document.querySelector(`input[name='entryType'][value='${type}']`);
  if (target) target.checked = true;
}

function defaultCategoryId(type) {
  return type === "income" ? "salary" : "food";
}

function categoryMatchesType(id, type) {
  return categories.some((category) => category.id === id && category.type === type);
}

function matchCategory(text, type) {
  return categories.find((category) =>
    category.type === type && category.keywords.some((keyword) => text.includes(keyword.toLowerCase()))
  );
}

function inferEntryType(text) {
  const normalized = text.toLowerCase();
  const incomeWords = ["收入", "薪水", "薪資", "獎金", "入帳", "股利", "利息", "退款", "退費", "收租", "租金", "兼職", "接案", "紅包"];
  return incomeWords.some((word) => normalized.includes(word)) ? "income" : "expense";
}

function extractReceiptAmount(text) {
  if (!text) return null;
  const chunks = text.split(/\s+/).filter(Boolean);
  for (const chunk of chunks) {
    const invoiceAmount = parseTaiwanInvoiceQr(chunk);
    if (invoiceAmount) return invoiceAmount;
  }
  return extractAmount(text);
}

function parseTaiwanInvoiceQr(raw) {
  const value = raw.trim();
  if (!/^[A-Z]{2}\d{8}/.test(value) || value.length < 37) return null;
  const totalHex = value.slice(29, 37);
  if (!/^[0-9a-f]{8}$/i.test(totalHex)) return null;
  const amount = parseInt(totalHex, 16);
  return amount > 0 && amount < 10000000 ? amount : null;
}

function extractAmount(text) {
  const normalized = String(text).replace(/[，,]/g, "");
  const patterns = [
    /(?:NT\$|NTD|TWD|台幣|\$)\s*(\d+(?:\.\d+)?)/i,
    /(?:合計|總計|小計|total|amount)[：:\s]*(\d+(?:\.\d+)?)/i,
    /(\d+(?:\.\d+)?)\s*(?:元|塊|圓)/
  ];
  for (const pattern of patterns) {
    const match = normalized.match(pattern);
    if (match) return Number(match[1]);
  }
  const fallback = normalized.match(/\d+(?:\.\d+)?/);
  return fallback ? Number(fallback[0]) : null;
}

function cleanVoiceNote(text) {
  return text
    .replace(/(?:NT\$|NTD|TWD|台幣|\$)?\s*\d+(?:[，,]\d{3})*(?:\.\d+)?\s*(?:元|塊|圓)?/gi, "")
    .replace(/(?:支出|收入|記一筆|幫我記|記帳|花了|收到|入帳)/g, "")
    .trim();
}

function currentMonthItems() {
  return state.expenses.filter((item) => sameMonth(new Date(item.date), state.selectedMonth));
}

function categoryTotals(items) {
  return items.reduce((acc, item) => {
    const normalized = normalizeCategory(item.category, item.isIncome ? "income" : "expense");
    acc[normalized] = (acc[normalized] || 0) + Number(item.amount || 0);
    return acc;
  }, {});
}

function dailyTotals(items) {
  const map = new Map();
  items.forEach((item) => {
    const date = new Date(item.date);
    const key = `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
    const current = map.get(key) || { date, amount: 0, count: 0 };
    current.amount += Number(item.amount || 0);
    current.count += 1;
    map.set(key, current);
  });

  return Array.from(map.values())
    .sort((a, b) => a.date - b.date)
    .map((item) => ({
      ...item,
      label: new Intl.DateTimeFormat("zh-TW", { month: "numeric", day: "numeric" }).format(item.date)
    }));
}

function sixMonthAverageExpense() {
  let total = 0;
  let months = 0;
  for (let i = 1; i <= 6; i += 1) {
    const month = addMonths(state.selectedMonth, -i);
    const monthTotal = sum(state.expenses.filter((item) => !item.isIncome && sameMonth(new Date(item.date), month)));
    total += monthTotal;
    months += 1;
  }
  return months ? total / months : 0;
}

function sum(items) {
  return items.reduce((total, item) => total + Number(item.amount || 0), 0);
}

function findCategory(id) {
  return categories.find((category) => category.id === id || category.name === id) || categories.find((category) => category.id === "other");
}

function normalizeCategory(value, type = "expense") {
  const found = categories.find((category) => category.id === value || category.name === value);
  if (found) return found.id;
  return type === "income" ? "incomeOther" : "other";
}

function makeId() {
  return crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function startOfMonth(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function addMonths(date, value) {
  return new Date(date.getFullYear(), date.getMonth() + value, 1);
}

function sameMonth(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
}

function formatMonth(date) {
  return new Intl.DateTimeFormat("zh-TW", { year: "numeric", month: "long" }).format(date);
}

function formatDateTime(value) {
  return new Intl.DateTimeFormat("zh-TW", {
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatCurrency(value) {
  return `NT$${new Intl.NumberFormat("zh-TW", {
    maximumFractionDigits: 0
  }).format(value || 0)}`;
}

function formatTwdRate(value) {
  const amount = Number(value) || 0;
  return `NT$${new Intl.NumberFormat("zh-TW", {
    minimumFractionDigits: amount < 1 ? 3 : 0,
    maximumFractionDigits: amount < 1 ? 4 : 2
  }).format(amount)}`;
}

function compactCurrency(value) {
  return `NT$${new Intl.NumberFormat("zh-TW", {
    notation: "compact",
    maximumFractionDigits: 1
  }).format(value || 0)}`;
}

function formatForeignAmount(code, value) {
  const currency = currencyInfoFor(code);
  const digits = ["JPY", "KRW", "VND", "IDR"].includes(currency.code) ? 0 : 2;
  return `${currency.symbol}${new Intl.NumberFormat("zh-TW", {
    maximumFractionDigits: digits,
    minimumFractionDigits: 0
  }).format(value || 0)}`;
}

function travelAmountCopy(item) {
  if (!item.currency || !item.originalAmount) return "";
  return `${formatForeignAmount(item.currency, item.originalAmount)} ≈ ${formatCurrency(item.amount)}`;
}

function currencyInfoFor(code) {
  return travelCurrencies.find((currency) => currency.code === code) || travelCurrencies[0];
}

function currencyLabelText(currency) {
  return `${currency.flag} ${currency.code} ${currency.name}`;
}

function currencyIconMarkup(currency, className = "currency-icon") {
  if (currency.code === "TWD") {
    return `
      <span class="${className} twd-flag" aria-hidden="true">
        <span class="twd-canton"><span class="twd-sun"></span></span>
      </span>
    `;
  }
  return `<span class="${className}" aria-hidden="true">${escapeHtml(currency.flag)}</span>`;
}

function iconMarkup(option) {
  if (option.image) {
    return `<img src="${escapeAttr(option.image)}" alt="" width="40" height="40">`;
  }
  return `<span>${escapeHtml(option.symbol || "i")}</span>`;
}

function selectedConverterCodes() {
  const raw = Array.isArray(state.settings.converterCurrencies)
    ? state.settings.converterCurrencies
    : String(state.settings.converterCurrencies || "").split(",");
  let codes = uniqueCodes(raw.length ? raw : converterDefaultCodes).filter(Boolean);
  if (codes.length < 2) codes = uniqueCodes(converterDefaultCodes);
  if (!codes.includes(state.settings.converterBase)) {
    state.settings.converterBase = codes[0] || "TWD";
  }
  state.settings.converterCurrencies = codes;
  return codes;
}

function uniqueCodes(codes) {
  return Array.from(new Set(codes.map((code) => currencyInfoFor(code).code)));
}

function timeShort(date) {
  return new Intl.DateTimeFormat("zh-TW", {
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

function roundMoney(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

function formatConverterInput(code, value) {
  const digits = ["JPY", "KRW", "VND", "IDR"].includes(currencyInfoFor(code).code) ? 0 : 2;
  return new Intl.NumberFormat("zh-TW", {
    maximumFractionDigits: digits,
    minimumFractionDigits: 0
  }).format(Number(value) || 0);
}

function formatAmountForDisplay(value) {
  const [integer, decimal] = String(value).split(".");
  const formatted = new Intl.NumberFormat("zh-TW").format(Number(integer || 0));
  return decimal !== undefined ? `${formatted}.${decimal}` : formatted;
}

function trimAmount(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return "";
  return Number.isInteger(number) ? String(number) : String(number);
}

function normalizeAmountText(value) {
  let next = value.replace(/[^\d.]/g, "");
  const parts = next.split(".");
  if (parts.length > 2) next = `${parts[0]}.${parts.slice(1).join("")}`;
  next = next.replace(/^0+(?=\d)/, "");
  if (next.startsWith(".")) next = `0${next}`;
  const [integer, decimal] = next.split(".");
  return decimal !== undefined ? `${integer}.${decimal.slice(0, 2)}` : integer;
}

function normalizeConverterText(value) {
  let next = String(value).replace(/[^\d.]/g, "");
  const parts = next.split(".");
  if (parts.length > 2) next = `${parts[0]}.${parts.slice(1).join("")}`;
  next = next.replace(/^0+(?=\d)/, "");
  if (next.startsWith(".")) next = `0${next}`;
  const [integer, decimal] = next.split(".");
  const whole = integer.slice(0, 12);
  return decimal !== undefined ? `${whole}.${decimal.slice(0, 4)}` : whole;
}

function cssEscape(value) {
  return window.CSS?.escape ? CSS.escape(value) : String(value).replace(/["\\]/g, "\\$&");
}

function toLocalInputValue(date) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

function hexToSoft(hex) {
  const value = hex.replace("#", "");
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgb(${r} ${g} ${b} / 15%)`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[char]);
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
}

function loadExpenses() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.map(normalizeExpenseRecord) : [];
  } catch {
    return [];
  }
}

function loadSettings() {
  try {
    const parsed = JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}");
    return normalizeSettings(parsed);
  } catch {
    return normalizeSettings({});
  }
}

function normalizeSettings(value) {
  return {
    theme: validThemeId(value.theme),
    icon: validIconId(value.icon),
    reminderEnabled: Boolean(value.reminderEnabled),
    reminderTime: /^\d{2}:\d{2}$/.test(value.reminderTime || "") ? value.reminderTime : "21:00",
    travelModeEnabled: Boolean(value.travelModeEnabled),
    travelCurrency: currencyInfoFor(value.travelCurrency || "JPY").code,
    travelSessionId: String(value.travelSessionId || ""),
    travelStartedAt: String(value.travelStartedAt || ""),
    converterBase: currencyInfoFor(value.converterBase || "TWD").code,
    converterAmount: normalizeConverterText(String(value.converterAmount || "1000")),
    converterCurrencies: uniqueCodes(Array.isArray(value.converterCurrencies)
      ? value.converterCurrencies
      : String(value.converterCurrencies || converterDefaultCodes.join(",")).split(","))
  };
}

function validThemeId(value) {
  return themeOptions.some((option) => option.id === value) ? value : "pink";
}

function validIconId(value) {
  return iconOptions.some((option) => option.id === value) ? value : "default";
}

function loadTrips() {
  try {
    const parsed = JSON.parse(localStorage.getItem(TRIPS_KEY) || "[]");
    return Array.isArray(parsed) ? parsed.filter((trip) => trip && trip.id) : [];
  } catch {
    return [];
  }
}

function loadRateCache() {
  try {
    const parsed = JSON.parse(localStorage.getItem(RATE_CACHE_KEY) || "{}");
    return {
      ...Object.fromEntries(Object.entries(fallbackTwdRates).map(([code, rate]) => [code, { rate, updatedAt: "", source: "fallback" }])),
      ...parsed
    };
  } catch {
    return Object.fromEntries(Object.entries(fallbackTwdRates).map(([code, rate]) => [code, { rate, updatedAt: "", source: "fallback" }]));
  }
}

function normalizeExpenseRecord(item) {
  const isIncome = Boolean(item.isIncome);
  const normalized = {
    ...item,
    amount: Number(item.amount),
    category: normalizeCategory(item.category, isIncome ? "income" : "expense"),
    isIncome
  };
  if (item.currency && item.currency !== "TWD") {
    normalized.currency = currencyInfoFor(item.currency).code;
    normalized.originalAmount = Number(item.originalAmount || item.amount);
    normalized.exchangeRate = Number(item.exchangeRate || fallbackTwdRates[normalized.currency] || 1);
  }
  return normalized;
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.expenses));
}

function saveSettings() {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(state.settings));
}

function saveTrips() {
  localStorage.setItem(TRIPS_KEY, JSON.stringify(state.trips));
}

function saveRateCache() {
  localStorage.setItem(RATE_CACHE_KEY, JSON.stringify(state.rateCache));
}

function createBackupPayload() {
  return {
    app: "i 記帳 PWA",
    version: 5,
    exportedAt: new Date().toISOString(),
    expenses: state.expenses,
    settings: state.settings,
    trips: state.trips
  };
}

function exportJson() {
  download(`i-expense-backup-${dateStamp()}.json`, JSON.stringify(createBackupPayload(), null, 2), "application/json");
}

async function copyJson() {
  try {
    await navigator.clipboard.writeText(JSON.stringify(createBackupPayload(), null, 2));
    els.dataCount.textContent = "備份已複製";
    window.setTimeout(updateDataManagement, 1600);
  } catch {
    window.alert("複製失敗，請改用匯出備份。");
  }
}

function exportCsv() {
  const rows = [
    ["date", "type", "category", "amount_twd", "currency", "original_amount", "exchange_rate", "note"],
    ...state.expenses.map((item) => [
      item.date,
      item.isIncome ? "income" : "expense",
      findCategory(item.category).name,
      item.amount,
      item.currency || "TWD",
      item.originalAmount || item.amount,
      item.exchangeRate || 1,
      item.note || ""
    ])
  ];
  const csv = rows.map((row) => row.map(csvCell).join(",")).join("\n");
  download(`i-expense-${dateStamp()}.csv`, csv, "text/csv;charset=utf-8");
}

function importJson(event) {
  const file = event.target.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const parsed = JSON.parse(String(reader.result));
      const imported = Array.isArray(parsed) ? parsed : parsed.expenses;
      if (!Array.isArray(imported)) throw new Error("Invalid backup");
      const normalized = imported
        .filter((item) => item && Number(item.amount) > 0 && item.date)
        .map((item) => normalizeExpenseRecord({
          ...item,
          id: item.id || makeId(),
          amount: Number(item.amount),
          category: item.category,
          note: String(item.note || ""),
          date: new Date(item.date).toISOString(),
          isIncome: Boolean(item.isIncome)
        }));
      state.expenses = mergeExpenses(state.expenses, normalized);
      if (!Array.isArray(parsed) && parsed.settings) {
        state.settings = normalizeSettings({ ...state.settings, ...parsed.settings });
        saveSettings();
        applySettings();
        populateCurrencySelects();
      }
      if (!Array.isArray(parsed) && Array.isArray(parsed.trips)) {
        state.trips = mergeTrips(state.trips, parsed.trips);
        saveTrips();
      }
      persist();
      render();
    } catch {
      window.alert("匯入失敗，檔案格式不正確。");
    } finally {
      event.target.value = "";
    }
  };
  reader.readAsText(file);
}

function mergeExpenses(current, imported) {
  const byId = new Map(current.map((item) => [item.id, item]));
  imported.forEach((item) => byId.set(item.id, item));
  return Array.from(byId.values()).sort((a, b) => new Date(b.date) - new Date(a.date));
}

function mergeTrips(current, imported) {
  const byId = new Map(current.map((item) => [item.id, item]));
  imported
    .filter((item) => item && item.id)
    .forEach((item) => byId.set(item.id, item));
  return Array.from(byId.values()).sort((a, b) => new Date(b.endedAt || b.startedAt || 0) - new Date(a.endedAt || a.startedAt || 0));
}

function clearData() {
  const ok = window.confirm("清除所有記帳資料？");
  if (!ok) return;
  state.expenses = [];
  state.trips = [];
  state.settings.travelModeEnabled = false;
  state.settings.travelSessionId = "";
  state.settings.travelStartedAt = "";
  persist();
  saveSettings();
  saveTrips();
  render();
}

function download(filename, content, type) {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function csvCell(value) {
  const text = String(value ?? "");
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function dateStamp() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return;
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js").catch(() => {});
  });
}
