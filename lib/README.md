# 🏫 Campus Expense Split (QuickSplit)

A cross-platform Flutter application designed for campus students to seamlessly log, split, and optimize shared group expenses. Powered by **Provider** state management and local persistent storage via **Hive**.

---

## 🚀 Features

* **Flexible Expense Splitting Modes**:
  * **Uniform**: Equal split among selected participants.
  * **Specific**: Custom fixed amounts allocated to specific members.
  * **Ratio (%)**: Percentage-based expense distribution.
* **Multi-Payer Support**: Log expenses paid by one or multiple individuals in a single bill.
* **Optimized Debt Path**: Built-in greedy min-cash-flow algorithm that minimizes total bank transfers needed to settle all group debts.
* **Spend Analytics**: Visual category-wise breakdown powered by dynamic pie charts and category summaries.
* **Local Persistence**: Offline-first storage using **Hive** for instant startup and offline capability.
* **Theme Support**: Built-in Light and Dark themes with continuous state persistence.
* **Undoable Actions**: Quick deletion recovery with built-in SnackBar `UNDO` functionality.

---

## 🛠️ Tech Stack

* **Framework**: Flutter (Dart)
* **State Management**: `provider`
* **Local Database**: `hive` & `hive_flutter`
* **Data Visualization**: `fl_chart`
* **Design System**: Material Design 3

---

## 📂 Project Structure

```text
lib/
├── models.dart           # Models for Expense, Participant, Categories, and SplitModes
├── provider.dart         # Hive initialization, state management & settlement algorithms
├── main.dart             # App root and Provider wrapper initialization
└── screens/
    ├── dashboard_screen.dart     # Main tab navigation layout
    ├── landing_page.dart         # Home view with participant management & balance standings
    ├── main_dashboard_view.dart  # Expenses tab listing history & optimized debt path
    ├── analytics_view.dart       # Spend distribution pie chart & category details
    └── add_expense_form.dart     # Modal form for logging multi-payer, multi-mode expenses