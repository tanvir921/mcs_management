# Wallet Module Flow Diagram

## User Journey: Wallet Creation & Balance Management

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HOME SCREEN                                  │
│  [Customers] [Sales] [Wallets] [Expenses] [Reports]                │
│                           ↓                                          │
│                    Tap "Wallets"                                    │
└─────────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    WALLETS LIST SCREEN                              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 🏦 Bkash Agent                                              │   │
│  │ Perm: ৳5000.00  Temp: ৳2000.00  Total: ৳7000.00            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 🏦 Nagad Agent                                              │   │
│  │ Perm: ৳3000.00  Temp: ৳1000.00  Total: ৳4000.00            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  [+ Create New Wallet]      [🔄 Refresh]                           │
└─────────────────────────────────────────────────────────────────────┘
        ↓ (Tap wallet card)            ↓ (Tap + button)
        │                              │
        ├──────────────────┬───────────┘
        ↓                  ↓
    DETAIL SCREEN   CREATE SCREEN
        │                  │
        └──────────────────┘
        
┌──────────────────────────────────────────────────────────────────────┐
│                  CREATE WALLET SCREEN                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Wallet Type: [Bkash Agent ▼]                                │   │
│  │                                                               │   │
│  │ Initial Permanent Balance:  [____] ৳                        │   │
│  │ Initial Temporary Balance:  [____] ৳                        │   │
│  │                                                               │   │
│  │ [Create Wallet]                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                             ↓ (Submit)
                       Firebase batch write
                             ↓
        ┌────────────────────┬────────────────────┐
        ↓                    ↓                    ↓
    Create wallet      Create initial       Return to
    doc in Firestore   balance history      wallet list
                       records (2)
    
┌──────────────────────────────────────────────────────────────────────┐
│                  WALLET DETAIL SCREEN                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Bkash Agent                                 [🔄 Refresh]     │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │                                                               │   │
│  │ PERMANENT BALANCE                                            │   │
│  │ ৳5000.00                                                    │   │
│  │ [Edit]                                                       │   │
│  │                                                               │   │
│  │ TEMPORARY BALANCE                                            │   │
│  │ ৳2000.00                                                    │   │
│  │ [Edit]                                                       │   │
│  │                                                               │   │
│  │ TOTAL BALANCE                                                │   │
│  │ ৳7000.00                                                    │   │
│  │                                                               │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │ BALANCE HISTORY                                              │   │
│  │ ┌──────────────────────────────────────────────────────────┐ │   │
│  │ │ ↑ ৳500 | PERMANENT | 5000→5500                           │ │   │
│  │ │ Manual adjustment | By: Ahmed | Jan 15, 2:30 PM         │ │   │
│  │ └──────────────────────────────────────────────────────────┘ │   │
│  │ ┌──────────────────────────────────────────────────────────┐ │   │
│  │ │ ↓ ৳500 | TEMPORARY | 2500→2000                           │ │   │
│  │ │ Daily closing | By: System | Jan 14, 11:00 PM           │ │   │
│  │ └──────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
        ↓ (Tap Edit button)
        
┌──────────────────────────────────────────────────────────────────────┐
│              EDIT PERMANENT BALANCE DIALOG                            │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Edit Permanent Balance                                       │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │ Current Balance: ৳5000.00                                    │   │
│  │                                                               │   │
│  │ New Balance: [____] ৳                                        │   │
│  │ Note: [Manual correction, agent request...] (3 lines)       │   │
│  │                                                               │   │
│  │ [Cancel]  [Update]                                           │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
                             ↓ (Submit)
                    Calculate change = new - old
                             ↓
        ┌────────────────────┬───────────────────────┐
        ↓                    ↓                       ↓
    Update wallet       Create balance_history  Close dialog
    in Firestore        record with:
                        - balanceType
                        - previousBalance
                        - newBalance
                        - change
                        - note
                        - changedAt
                        - changedBy
                        - changedByName
```

## Data Flow: Balance Update

```
┌─────────────────────────────────────────────────────────────┐
│              User Edits Balance                             │
│     (Fills new amount + note in dialog)                     │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│         WalletDetailScreen._EditBalanceDialog               │
│  - Gets current balance from widget.wallet                  │
│  - Validates new balance input                              │
│  - Validates note is not empty                              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│            WalletProvider.updateBalance()                   │
│  Parameters:                                                │
│  - walletId                                                 │
│  - balanceType ('permanent' or 'temporary')                 │
│  - newBalance                                               │
│  - note                                                     │
│  - userId                                                   │
│  - userName                                                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│          WalletService.updateBalance()                      │
│  1. Get current wallet                                      │
│  2. Read old balance (permanent or temporary)               │
│  3. Calculate change = newBalance - oldBalance              │
│  4. Create updated wallet with new balance(s)               │
│  5. Create BalanceHistory record                            │
│  6. Firestore batch write (atomic)                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
        ┌──────────────────┬──────────────────┐
        ↓                  ↓                  ↓
    Update wallet    Create balance_history  Success
    doc               doc
    permanentBalance/ change logged with
    temporaryBalance  type indicator
    
                           ↓
┌─────────────────────────────────────────────────────────────┐
│            Reload & Refresh UI                              │
│  - WalletProvider.loadUserWallets()                         │
│  - WalletDetailScreen updates with new balance              │
│  - Balance history ListView refreshes                       │
└─────────────────────────────────────────────────────────────┘
```

## Firestore Collections Structure

```
┌──────────────────────────────────────────────────────────────┐
│ DATABASE: mcs_management (Firebase)                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  📂 wallets/ (Collection)                                    │
│     ├─ wallet_001/                                           │
│     │  ├─ id: "wallet_001"                                   │
│     │  ├─ userId: "user_123"                                 │
│     │  ├─ type: "bkashAgent"                                 │
│     │  ├─ customName: null                                   │
│     │  ├─ permanentBalance: 5000.00                          │
│     │  ├─ temporaryBalance: 2000.00                          │
│     │  ├─ createdAt: 2024-01-15T10:30:00Z                   │
│     │  ├─ updatedAt: 2024-01-15T14:20:00Z                   │
│     │  └─ isActive: true                                     │
│     │                                                        │
│     └─ wallet_002/                                           │
│        ├─ id: "wallet_002"                                   │
│        ├─ userId: "user_123"                                 │
│        ├─ type: "nagadAgent"                                 │
│        ├─ permanentBalance: 3000.00                          │
│        └─ temporaryBalance: 1000.00                          │
│                                                               │
│  📂 balance_history/ (Collection)                            │
│     ├─ history_001/                                          │
│     │  ├─ id: "history_001"                                  │
│     │  ├─ walletId: "wallet_001"                             │
│     │  ├─ balanceType: "permanent"              ← Key field   │
│     │  ├─ previousBalance: 4500.00                           │
│     │  ├─ newBalance: 5000.00                                │
│     │  ├─ change: +500.00                                    │
│     │  ├─ note: "Initial balance setup"                      │
│     │  ├─ changedAt: 2024-01-15T10:30:00Z                   │
│     │  ├─ changedBy: "user_123"                              │
│     │  └─ changedByName: "Ahmed Admin"                       │
│     │                                                        │
│     └─ history_002/                                          │
│        ├─ id: "history_002"                                  │
│        ├─ walletId: "wallet_001"                             │
│        ├─ balanceType: "temporary"              ← Key field   │
│        ├─ previousBalance: 2500.00                           │
│        ├─ newBalance: 2000.00                                │
│        ├─ change: -500.00                                    │
│        ├─ note: "Daily closing deduction"                    │
│        ├─ changedAt: 2024-01-14T23:00:00Z                   │
│        ├─ changedBy: "system"                                │
│        └─ changedByName: "System (Daily Closing)"            │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Balance Calculation Logic

```
When User Creates Wallet:
  wallet.permanentBalance = user_input_permanent
  wallet.temporaryBalance = user_input_temporary
  wallet.totalBalance = permanentBalance + temporaryBalance

When User Edits Permanent Balance:
  change = newBalance - wallet.permanentBalance
  wallet.permanentBalance = newBalance
  wallet.totalBalance = permanentBalance + temporaryBalance
  balanceHistory.balanceType = 'permanent'
  balanceHistory.change = change

When User Edits Temporary Balance:
  change = newBalance - wallet.temporaryBalance
  wallet.temporaryBalance = newBalance
  wallet.totalBalance = permanentBalance + temporaryBalance
  balanceHistory.balanceType = 'temporary'
  balanceHistory.change = change

Example:
  Initial: Perm=5000, Temp=2000, Total=7000
  Edit Perm to 5500: ✓ Perm=5500, Temp=2000, Total=7500
  Edit Temp to 1500: ✓ Perm=5500, Temp=1500, Total=7000
```

## Color Coding (UI)

```
Balance Type Colors:
┌─────────────────────────────────────────────────────────────┐
│ Component               │ Permanent  │ Temporary              │
├─────────────────────────────────────────────────────────────┤
│ Balance Card Background │ Green      │ Orange                │
│ Balance Amount          │ Green      │ Orange                │
│ Edit Button             │ Green      │ Orange                │
│ Badge in History        │ Green bg   │ Orange bg             │
│ Arrow in History        │ ↑/↓        │ ↑/↓ (same as change)  │
└─────────────────────────────────────────────────────────────┘

Change Direction Indicators:
  ↑ Green   = Increase (new balance > old)
  ↓ Red     = Decrease (new balance < old)
  = Grey    = No change (edge case)
```

## Future: Daily Closing Integration

```
┌──────────────────────────────────────────────────────────────┐
│            DAILY CLOSING SERVICE (Future)                    │
│        (Scheduled task, runs 11 PM daily)                   │
└──────────────────────────────────────────────────────────────┘
                           ↓
     Query balance_history with:
     - walletId = each user's wallets
     - balanceType = 'temporary'
     - changedAt >= 2 days ago
                           ↓
     ┌──────────────────────────────────────┐
     │ For each old temporary balance entry: │
     │ 1. Get deduction rules (config)       │
     │ 2. Calculate deduction amount         │
     │ 3. Update wallet.temporaryBalance     │
     │ 4. Create balance_history record      │
     │    (balanceType: 'temporary')         │
     │ 5. Notify user (optional)             │
     └──────────────────────────────────────┘
                           ↓
     Store result in daily_closing_log
     (for audit and reconciliation)
```

## Security & Permissions

```
┌──────────────────────────────────────────────────────────────┐
│                  PERMISSION GATE                             │
├──────────────────────────────────────────────────────────────┤
│ Required Permission: Permission.msfTransactions              │
│                                                               │
│ Who can see Wallets tile on home?                            │
│  → Users with msfTransactions permission                     │
│                                                               │
│ Who can create/edit wallets?                                 │
│  → Authenticated users with msfTransactions permission       │
│                                                               │
│ Audit Trail: Every balance change logged with:               │
│  - User ID                                                   │
│  - User name                                                 │
│  - Timestamp                                                 │
│  - Change amount                                             │
│  - Reason (note)                                             │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/modules/wallet/
├── models/
│   ├── wallet.dart                 (Dual balance model)
│   ├── wallet_type.dart            (10 types + custom)
│   └── wallet_transaction.dart      (BalanceHistory)
│
├── services/
│   └── wallet_service.dart         (CRUD + balance updates)
│
├── providers/
│   └── wallet_provider.dart        (State management)
│
└── screens/
    ├── wallets_screen.dart         (List with dual balance display)
    ├── add_wallet_screen.dart      (Create with init balances)
    ├── wallet_detail_screen.dart   (Detail + edit + history)
    └── (add_wallet_screen is referenced)
```

## Testing Flow

```
Manual Testing:
1. ✓ Create wallet with initial balances
2. ✓ Verify display on list (both balances visible)
3. ✓ Open detail screen
4. ✓ Edit permanent balance → verify history
5. ✓ Edit temporary balance → verify separate history entry
6. ✓ Confirm balances are independent
7. ✓ Check total balance = perm + temp
8. ✓ Review history shows type badge correctly
9. ✓ Verify user name and time on history

Expected Results:
  ✅ Both balances editable independently
  ✅ History shows which balance changed
  ✅ No compile errors
  ✅ Proper error handling
  ✅ Smooth UI transitions
```
