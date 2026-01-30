# Customer Management - Complete CRUD Operations

## Overview
The customer management module now has complete CRUD (Create, Read, Update, Delete) operations with full due management functionality.

## Features

### 1. **Customer List Screen** (`customer_list_screen.dart`)
- Displays all active customers
- Shows customer name, phone, total due, and advance deposit
- Tap on any customer to edit
- Floating action button to add new customer
- Pull to refresh functionality
- Empty state when no customers exist
- Error handling with retry option

### 2. **Add Customer Screen** (`add_customer_screen.dart`)
- Create new customers with:
  - Name (required)
  - Phone number (optional)
  - Address (optional)
- Form validation
- Loading state during submission
- Success/error feedback
- Action logging for audit trail
- Auto-navigation back on success

### 3. **Edit Customer Screen** (`edit_customer_screen.dart`)
- Update customer basic information:
  - Name
  - Phone
  - Address
- **Due Management Section** (expandable):
  - Product Due
  - Service Due
  - MSF/Recharge Due
  - Advance Deposit
  - Net Balance calculation (advance - total due)
- Each due type shows:
  - Current amount
  - Color-coded display
  - Tap to add/subtract
- **Due Update Dialog**:
  - Radio buttons for Add/Subtract
  - Amount input field
  - Real-time calculation
  - Validation
- Delete customer option (soft delete)
- Action logging for all operations

### 4. **Backend Services**

#### CustomerService (`customer_service.dart`)
- `createCustomer()` - Add new customer to Firestore
- `updateCustomer()` - Update customer details
- `getCustomerById()` - Fetch single customer
- `getAllCustomers()` - Fetch all customers (with active filter)
- `searchCustomers()` - Search by name or phone
- `updateDue()` - Add/subtract dues by type
- `deleteCustomer()` - Soft delete (sets isActive to false)

#### CustomerProvider (`customer_provider.dart`)
- State management with ChangeNotifier
- Automatic refresh after CRUD operations
- Loading and error states
- Methods:
  - `loadCustomers()` - Fetch customers
  - `addCustomer()` - Create and reload
  - `updateCustomer()` - Update and reload
  - `deleteCustomer()` - Delete and reload
  - `updateDue()` - Update due and reload

## Data Model

```dart
Customer {
  id: String
  name: String
  phone: String?
  address: String?
  createdAt: DateTime
  updatedAt: DateTime
  isActive: bool
  
  // Dues
  productDue: double
  serviceDue: double
  msfRechargeDue: double
  advanceDeposit: double
  
  // Computed
  totalDue: double (sum of all dues)
  netBalance: double (advance - totalDue)
}
```

## Routes

```dart
AppRoutes.customers       // /customers - List screen
AppRoutes.customerAdd     // /customer/add - Add screen
AppRoutes.customerEdit    // /customer/edit - Edit screen (requires Customer argument)
```

## Navigation Flow

```
HomeScreen
  ↓ (Customers card)
CustomerListScreen
  ↓ (+ FAB)                    ↓ (Tap customer)
AddCustomerScreen          EditCustomerScreen
  ↓ (Save)                      ↓ (Update/Delete)
Back to List               Back to List
```

## Action Logging

All operations are logged with:
- Action type: CREATE_CUSTOMER, UPDATE_CUSTOMER, DELETE_CUSTOMER, UPDATE_DUE
- Module: Customer
- Admin who performed the action
- Timestamp
- Details of the operation

## Usage Examples

### Add Customer
1. Go to Customers screen
2. Tap floating "Add Customer" button
3. Fill in name (required), phone, address
4. Tap "Add Customer"
5. Success message appears
6. Returns to customer list

### Edit Customer
1. Tap on any customer in the list
2. Edit name, phone, or address
3. Tap "Update Customer" to save basic info

### Manage Dues
1. In Edit Customer screen
2. Tap "Due Management" to expand
3. Tap on any due type (e.g., "Product Due")
4. Select Add or Subtract
5. Enter amount
6. Tap "Update"
7. Due is updated and net balance recalculated

### Delete Customer
1. In Edit Customer screen
2. Tap delete icon in app bar
3. Confirm deletion
4. Customer is soft-deleted (isActive = false)
5. Returns to customer list

## Color Coding

- **Product Due**: Orange
- **Service Due**: Blue
- **MSF/Recharge Due**: Purple
- **Advance Deposit**: Green
- **Net Balance**: Green (positive) / Red (negative)
- **Total Due**: Red (has due) / Green (no due)

## Validation

- Customer name is required
- Phone and address are optional
- Amount inputs must be valid numbers > 0
- Customer must exist to edit/delete
- All operations validated before Firestore update

## Error Handling

- Network errors caught and displayed
- Validation errors shown in snackbars
- Retry option on load failures
- Loading states prevent double-submission
- Transaction rollback on failures

## Next Steps

Customer management is complete! Ready to implement:
1. MSF Transaction Module
2. Product/Service Management
3. Daily Closing/Reports
4. Transaction History per Customer
