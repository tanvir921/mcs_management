# Dual Balance Wallet System - Implementation Summary

## Overview
Implemented a dual balance tracking system for wallets, separating **Permanent Balance** (less frequently deducted) from **Temporary Balance** (can be deducted 1-2 days later). This supports future daily-closing workflows and provides granular balance management.

## Architecture

### 1. **Wallet Model** (`lib/modules/wallet/models/wallet.dart`)
Each wallet now tracks two independent balance types:

```dart
class Wallet {
  final double permanentBalance;      // Stable funds, less frequently deducted
  final double temporaryBalance;      // Fluid funds, 1-2 day deduction window
  // ... other fields
  
  double get totalBalance => permanentBalance + temporaryBalance;
}
```

### 2. **Balance History Tracking** (`lib/modules/wallet/models/wallet_transaction.dart`)
Every balance change is recorded with type distinction:

```dart
class BalanceHistory {
  final String balanceType;        // 'permanent' or 'temporary'
  final double previousBalance;    // Balance before change
  final double newBalance;         // Balance after change
  final double change;             // Can be ±
  final String note;               // Reason for change
  final DateTime changedAt;        // When changed
  final String changedBy;          // User ID
  final String changedByName;      // User name
}
```

### 3. **Service Layer** (`lib/modules/wallet/services/wallet_service.dart`)
The `updateBalance()` method handles dual balance updates:

```dart
Future<void> updateBalance({
  required String walletId,
  required String balanceType,     // Specify which balance to update
  required double newBalance,
  required String note,
  required String userId,
  required String userName,
}) async {
  // Updates either permanent or temporary balance
  // Creates audit trail in balance_history collection
  // Uses batch write for consistency
}
```

### 4. **Provider** (`lib/modules/wallet/providers/wallet_provider.dart`)
State management passes balance type through the update chain:

```dart
Future<void> updateBalance({
  required String walletId,
  required String balanceType,
  required double newBalance,
  required String note,
  required String userId,
  required String userName,
}) async {
  // Delegates to service with balanceType parameter
  // Reloads wallet list on success
}
```

## UI Implementation

### **Wallet Creation Screen** (`add_wallet_screen.dart`)
Users initialize both balances when creating a wallet:

```
┌─────────────────────────────────────┐
│ Create Wallet                       │
├─────────────────────────────────────┤
│ Wallet Type: [Bkash Agent ▼]        │
│ Initial Permanent Balance: [0    ]  │
│ Initial Temporary Balance: [0    ]  │
│                                     │
│ [Create Wallet]                     │
└─────────────────────────────────────┘
```

### **Wallet List Screen** (`wallets_screen.dart`)
Displays both balances on each wallet card:

```
┌──────────────────────────────────┐
│ 🏦 Bkash Agent                   │
│ 📊 ৳5000.00 (Perm) ৳2000.00 (Temp)
│ Total: ৳7000.00                  │
└──────────────────────────────────┘
```

### **Wallet Detail Screen** (`wallet_detail_screen.dart`)
Two separate balance editing sections with independent history:

```
┌────────────────────────────────────┐
│ Bkash Agent                        │
├────────────────────────────────────┤
│ PERMANENT BALANCE                  │
│ ৳5000.00  [Edit]                   │
│                                    │
│ TEMPORARY BALANCE                  │
│ ৳2000.00  [Edit]                   │
│                                    │
│ TOTAL BALANCE                      │
│ ৳7000.00                           │
├────────────────────────────────────┤
│ BALANCE HISTORY                    │
│ ↑ ৳500 | Permanent | Manual adjust │
│   5000→5500 | By: Admin | Jan 15   │
│ ↓ ৳200 | Temporary | Daily closing │
│   2000→1800 | By: System | Jan 14  │
└────────────────────────────────────┘
```

### **Edit Balance Dialog** 
Contextual dialog based on balance type:

```
┌──────────────────────────────────┐
│ Edit Permanent Balance           │
├──────────────────────────────────┤
│ Current: ৳5000.00                │
│ New Balance: [5500     ]          │
│ Note: [Manual correction  ] ×3   │
│                                  │
│ [Cancel]  [Update]               │
└──────────────────────────────────┘
```

## Wallet Types Supported (10 + Custom)

| Type | Label | Use Case |
|------|-------|----------|
| `bkashAgent` | Bkash Agent | Digital payment agent |
| `nagadAgent` | Nagad Agent | Digital payment agent |
| `rocketAgent` | Rocket Agent | Digital payment agent |
| `gp1` | GP1 | Telecom partner |
| `gp2` | GP2 | Telecom partner |
| `blRetailer` | BL Retailer | Retail network |
| `bkashMerchant` | Bkash Merchant | Merchant account |
| `nagadB2B` | Nagad B2B | Business-to-business |
| `bkashB2B` | Bkash B2B | Business-to-business |
| `custom` | Custom Wallet | User-defined purpose |

## Database Schema

### `wallets` collection
```json
{
  "id": "wallet_123",
  "userId": "user_456",
  "type": "bkashAgent",
  "customName": null,
  "permanentBalance": 5000.00,
  "temporaryBalance": 2000.00,
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T14:20:00Z",
  "isActive": true
}
```

### `balance_history` collection
```json
{
  "id": "history_789",
  "walletId": "wallet_123",
  "balanceType": "permanent",
  "previousBalance": 5000.00,
  "newBalance": 5500.00,
  "change": 500.00,
  "note": "Manual adjustment",
  "changedAt": "2024-01-15T14:20:00Z",
  "changedBy": "user_456",
  "changedByName": "Ahmed Admin"
}
```

## Integration Points

### **Routes** (`lib/app/app_routes.dart`)
```dart
static const String wallets = '/wallets';

case wallets:
  return MaterialPageRoute(
    builder: (_) => const WalletsScreen(),
  );
```

### **Provider Setup** (`lib/app/app.dart`)
```dart
ChangeNotifierProvider(create: (_) => WalletProvider()),
```

### **Home Screen** (`lib/shared/widgets/home_screen.dart`)
```dart
// Wallet tile with msfTransactions permission gate
_ModuleCard(
  title: 'Wallets',
  icon: Icons.account_balance_wallet,
  onTap: () => Navigator.pushNamed(context, AppRoutes.wallets),
),
```

## Permission Gate
Wallet access requires `Permission.msfTransactions` (inherited from MSF system).

## Future Integration: Daily Closing

The dual balance structure enables future daily-closing workflows:

### Temporary Balance Processing
```dart
// During daily closing (scheduled task)
// For each wallet:
//   1. Identify temporary balance transactions from last 1-2 days
//   2. Apply configured deduction rules
//   3. Create balance_history records with balanceType='temporary'
```

### Permanent Balance Processing
```dart
// Permanent balance changes less frequently
// Manual adjustments, monthly reconciliations
// Still tracked with full audit trail
```

### Example Daily Closing Logic
```dart
// Pseudo-code
for (var wallet in wallets) {
  // Get temporary balance changes from last 2 days
  var tempHistory = balanceHistory
    .where((h) => h.balanceType == 'temporary')
    .where((h) => h.changedAt.isWithin(2.days))
    .toList();
  
  // Apply deduction rules and create new history records
  // Notify user of temporary balance processing
}
```

## Error Handling

All balance updates include:
- **Validation**: Amount > 0, balance type valid
- **Consistency**: Firestore batch writes ensure atomicity
- **Audit Trail**: Every change logged with user info
- **User Feedback**: SnackBar notifications on success/failure

## Testing Considerations

### Manual Testing Checklist
- [ ] Create wallet with initial permanent and temporary balances
- [ ] Edit permanent balance, verify history records type correctly
- [ ] Edit temporary balance, verify separate history entry
- [ ] Total balance = permanent + temporary
- [ ] Balance history displays in reverse chronological order
- [ ] Each history item shows correct change amount (±)
- [ ] User name and timestamp are accurate
- [ ] Wallet list shows both balances with correct colors:
  - Permanent: Green
  - Temporary: Orange

### Automated Testing
```dart
test('updateBalance creates history with correct balanceType', () async {
  await walletService.updateBalance(
    walletId: 'wallet_123',
    balanceType: 'permanent',
    newBalance: 5500,
    note: 'Test',
    userId: 'user_456',
    userName: 'Test User',
  );
  
  final history = await walletService.getBalanceHistory('wallet_123');
  expect(history[0].balanceType, equals('permanent'));
  expect(history[0].change, equals(500));
});
```

## Code Quality
✅ No compile errors  
✅ All imports used  
✅ Proper error handling  
✅ Full audit trail implementation  
✅ Type-safe balance tracking  

## Migration Path (if needed)
If migrating from single-balance system:
```dart
// Set temporary balance = 0, permanent balance = existing balance
wallet.permanentBalance = wallet.balance;
wallet.temporaryBalance = 0;
```

## Summary

The dual balance system is **production-ready** with:
- ✅ Complete model and service implementation
- ✅ Full UI with separate edit buttons per balance type
- ✅ Comprehensive audit trail with type indicators
- ✅ 10 predefined wallet types + custom support
- ✅ Ready for daily-closing integration
- ✅ All errors resolved
- ✅ Proper permission gating
