const STORAGE_KEY = "i-expense-pwa-v1";

const categories = [
  { id: "food", name: "餐飲", type: "expense", emoji: "🍜", color: "#e65f63", keywords: ["午餐", "早餐", "晚餐", "飯", "食", "吃", "咖啡", "飲料", "餐廳", "便當", "麵", "超商", "711", "全家", "甜點", "奶茶", "火鍋"] },
  { id: "transport", name: "交通", type: "expense", emoji: "🚗", color: "#2f9c95", keywords: ["捷運", "公車", "計程車", "uber", "taxi", "油費", "停車", "高鐵", "火車", "交通", "加油", "機票", "台鐵", "悠遊"] },
  { id: "shopping", name: "購物", type: "expense", emoji: "🛍️", color: "#3478b8", keywords: ["購物", "買", "衣服", "鞋子", "包包", "3c", "電腦", "手機", "momo", "蝦皮", "網購", "amazon", "ikea", "百貨"] },
  { id: "entertainment", name: "娛樂", type: "expense", emoji: "🎮", color: "#7a65b7", keywords: ["電影", "遊戲", "ktv", "娛樂", "netflix", "旅遊", "玩", "音樂", "書", "展覽", "演唱會", "健身"] },
  { id: "medical", name: "醫療", type: "expense", emoji: "💊", color: "#c85a99", keywords: ["醫院", "藥局", "看病", "醫療", "診所", "藥", "健檢", "牙科", "眼科", "掛號"] },
  { id: "home", name: "居家", type: "expense", emoji: "🏠", color: "#d68a2f", keywords: ["水電", "房租", "家具", "裝潢", "修繕", "家居", "清潔", "網路", "瓦斯", "保險", "管理費"] },
  { id: "other", name: "其他", type: "expense", emoji: "📦", color: "#7b8a86", keywords: [] },
  { id: "salary", name: "薪資", type: "income", emoji: "💰", color: "#238b45", keywords: ["薪水", "薪資", "月薪", "工資", "底薪", "發薪", "入帳", "salary"] },
  { id: "bonus", name: "獎金", type: "income", emoji: "🎁", color: "#3aa35c", keywords: ["獎金", "年終", "績效", "紅包", "禮金", "bonus"] },
  { id: "partTime", name: "兼職", type: "income", emoji: "💼", color: "#3686b8", keywords: ["兼職", "打工", "接案", "freelance", "外快", "副業", "稿費"] },
  { id: "investment", name: "投資", type: "income", emoji: "📈", color: "#7650a8", keywords: ["股票", "股利", "投資", "基金", "利息", "配息", "dividend", "收益"] },
  { id: "incomeOther", name: "其他收入", type: "income", emoji: "💵", color: "#7f9d32", keywords: [] }
];

const state = {
  expenses: loadExpenses(),
  selectedMonth: startOfMonth(new Date()),
  currentTab: "home",
  statsMode: "category",
  deferredInstallPrompt: null
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

const els = {
  todayLabel: $("#todayLabel"),
  homeTitle: $("#homeTitle"),
  goCurrentMonth: $("#goCurrentMonth"),
  monthExpense: $("#monthExpense"),
  monthIncome: $("#monthIncome"),
  monthBalance: $("#monthBalance"),
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
  categoryInput: $("#categoryInput"),
  noteInput: $("#noteInput"),
  dateInput: $("#dateInput"),
  deleteEntry: $("#deleteEntry"),
  installButton: $("#installButton")
};

init();

function init() {
  els.todayLabel.textContent = new Intl.DateTimeFormat("zh-TW", {
    month: "long",
    day: "numeric",
    weekday: "long"
  }).format(new Date());

  bindEvents();
  hydrateCategoryOptions("expense");
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
      hydrateCategoryOptions(entryType());
      inferCategoryFromNote();
    });
  });

  els.noteInput.addEventListener("input", inferCategoryFromNote);
  els.entryForm.addEventListener("submit", saveEntry);
  els.deleteEntry.addEventListener("click", deleteEntry);
  els.statsMode.addEventListener("change", () => {
    state.statsMode = els.statsMode.value;
    renderStats();
  });

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
  $$(".tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.tab === state.currentTab));
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
  els.monthBalance.textContent = formatCurrency(incomeTotal - expenseTotal);
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
        <span class="name">${category.name} · ${pct}%</span>
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
        <button class="transaction-row" type="button" data-id="${item.id}">
          <span class="row-icon" style="background:${hexToSoft(category.color)}">${category.emoji}</span>
          <span class="row-main">
            <strong>${escapeHtml(item.note || category.name)}</strong>
            <time>${formatDateTime(item.date)} · ${category.name}</time>
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
    els.chartCanvas.innerHTML = $("#emptyTemplate").innerHTML;
    els.statsList.innerHTML = "";
    return;
  }

  els.chartCanvas.innerHTML = rows.map((category) => {
    const amount = totals[category.id];
    const pct = Math.round((amount / total) * 100);
    return `
      <div class="bar-row">
        <strong>${category.emoji} ${category.name}</strong>
        <span class="bar-track"><span class="bar-fill" style="width:${pct}%;background:${category.color}"></span></span>
        <span>${pct}%</span>
      </div>
    `;
  }).join("");

  els.statsList.innerHTML = rows.map((category) => `
    <div class="stats-item">
      <div>
        <strong>${category.emoji} ${category.name}</strong>
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
    els.chartCanvas.innerHTML = $("#emptyTemplate").innerHTML;
    els.statsList.innerHTML = "";
    return;
  }

  els.chartCanvas.innerHTML = daily.map((day) => {
    const pct = max > 0 ? Math.round((day.amount / max) * 100) : 0;
    return `
      <div class="bar-row">
        <strong>${day.label}</strong>
        <span class="bar-track"><span class="bar-fill" style="width:${pct}%;background:#2f8f83"></span></span>
        <span>${formatCurrency(day.amount)}</span>
      </div>
    `;
  }).join("");

  els.statsList.innerHTML = daily.map((day) => `
    <div class="stats-item">
      <div>
        <strong>${day.label}</strong>
        <div class="stats-meta">${day.count} 筆</div>
      </div>
      <strong>${formatCurrency(day.amount)}</strong>
    </div>
  `).join("");
}

function openEntryDialog(id = "") {
  const item = state.expenses.find((expense) => expense.id === id);
  const isEditing = Boolean(item);
  els.dialogTitle.textContent = isEditing ? "編輯記錄" : "快速記帳";
  els.entryId.value = item?.id || "";
  els.amountInput.value = item ? String(Math.round(item.amount)) : "";
  els.noteInput.value = item?.note || "";
  els.dateInput.value = toLocalInputValue(item ? new Date(item.date) : new Date());
  setEntryType(item?.isIncome ? "income" : "expense");
  hydrateCategoryOptions(entryType());
  els.categoryInput.value = item?.category || defaultCategoryId(entryType());
  els.deleteEntry.hidden = !isEditing;
  els.dialog.showModal();
  setTimeout(() => els.amountInput.focus(), 50);
}

function closeDialog() {
  els.dialog.close();
  els.entryForm.reset();
}

function saveEntry(event) {
  event.preventDefault();
  const amount = Number(els.amountInput.value.replace(/,/g, ""));
  if (!Number.isFinite(amount) || amount <= 0) {
    els.amountInput.focus();
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

function hydrateCategoryOptions(type) {
  els.categoryInput.innerHTML = categories
    .filter((category) => category.type === type)
    .map((category) => `<option value="${category.id}">${category.emoji} ${category.name}</option>`)
    .join("");
}

function inferCategoryFromNote() {
  const text = els.noteInput.value.trim().toLowerCase();
  if (!text) return;
  const type = entryType();
  const matched = categories.find((category) =>
    category.type === type && category.keywords.some((keyword) => text.includes(keyword.toLowerCase()))
  );
  if (matched) els.categoryInput.value = matched.id;
}

function entryType() {
  return document.querySelector("input[name='entryType']:checked").value;
}

function setEntryType(type) {
  document.querySelector(`input[name='entryType'][value='${type}']`).checked = true;
}

function defaultCategoryId(type) {
  return type === "income" ? "salary" : "food";
}

function currentMonthItems() {
  return state.expenses.filter((item) => sameMonth(new Date(item.date), state.selectedMonth));
}

function categoryTotals(items) {
  return items.reduce((acc, item) => {
    acc[item.category] = (acc[item.category] || 0) + Number(item.amount || 0);
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
  return categories.find((category) => category.id === id) || categories.find((category) => category.id === "other");
}

function normalizeCategory(value) {
  return categories.find((category) => category.id === value || category.name === value)?.id || "other";
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

function toLocalInputValue(date) {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

function hexToSoft(hex) {
  const value = hex.replace("#", "");
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgb(${r} ${g} ${b} / 14%)`;
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[char]);
}

function loadExpenses() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state.expenses));
}

function exportJson() {
  const payload = {
    app: "i 記帳 PWA",
    version: 1,
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
        .map((item) => ({
          id: item.id || makeId(),
          amount: Number(item.amount),
          category: normalizeCategory(item.category),
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
