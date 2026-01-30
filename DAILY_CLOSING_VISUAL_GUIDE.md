# Daily Closing Workflow - Visual Guide

## Complete System Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HOME SCREEN                                  │
│  [Customers] [Sales] [Wallets] [Daily Closing*] [Reports]          │
│  ★ NEW TILE in orange (deep orange color)                          │
└─────────────────────────────────────────────────────────────────────┘
                             ↓
                      Tap "Daily Closing"
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│              DAILY CLOSING INPUT SCREEN                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  "Enter Today's Hand Cash"                                          │
│                                                                      │
│  Hand Cash (৳):  [2500    ]                                        │
│                                                                      │
│  [Start Daily Closing]                                              │
│                                                                      │
│            ✓ Only manual input required!                            │
│              Everything else auto-calculated                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                             ↓
                   (1-2 seconds loading)
                             ↓
              System Auto-Queries & Calculates:
              ├─ Wallets: ৳8,000 perm + ৳800 temp
              ├─ MSF Today: ৳500
              ├─ Cash Borrow: ৳1,000
              ├─ Expenses: ৳300
              ├─ Yesterday: ৳12,000
              └─ Computes: subtotal, remaining, etc.
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│           DAILY CLOSING REPORT (Draft - Not Saved Yet)              │
├─────────────────────────────────────────────────────────────────────┤
│ 📊 Daily Closing Report                                             │
│    Tuesday, January 24, 2026                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  INCOME COMPONENTS                                                  │
│  ├─ Today's Wallet Balances:    ৳8,000.00 🟢                       │
│  ├─ Today's Hand Cash:          ৳2,500.00 🟢                       │
│  ├─ Today's MSF/Recharge:       ৳500.00  🟢                        │
│  └─ Today's Cash Borrow Due:    ৳1,000.00 🟢                       │
│                                                                      │
│  DEDUCTIONS                                                         │
│  ├─ Today's Expenses:           ৳300.00 🔴                         │
│  └─ Temporary Wallet Balance:   ৳800.00 🔴                         │
│                                                                      │
│  ────────────────────────────────────────────────────────────────  │
│  TODAY'S SUBTOTAL:              ৳11,200.00 🔵                      │
│  ────────────────────────────────────────────────────────────────  │
│                                                                      │
│  COMPARISON WITH YESTERDAY                                          │
│  Yesterday's Subtotal:          ৳10,800.00                          │
│  Today's Subtotal:              ৳11,200.00                          │
│                       ↓                                              │
│  Remaining Cash (Small Sales):  ৳400.00 ✓ (Profit!)               │
│  [Meaning: Extra cash from photocopy, card sales, etc.]            │
│                                                                      │
│  ────────────────────────────────────────────────────────────────  │
│                                                                      │
│  OPTIONAL PROFITS (Tracked Separately - Don't Affect Closing)      │
│  Total Profit: ৳280.00                                             │
│                                                                      │
│  [+ Add Profit Entry]                                               │
│  └─ • Bkash Agent Commission:   ৳200.00                            │
│     • Photocopy Side Income:    ৳50.00                             │
│     • Card Sales:               ৳30.00                             │
│                                                                      │
│  ────────────────────────────────────────────────────────────────  │
│                                                                      │
│  OPTIONAL: DEDUCT PROFIT FROM CLOSING                               │
│  Amount to Reduce: [100]  ৳  (Optional)                             │
│  [Profit deduction helps manage cash flow]                          │
│                                                                      │
│  ────────────────────────────────────────────────────────────────  │
│  FINAL CLOSING BALANCE:         ৳11,100.00 🟢                      │
│  ────────────────────────────────────────────────────────────────  │
│                                                                      │
│  Remarks (Optional):                                                │
│  ┌────────────────────────────────────────────────────────────────┐│
│  │ All balanced correctly. Good day!                               ││
│  └────────────────────────────────────────────────────────────────┘│
│                                                                      │
│  [Cancel]                              [Upload & Save] 💾           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
        ↓ (Tap "Upload & Save")
        │
        └─→ Validation:
            ├─ Hand cash exists? ✓
            ├─ All numbers valid? ✓
            └─ Not already closed? ✓
                        ↓
        ┌───────────────────────────┐
        │  UPLOAD IN PROGRESS...    │
        └───────────────────────────┘
                        ↓
        Saves to daily_closing collection
        Adds ৳280 to reports/profits
        Generates PDF link
        Clears form
                        ↓
        ┌───────────────────────────────────────────┐
        │ ✓ Daily Closing Uploaded Successfully!   │
        │ • Report saved                            │
        │ • Profit added to reports                 │
        │ • PDF generated                           │
        └───────────────────────────────────────────┘
                        ↓
        Returns to INPUT SCREEN (empty form)
                        ↓
        User can:
        ├─ View History [History button]
        └─ Try closing again → Shows "Already closed today ⚠️"
```

---

## Data Query Sequence (Happens in ~1 second)

```
START: User taps "Start Daily Closing"
│
├─ QUERY 1: Wallets Collection
│  └─ collection('wallets')
│     .where('userId', ==, current_user)
│     .where('isActive', ==, true)
│     .get()
│  └─ Returns: List<Wallet>
│     ├─ Extract permanentBalance for each
│     ├─ Extract temporaryBalance for each
│     └─ Sum both separately
│
├─ QUERY 2: Customers & Due Transactions (MSF)
│  └─ For each customer of user:
│     ├─ collection('customers/{id}/due_transactions')
│     ├─ .where('type', ==, 'msfRecharge')
│     ├─ .where('date', >=, today_start)
│     ├─ .where('date', <=, today_end)
│     └─ Sum all amounts
│
├─ QUERY 3: Customers & Due Transactions (Cash Borrow)
│  └─ For each customer of user:
│     ├─ collection('customers/{id}/due_transactions')
│     ├─ .where('type', ==, 'cashBorrow')
│     ├─ .where('date', >=, today_start)
│     ├─ .where('date', <=, today_end)
│     └─ Sum all amounts
│
├─ QUERY 4: Expenses
│  └─ collection('expenses')
│     ├─ .where('userId', ==, current_user)
│     ├─ .where('date', >=, today_start)
│     ├─ .where('date', <=, today_end)
│     └─ Sum all amounts
│
└─ QUERY 5: Yesterday's Daily Closing
   └─ collection('daily_closing')
      ├─ .where('userId', ==, current_user)
      ├─ .where('closingDate', >=, yesterday_start)
      ├─ .where('closingDate', <=, yesterday_end)
      ├─ .limit(1)
      └─ Get: yesterdaySubtotal

CALCULATIONS (Local):
├─ Income = wallets_perm + hand_cash + msf + cash_borrow
├─ Deductions = expenses + temp_wallets
├─ Subtotal = income - deductions
├─ Remaining = subtotal - yesterday_subtotal
└─ Total Profit = sum of profit entries

RESULT: Display all values in UI
```

---

## Profit Entry Process

```
┌──────────────────────────────────────┐
│ OPTIONAL PROFITS SECTION             │
│ Total Profit: ৳280.00 ✓              │
│ [+ Add Profit Entry]                 │
└──────────────────────────────────────┘
              ↓ (User taps +)
              │
        ┌─────────────────────────────────────┐
        │ Add Profit Entry Dialog              │
        ├─────────────────────────────────────┤
        │                                     │
        │ Source:                             │
        │ [Bkash Agent____________]          │
        │                                     │
        │ Amount (৳):                        │
        │ [100_____]                         │
        │                                     │
        │ Note (Optional):                    │
        │ [Monthly commission____]            │
        │                                     │
        │ [Cancel]  [Add]                     │
        │                                     │
        └─────────────────────────────────────┘
              ↓ (User taps Add)
              │
        ✓ Entry Added!
        Report updates:
        ├─ Total Profit: ৳280.00 → ৳380.00
        ├─ New entry shows:
        │  "• Bkash Agent: ৳100.00"
        └─ Final Balance stays: ৳11,200 (not affected!)
              ↓
        User can:
        ├─ Add more entries (+ button again)
        ├─ Continue adjusting
        └─ Upload when satisfied
```

---

## Upload & Save Process

```
┌──────────────────────────────────────┐
│ Upload & Save Button Clicked         │
└──────────────────────────────────────┘
              ↓
        Validation:
        ├─ Hand cash > 0? ✓
        ├─ All numbers valid? ✓
        ├─ Not already closed? ✓
        └─ All checks passed ✓
              ↓
        ┌──────────────────────────────────────────┐
        │ 1️⃣ Save to Firestore: daily_closing      │
        │    ├─ id, userId, closingDate            │
        │    ├─ All income & deduction values      │
        │    ├─ Calculated: subtotal, remaining    │
        │    ├─ profitEntries[] array              │
        │    ├─ deductedProfit, finalBalance       │
        │    ├─ isApproved: true                   │
        │    ├─ isUploaded: true                   │
        │    ├─ approvedBy: current_user_id        │
        │    └─ approvedAt: timestamp              │
        └──────────────────────────────────────────┘
              ↓
        ┌──────────────────────────────────────────┐
        │ 2️⃣ Add to Reports: reports/{uid}/profits  │
        │    ├─ date: today                        │
        │    ├─ amount: totalProfit (280)          │
        │    ├─ closingIds: [closing_id]           │
        │    └─ If exists: add to amount           │
        └──────────────────────────────────────────┘
              ↓
        ┌──────────────────────────────────────────┐
        │ 3️⃣ Generate PDF (placeholder)            │
        │    └─ pdfUrl: https://.../{closing_id}  │
        └──────────────────────────────────────────┘
              ↓
        ┌──────────────────────────────────────────┐
        │ 4️⃣ Clear Form & Show Success             │
        │    ├─ _handCashController.clear()        │
        │    ├─ _deductedProfitController.clear() │
        │    ├─ _remarksController.clear()        │
        │    ├─ _showCalculations = false          │
        │    └─ SnackBar: "✓ Uploaded!"            │
        └──────────────────────────────────────────┘
```

---

## History & Detail View

```
┌──────────────────────────────────────────┐
│ HISTORY VIEW                             │
│ [Menu] Daily Closing [History Button]    │
└──────────────────────────────────────────┘
              ↓
        Lists all uploaded closings
        (Newest first)
              ↓
        ┌────────────────────────────────────────┐
        │ ✓ Tuesday, Jan 24, 2026                │
        │   Balance: ৳11,200.00                  │
        │   Profit: ৳380.00                      │
        │                              [View] →  │
        └────────────────────────────────────────┘
                      ↓ (Tap View)
                      │
        ┌────────────────────────────────────────────────┐
        │ CLOSING DETAIL SCREEN                          │
        │ Jan 24, 2026                    [📥 Download PDF]│
        ├────────────────────────────────────────────────┤
        │                                                 │
        │ SUMMARY                                         │
        │ ├─ Final Balance:        ৳11,200.00           │
        │ ├─ Total Profit:         ৳380.00 🟢           │
        │ └─ Remaining vs Yest:    ৳400.00 🟢           │
        │                                                 │
        │ INCOME BREAKDOWN                                │
        │ ├─ Wallet Balances:      ৳8,000.00            │
        │ ├─ Hand Cash:            ৳2,500.00            │
        │ ├─ MSF/Recharge:         ৳500.00              │
        │ └─ Cash Borrow Due:      ৳1,000.00            │
        │                                                 │
        │ DEDUCTIONS BREAKDOWN                            │
        │ ├─ Expenses:             -৳300.00             │
        │ └─ Temp Balances:        -৳800.00             │
        │                                                 │
        │ PROFIT ENTRIES                                  │
        │ ├─ Bkash Commission:     ৳200.00              │
        │ ├─ Photocopy:            ৳50.00               │
        │ └─ Card Sales:           ৳30.00               │
        │                                                 │
        │ APPROVAL INFO                                   │
        │ ├─ Approved by:          Ahmed Admin           │
        │ ├─ At:                   Jan 24, 11:35 PM     │
        │ └─ Remarks:              "All balanced ✓"      │
        │                                                 │
        └────────────────────────────────────────────────┘
```

---

## Key Calculation Examples

### Example 1: Good Day
```
Calculation                 Result
─────────────────────────────────────
Wallet Permanent           + ৳10,000
Hand Cash (entered)        + ৳3,000
MSF Today                  + ৳500
Cash Borrow Today          + ৳1,000
                           ─────────
Total Income = ৳14,500

Expenses Today             - ৳400
Temporary Wallets          - ৳600
                           ─────────
Total Deductions = ৳1,000

Subtotal = ৳14,500 - ৳1,000 = ৳13,500

Yesterday = ৳13,000
Remaining = ৳13,500 - ৳13,000 = ৳500 ✓ (Profit!)

Profit Entries = ৳200
Final Balance = ৳13,500
```

### Example 2: Loss Day
```
Subtotal                   = ৳11,000
Yesterday                  = ৳12,000
                           ─────────
Remaining = ৳11,000 - ৳12,000 = -৳1,000 ❌ (Loss!)

Reason: High expenses or high temporary balance
Investigation: Check transaction logs
```

### Example 3: First Day (No Yesterday)
```
Subtotal                   = ৳10,000
Yesterday                  = [None] (First closing ever)
                           ─────────
Remaining = ৳10,000 - ৳0 = ৳0
Message: "First closing (no comparison)"
```

---

## Firestore Structure Visualization

```
┌─────────────────────────────────────────────────────────────┐
│ Firestore Database                                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ Collection: daily_closing/                                 │
│ ├─ Doc: closing_2026_01_24_123456                          │
│ │  ├─ id: "closing_2026_01_24_123456"                      │
│ │  ├─ userId: "user_123"                                   │
│ │  ├─ closingDate: Jan 24, 2026                            │
│ │  ├─ createdAt: Jan 24, 2026, 11:35 PM                   │
│ │  ├─ todaysHandCash: 3000                                 │
│ │  ├─ todaysMSFRecharge: 500                               │
│ │  ├─ todaysCashBorrowDue: 1000                            │
│ │  ├─ todaysExpenses: 400                                  │
│ │  ├─ walletBalancesTotal: 10000                           │
│ │  ├─ temporaryBalancesTotal: 600                          │
│ │  ├─ subtotal: 13500                                      │
│ │  ├─ yesterdaySubtotal: 13000                             │
│ │  ├─ remainingCash: 500                                   │
│ │  ├─ profitEntries:                                       │
│ │  │  ├─ [0]: {source: "Bkash", amount: 200}             │
│ │  │  └─ [1]: {source: "Photocopy", amount: 50}          │
│ │  ├─ totalProfit: 250                                     │
│ │  ├─ deductedProfit: 0                                    │
│ │  ├─ finalClosingBalance: 13500                           │
│ │  ├─ isApproved: true                                     │
│ │  ├─ isUploaded: true                                     │
│ │  ├─ approvedBy: "user_123"                               │
│ │  ├─ approvedAt: Jan 24, 2026, 11:35 PM                 │
│ │  ├─ pdfUrl: "https://reports/.../closing_123.pdf"      │
│ │  └─ remarks: "All balanced correctly"                    │
│ │                                                           │
│ └─ Doc: closing_2026_01_23_234567                          │
│    └─ [Previous day's data...]                             │
│                                                              │
│ Collection: reports/user_123/profits/                      │
│ ├─ Doc: profit_2026_01_24                                  │
│ │  ├─ date: Jan 24, 2026                                   │
│ │  ├─ amount: 250                                          │
│ │  ├─ userId: "user_123"                                   │
│ │  ├─ closingIds: ["closing_2026_01_24_123456"]           │
│ │  ├─ createdAt: Jan 24, 2026, 11:35 PM                  │
│ │  └─ lastUpdated: Jan 24, 2026, 11:35 PM                │
│ │                                                           │
│ └─ Doc: profit_2026_01_23                                  │
│    └─ [Previous day's profit...]                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## State Management Flow

```
┌────────────────────────────────────────┐
│ DailyClosingProvider                   │
├────────────────────────────────────────┤
│                                         │
│ State Variables:                        │
│ ├─ _draftClosing: null → DailyClosing │
│ ├─ _closingHistory: []                 │
│ ├─ _isLoading: false                   │
│ └─ _error: null                        │
│                                         │
│ Getters:                                │
│ ├─ draftClosing → null (starts)        │
│ ├─ closingHistory → []                 │
│ ├─ isLoading → false                   │
│ └─ error → null                        │
│                                         │
└────────────────────────────────────────┘
              ↓
        createDraftClosing()
              ↓
        _draftClosing = new DailyClosing()
        notifyListeners()
              ↓
        UI rebuilds with draft data
              ↓
        updateDeductedProfit() / updateProfitEntries()
              ↓
        _draftClosing = copied with updates
        notifyListeners()
              ↓
        UI updates real-time
              ↓
        saveDailyClosing()
              ↓
        Service saves to DB
        Profit added to reports
        _draftClosing = null
        loadClosingHistory()
        notifyListeners()
              ↓
        UI shows form cleared + history updated
```

---

**Visual Summary**: Complete workflow from home screen through daily closing creation, upload, and history viewing with all calculations happening in real-time.
