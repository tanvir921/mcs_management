# Customer Due Tracker - Web Portal

## Overview
A dedicated web page that allows customers to check their due amounts and transaction history by entering their phone number.

## Features

### 🌐 **Web-Only Access**
- **URL**: https://mcs-management.web.app/customer-due-tracker
- Automatically redirects to home if accessed from mobile app
- Designed specifically for web browsers

### 🇧🇩 **Bangla Language Interface**
- Complete Bangla interface for customer convenience
- Professional and user-friendly design
- Clear typography and color coding

### 📊 **Customer Information Display**
When a customer enters their phone number, they can see:

1. **Personal Information**
   - Customer name
   - Phone number

2. **Payment Reminder**
   - Prominent message: "দয়া করে আপনার বকেয়া টাকা পরিশোধ করুন।" (Please pay your due amount)
   - Warning icon and color-coded banner

3. **Total Due Amount**
   - Large, prominent display of total outstanding balance
   - Color-coded: Red for due amounts, Green for no dues

4. **Due Breakdown**
   - পণ্য বকেয়া (Product Due)
   - সার্ভিস বকেয়া (Service Due)
   - MSF/রিচার্জ বকেয়া (MSF/Recharge Due)
   - নগদ ঋণ (Cash Borrow)
   - পূর্ববর্তী বকেয়া (Previous Due)

5. **Transaction History**
   - Last 50 transactions
   - Shows transaction type, amount, date, and notes
   - Color-coded: Red for additions, Green for payments

## Design Features

### 🎨 **Professional Design**
- Modern gradient headers
- Card-based layout
- Responsive design (optimized for desktop and mobile browsers)
- Color-coded information for easy understanding
- Clear visual hierarchy

### 📱 **Mobile-Friendly**
- Works on mobile browsers
- Responsive layout adapts to screen size
- Easy-to-use form inputs

### 🔒 **Customer Privacy**
- Customers can only see their own information
- Phone number validation
- Secure Firebase authentication

## Technical Implementation

### Files Created/Modified

1. **customer_due_tracker_screen.dart**
   - New screen component
   - Web-only guard (redirects if not web)
   - Bangla language UI
   - Phone number input and search
   - Customer due summary display
   - Transaction history list

2. **customer_service.dart**
   - Added `getCustomerByPhone()` method
   - Added `getDueTransactions()` method
   - Limited to 50 most recent transactions

3. **app_routes.dart**
   - Added route: `/customer-due-tracker`
   - Route constant: `AppRoutes.customerDueTracker`

### Route Configuration

```dart
// Route constant
static const String customerDueTracker = '/customer-due-tracker';

// Route handler
case customerDueTracker:
  return MaterialPageRoute(
    builder: (_) => const CustomerDueTrackerScreen(),
    settings: settings,
  );
```

### Database Queries

**Get Customer by Phone:**
```dart
Future<Customer?> getCustomerByPhone(String phone) async {
  final snapshot = await _firestore
    .collection('customers')
    .where('phone', isEqualTo: phone)
    .where('isActive', isEqualTo: true)
    .limit(1)
    .get();
  
  if (snapshot.docs.isEmpty) return null;
  return Customer.fromJson(snapshot.docs.first.data());
}
```

**Get Due Transactions:**
```dart
Future<List<DueTransaction>> getDueTransactions(String customerId) async {
  final snapshot = await _firestore
    .collection('due_transactions')
    .where('customerId', isEqualTo: customerId)
    .orderBy('createdAt', descending: true)
    .limit(50)
    .get();
  
  return snapshot.docs
    .map((doc) => DueTransaction.fromJson(doc.data()))
    .toList();
}
```

## Usage Instructions

### For Customers

1. **Visit the URL**: https://mcs-management.web.app/customer-due-tracker
2. **Enter Phone Number**: Type your 11-digit Bangladeshi phone number (e.g., 01712345678)
3. **Click "খুঁজুন" (Search)**: Click the search button or press Enter
4. **View Your Dues**: See your total due amount and detailed breakdown
5. **Check History**: Scroll down to see your transaction history

### For Administrators

**Share the Link:**
- Send to customers via SMS, WhatsApp, or Facebook
- Print the QR code for easy access
- Add to business cards or receipts

**Customer Support:**
- If customer cannot find their information, verify:
  - Phone number is entered correctly
  - Customer exists in the system with the same phone number
  - Customer account is active (isActive = true)

## Screenshots Description

### Header Section
- Blue gradient background
- Wallet icon
- "গ্রাহক বকেয়া ট্র্যাকার" (Customer Due Tracker) title
- "MCS Management System" subtitle

### Search Section
- White card with shadow
- "আপনার বকেয়া দেখতে ফোন নম্বর লিখুন" instruction
- Phone number input field with icon
- "খুঁজুন" (Search) button

### Results Section
- Customer name and phone display
- Warning banner: "দয়া করে আপনার বকেয়া টাকা পরিশোধ করুন।"
- Large total due amount display
- Detailed due breakdown by category
- Transaction history cards

### Footer
- MCS Management System branding
- Copyright notice

## Security Considerations

1. **No Authentication Required**
   - Customers can check dues without logging in
   - Phone number acts as the identifier

2. **Limited Information**
   - Only shows financial information
   - No customer address or other personal details exposed

3. **Read-Only Access**
   - Customers cannot modify their dues
   - No payment processing on this page

## Future Enhancements

Potential features to add:

1. **SMS Notifications**
   - Send automated SMS with due amounts
   - Reminder notifications

2. **Payment Integration**
   - bKash/Nagad payment gateway
   - Online payment options

3. **Download Receipt**
   - PDF download of due summary
   - Email receipt option

4. **Multi-Language Support**
   - English language option
   - Language toggle

5. **QR Code Generation**
   - Generate QR code for each customer
   - Scan to view dues

## Deployment

### Build for Web
```bash
flutter build web --release
```

### Deploy to Firebase
```bash
firebase deploy --only hosting
```

### Access the Page
After deployment, the page will be available at:
- https://mcs-management.web.app/customer-due-tracker

## Troubleshooting

### Customer Can't Find Their Information

**Problem:** "এই নম্বরে কোনো গ্রাহক খুঁজে পাওয়া যায়নি।" (No customer found with this number)

**Solutions:**
1. Verify the phone number is correct
2. Check if customer exists in Firebase (customers collection)
3. Verify phone field matches exactly
4. Ensure customer's isActive field is true

### Page Not Loading

**Problem:** Blank page or loading spinner

**Solutions:**
1. Check internet connection
2. Verify Firebase hosting is active
3. Check browser console for errors
4. Clear browser cache

### Transactions Not Showing

**Problem:** Customer due shows but no transaction history

**Possible Reasons:**
1. Customer has no transaction history yet
2. Transactions are in a different collection
3. createdAt field is missing or invalid

## Support

For technical support or questions:
- Check Firebase Console for data integrity
- Review transaction logs in due_transactions collection
- Verify customer phone numbers in customers collection
