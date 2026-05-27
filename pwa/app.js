const STORAGE_KEY = "i-expense-pwa-v1";

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

const state = {
  expenses: loadExpenses(),
  selectedMonth: startOfMonth(new Date()),
  currentTab: "home",
  statsMode: "category",
  deferredInstallPrompt: null,
  recognition: null,
  isRecording: false,
  voiceTranscript: "",
  voiceMessage: "",
  shouldParseOnStop: false,
  scanMessage: "",
  isScanning: false
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
  installButton: $("#installButton")
};

init();

function init() {
  els.entryForm.noValidate = true;
  els.todayLabel.textContent = new Intl.DateTimeFormat("zh-TW", {
    month: "long",
    day: "numeric",
    weekday: "long"
  }).format(new Date());

  bindEvents();
  renderCategoryPicker();
  renderAmountDisplay();
  render();
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

  $("#exportJson").addEventListener("click", exportJson);
  $("#exportCsv").addEventListener("click", exportCsv);
  $("#importJson").addEventListener("change", importJson);
  $("#clearData").addEventListener("click", clearData);

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    state.deferredInstallPrompt = event;
    els.installButton.hidden = false;
  });

  els.installButton.addEventListener("click", async () => {
    if (!state.deferredInstallPrompt) return;
    state.deferredInstallPrompt.prompt();
    await state.deferredInstallPrompt.userChoice;
    state.deferredInstallPrompt = null;
    els.installButton.hidden = true;
  });
}

function render() {
  renderHome();
  renderStats();
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
      return `
        <button class="transaction-row" type="button" data-id="${escapeAttr(item.id)}" aria-label="${escapeAttr(`${item.note || category.name} ${formatCurrency(item.amount)}`)}">
          <span class="row-icon" style="background:${hexToSoft(category.color)}">${category.emoji}</span>
          <span class="row-main">
            <strong>${escapeHtml(item.note || category.name)}</strong>
            <time>${formatDateTime(item.date)} · ${escapeHtml(category.name)}</time>
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
  els.chartCanvas.innerHTML = rows.map((category) => {
    const amount = totals[category.id];
    const pct = Math.round((amount / total) * 100);
    return `
      <div class="bar-row">
        <strong>${category.emoji} ${escapeHtml(category.name)}</strong>
        <span class="bar-track"><span class="bar-fill" style="width:${pct}%;background:${category.color}"></span></span>
        <span>${pct}%</span>
      </div>
    `;
  }).join("");

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
        <span class="bar-track"><span class="bar-fill" style="width:${pct}%;background:#d93672"></span></span>
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
  els.amountInput.value = item ? trimAmount(item.amount) : "";
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
  els.amountError.hidden = true;
  els.receiptInput.value = "";
}

function saveEntry(event) {
  event.preventDefault();
  const amount = Number(els.amountInput.value.replace(/,/g, ""));
  if (!Number.isFinite(amount) || amount <= 0) {
    els.amountError.hidden = false;
    renderAmountDisplay();
    return;
  }

  const id = els.entryId.value || makeId();
  const next = {
    id,
    amount,
    category: els.categoryInput.value,
    note: els.noteInput.value.trim(),
    date: new Date(els.dateInput.value).toISOString(),
    isIncome: entryType() === "income"
  };

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
  els.amountDisplay.textContent = amountText ? formatAmountForDisplay(amountText) : "0";
  els.amountSign.textContent = isIncome ? "+" : "−";
  els.amountCard.classList.toggle("income-amount", isIncome);
  els.amountDisplay.style.color = hasValue ? "" : "var(--border)";
  els.saveEntry.disabled = !hasValue;
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
  return new Intl.NumberFormat("zh-TW", {
    style: "currency",
    currency: "TWD",
    maximumFractionDigits: 0
  }).format(value || 0);
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

function normalizeExpenseRecord(item) {
  const isIncome = Boolean(item.isIncome);
  return {
    ...item,
    amount: Number(item.amount),
    category: normalizeCategory(item.category, isIncome ? "income" : "expense"),
    isIncome
  };
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.expenses));
}

function exportJson() {
  const payload = {
    app: "i 記帳 PWA",
    version: 2,
    exportedAt: new Date().toISOString(),
    expenses: state.expenses
  };
  download(`i-expense-backup-${dateStamp()}.json`, JSON.stringify(payload, null, 2), "application/json");
}

function exportCsv() {
  const rows = [
    ["date", "type", "category", "amount", "note"],
    ...state.expenses.map((item) => [
      item.date,
      item.isIncome ? "income" : "expense",
      findCategory(item.category).name,
      item.amount,
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
          id: item.id || makeId(),
          amount: Number(item.amount),
          category: item.category,
          note: String(item.note || ""),
          date: new Date(item.date).toISOString(),
          isIncome: Boolean(item.isIncome)
        }));
      state.expenses = mergeExpenses(state.expenses, normalized);
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

function clearData() {
  const ok = window.confirm("清除所有記帳資料？");
  if (!ok) return;
  state.expenses = [];
  persist();
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
