# Sales Module

## Overview
The Sales module provides a comprehensive manual inventory sales tracking system with profit calculation and detailed reporting.

## Features

### Current Features
- ✅ **Manual Sales Entry** - Add sales with multiple items
- ✅ **Item Management** - Each sale item tracks:
  - Item name, quantity, and unit (pcs, kg, ltr, box, set)
  - Cost price and selling price per unit
  - Automatic profit calculation
  - Optional notes per item
- ✅ **Payment Methods** - Support for Cash, Card, Mobile Banking, and Credit
- ✅ **Customer Integration** - Link sales to existing customers or walk-in sales
- ✅ **Sales History** - View all sales with filtering by date range
- ✅ **Statistics Dashboard** - Real-time metrics:
  - Total sales amount
  - Total profit
  - Profit margin percentage
  - Transaction count
  - Average sale value
- ✅ **Detailed Sale View** - Complete sale information with item breakdown
- ✅ **Auto-generated Sale Numbers** - Format: SAL-YYYYMM-XXXX
- ✅ **Soft Delete** - Sales are marked inactive rather than deleted

### Future Enhancements (Ready for Integration)
- 🔜 **Product Integration** - Link items to product database
- 🔜 **Service Integration** - Add service sales alongside products
- 🔜 **Inventory Management** - Auto-deduct stock on sale
- 🔜 **Invoice Generation** - PDF receipts and invoices
- 🔜 **Barcode Scanning** - Quick product selection

## File Structure

```
lib/modules/sales/
├── models/
│   ├── sale.dart           # Main sale model
│   └── sale_item.dart      # Individual sale item model
├── services/
│   └── sales_service.dart  # Firebase operations
├── providers/
│   └── sales_provider.dart # State management
└── screens/
    ├── sales_list_screen.dart    # List view with stats
    ├── add_sale_screen.dart      # Create new sale
    └── sale_detail_screen.dart   # View sale details
```

## Data Models

### Sale
- Sale number (auto-generated)
- Sale date & time
- Payment method
- Customer info (optional)
- List of items
- Calculated totals (cost, selling, profit)
- Created by & timestamp
- Notes

### SaleItem
- Item name
- Quantity & unit
- Cost price & selling price
- Calculated totals
- Profit
- Notes

## Usage

### Creating a Sale
1. Navigate to Sales from home screen
2. Tap "New Sale" button
3. Set sale date/time
4. Select payment method
5. Optionally select customer
6. Add items using the dialog:
   - Enter item details
   - Set quantity and unit
   - Enter cost and selling prices
   - Profit is calculated automatically
7. Review totals and save

### Viewing Sales
- Sales list shows recent transactions
- Filter by: Today, This Week, This Month, This Year, or Custom Range
- Statistics card shows key metrics
- Tap any sale to view full details

### Deleting Sales
- Open sale details
- Tap delete icon
- Confirm deletion (soft delete)

## Integration Points

### With Customer Module
- Sales can be linked to customers
- Customer dropdown in sale creation
- Future: Customer purchase history

### Future Product Module
- Items will auto-populate from product database
- Stock will auto-deduct on sale
- Product-level profit tracking

### Future Service Module
- Combined product + service sales
- Service-specific pricing and duration

## Firestore Collection

**Collection:** `sales`

**Security Rules Needed:**
```javascript
match /sales/{saleId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null 
    && (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['master_admin', 'admin']);
}
```

## Permissions
Uses existing `Permission.products` for sales access. Can be customized with dedicated sales permission later.
