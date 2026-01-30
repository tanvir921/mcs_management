# Inventory System - Visual Guide & Quick Reference

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      HOME SCREEN                                │
│  [Customers] [Sales] [Wallets] [Inventory*] [Reports]          │
│                                   ↑ NEW: Merged Products & Services
└─────────────────────────────────────────────────────────────────┘
                             ↓
                    Tap "Inventory"
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│           INVENTORY LIST SCREEN (Tab Navigation)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📦 Products Tab        |    🤝 Services Tab                    │
│                                                                  │
│  Search Bar: [Search by name or SKU____________] 🔍             │
│                                                                  │
│  Stats Card:                                                    │
│  ├─ Total Items: 25    ├─ Stock: 500    ├─ Margin: 35.2%      │
│                                                                  │
│  Item List:                                                     │
│  ├─ USB Cable (USB-001)          Profit: ৳70 (40%)            │
│  │  SKU: USB-001 | pcs           Stock: 50 units              │
│  │  Cost: ৳50 → Sell: ৳120       [View Details]               │
│  │                                                              │
│  ├─ HDMI Cable (HDMI-001)        Profit: ৳100 (50%)          │
│  │  SKU: HDMI-001 | pcs          Stock: 30 units             │
│  │  Cost: ৳100 → Sell: ৳200      [View Details]              │
│  │                                                              │
│  └─ ... more items                                             │
│                                                                  │
│  [+ Add Product]  (FAB - Type adjusts per tab)                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
        ↓ Tap Item           ↓ Tap [+ Add Product]
        │                    │
        ↓                    ↓
   DETAIL VIEW         ADD INVENTORY SCREEN
```

---

## User Flow - Add Product

```
START
  ↓
┌─────────────────────────────────────┐
│ Select Type:                        │
│ ⚫ Product  |  ○ Service           │
│                                     │
│ (Products have stock tracking)      │
└─────────────────────────────────────┘
  ↓
┌─────────────────────────────────────┐
│ Select/Create Category:             │
│ [Dropdown: Electronics ▼]           │
│          or                         │
│ [✓ Create New Category]             │
│ [Category Name_________]            │
└─────────────────────────────────────┘
  ↓
┌─────────────────────────────────────┐
│ Item Details:                       │
│ Name:        [USB Cable____]        │
│ Description: [High quality___]      │
│ SKU:         [USB-001______]        │
│ Unit:        [pcs_________]         │
│ Cost Price:  [50___________] ৳      │
│ Sell Price:  [120_________] ৳       │
│                                     │
│ ✓ Profit Display:                  │
│   Per Unit: ৳70 (40%)              │
│                                     │
│ Stock (Product only):               │
│ Initial:     [50___________]        │
│                                     │
│ [Cancel]  [Add Product]            │
└─────────────────────────────────────┘
  ↓
✓ SUCCESS
Item added to Firestore
Provider notifies listeners
List updates instantly
```

---

## User Flow - Add Service

```
START
  ↓
┌─────────────────────────────────────┐
│ Select Type:                        │
│ ○ Product  |  ⚫ Service           │
│                                     │
│ (Services don't track stock)        │
└─────────────────────────────────────┘
  ↓
┌─────────────────────────────────────┐
│ Select/Create Category:             │
│ [Dropdown: Repairs ▼]               │
└─────────────────────────────────────┘
  ↓
┌─────────────────────────────────────┐
│ Item Details:                       │
│ Name:        [Phone Screen Repair]  │
│ Description: [Professional repair]  │
│ SKU:         [REPAIR-001__]         │
│ Unit:        [service_____]         │
│ Cost Price:  [100_______] ৳         │
│ Sell Price:  [350_______] ৳         │
│                                     │
│ ✓ Profit Display:                  │
│   Per Unit: ৳250 (250%)            │
│                                     │
│ ⚠ No Stock Field (not applicable)  │
│                                     │
│ [Cancel]  [Add Service]            │
└─────────────────────────────────────┘
  ↓
✓ SUCCESS
```

---

## Detail View Flow

```
┌──────────────────────────────────────────────────────┐
│ Detail Screen: USB Cable                      [⋮]    │
├──────────────────────────────────────────────────────┤
│                                                      │
│ [Product Badge] (or [Service Badge])               │
│                                                      │
│ Item Information:                                   │
│ ├─ Name:        USB Cable                          │
│ ├─ SKU:         USB-001                            │
│ ├─ Category:    Electronics                        │
│ ├─ Unit:        pcs                                │
│ └─ Description: High quality...                    │
│                                                      │
│ Pricing Information:                                │
│ ├─ Cost Price:           ৳50                       │
│ ├─ Selling Price:        ৳120                      │
│ ├─ Profit per Unit:      ৳70 (green)             │
│ └─ Profit Margin:        40% (green)             │
│                                                      │
│ Stock Information: (Product only)                  │
│ └─ Current Stock: 50                               │
│                                                      │
│ Metadata:                                           │
│ ├─ Created By:   Ahmed (admin)                     │
│ ├─ Created At:   Jan 24, 2026, 10:30              │
│ └─ Updated:      Jan 24, 2026, 15:45              │
│                                                      │
└──────────────────────────────────────────────────────┘

Menu [⋮] Options:
├─ [Edit] → Toggle edit mode
├─ [Update Stock] → Modify quantity (Products only)
└─ [Delete] → Soft delete with confirmation
```

---

## Edit Mode

```
┌──────────────────────────────────────────────────────┐
│ Detail Screen: USB Cable (EDIT MODE)                │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Name:        [USB Cable_________]                   │
│ Description: [High quality...___]                   │
│ Cost Price:  [50______________] ৳                   │
│ Sell Price:  [120_____________] ৳                   │
│ Stock:       [50______________]                     │
│             (if product only)                       │
│                                                      │
│ [Cancel]  [Save Changes]                            │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## Stock Update Dialog

```
┌──────────────────────────────────────────────────────┐
│ Update Stock                                         │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Current Stock: 50                                   │
│                                                      │
│ Quantity to Add/Remove:                             │
│ [5______________]                                   │
│ (Positive = add, Negative = remove)                 │
│                                                      │
│ [Cancel]  [Update]                                  │
│                                                      │
└──────────────────────────────────────────────────────┘

Result: Stock updates from 50 → 55 (or 45)
```

---

## Search & Filter Flow

```
Search Bar:
[Search by name or SKU____________] [Clear ✕]
         ↓
Enter "cable":
         ↓
Real-time filter:
├─ USB Cable (USB-001)
├─ HDMI Cable (HDMI-001)
└─ Ethernet Cable (ETH-001)

Clear search:
         ↓
Full list restored
```

---

## Statistics Calculation

```
When on PRODUCTS Tab:
┌─────────────────────────────────────┐
│ 25 Items    |   500 Units   |   35.2% |
│ (Total)     |   (Total Stock) |   (Margin)|
└─────────────────────────────────────┘

Calculation:
Total Items = Count of active products
Total Stock = Sum of stock quantities
Average Margin = Total Profit / Total Cost * 100

Total Profit = Σ(item.profit * item.stock)
Total Cost = Σ(item.cost * item.stock)


When on SERVICES Tab:
┌─────────────────────────────────────┐
│ 15 Items    |   ----        |   42.1% |
│ (Total)     |   (N/A)       |   (Margin)|
└─────────────────────────────────────┘

No stock shown for services
```

---

## Profit Calculation Examples

### Example 1: Product with Profit
```
Cost Price:    ৳100
Selling Price: ৳250

Profit per Unit = ৳250 - ৳100 = ৳150
Profit % = (150 / 100) × 100 = 150%

If Stock = 50:
Total Profit = ৳150 × 50 = ৳7,500
```

### Example 2: Service with High Margin
```
Cost Price:    ৳200 (includes labor, materials)
Selling Price: ৳1,000

Profit per Unit = ৳1,000 - ৳200 = ৳800
Profit % = (800 / 200) × 100 = 400%
```

### Example 3: Low Profit Product
```
Cost Price:    ৳500
Selling Price: ৳525

Profit per Unit = ৳525 - ৳500 = ৳25
Profit % = (25 / 500) × 100 = 5%
```

---

## Type Behavior Comparison

| Feature | Product | Service |
|---------|---------|---------|
| Has Stock Field | ✓ Yes | ✗ No |
| Stock Management | ✓ Yes | ✗ No |
| Stock Update Option | ✓ Yes | ✗ No |
| Stock in List | ✓ Shows | ✗ Omitted |
| Cost/Selling Price | ✓ Yes | ✓ Yes |
| Profit Calculation | ✓ Yes | ✓ Yes |
| Category | ✓ Yes | ✓ Yes |
| Low Stock Alerts | ✓ Yes | ✗ No |

---

## Database Flow

```
┌──────────────────────────────────────────────────────┐
│ FIRESTORE DATABASE                                   │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Collection: inventory_items                         │
│ ├─ doc: USB-Cable-123                              │
│ │  ├─ userId: user_456                             │
│ │  ├─ category: Electronics                        │
│ │  ├─ name: USB Cable                              │
│ │  ├─ type: "product"                              │
│ │  ├─ costPrice: 50                                │
│ │  ├─ sellingPrice: 120                            │
│ │  ├─ stock: 50                                    │
│ │  ├─ sku: USB-001                                 │
│ │  └─ ... (other fields)                           │
│ │                                                   │
│ └─ doc: Phone-Repair-456                           │
│    ├─ userId: user_456                             │
│    ├─ category: Repairs                            │
│    ├─ name: Phone Screen Repair                    │
│    ├─ type: "service"                              │
│    ├─ costPrice: 100                               │
│    ├─ sellingPrice: 350                            │
│    ├─ stock: 0  (N/A for services)                │
│    └─ ... (other fields)                           │
│                                                      │
│ Collection: inventory_categories                    │
│ ├─ doc: Electronics-123                            │
│ │  ├─ name: Electronics                            │
│ │  ├─ type: "product"                              │
│ │  └─ isActive: true                               │
│ │                                                   │
│ └─ doc: Repairs-456                                │
│    ├─ name: Repairs                                │
│    ├─ type: "service"                              │
│    └─ isActive: true                               │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## Common Scenarios

### Scenario 1: Running Low on Stock
```
1. View Inventory → Products
2. See "USB Cable" with Stock: 5
3. Tap item → Tap [Update Stock]
4. Enter +20 (add 20 units)
5. Stock updates to 25
6. Alert system will notify when stock < 10
```

### Scenario 2: Price Adjustment
```
1. View Inventory → Products
2. Tap "USB Cable"
3. Tap [⋮] → [Edit]
4. Change Selling Price: 120 → 150
5. Profit updates: 70 → 100 (100%)
6. Save Changes
7. Statistics margin updates automatically
```

### Scenario 3: Searching for Item
```
1. Inventory List
2. Type "usb" in search
3. Real-time filter shows:
   - USB Cable
   - USB Hub
   - USB Adapter
4. Clear to reset
```

### Scenario 4: Compare Product vs Service
```
Product: USB Cable
├─ Type: Product
├─ Stock: 50
├─ Profit per unit: ৳70
└─ Total value: ৳3,500

Service: Phone Repair
├─ Type: Service
├─ Stock: (N/A)
├─ Profit per unit: ৳250
└─ Margin: 250%
```

---

## Key Metrics Dashboard

```
PRODUCTS TAB
┌──────────────────────────────────────────────────────┐
│ Statistics Overview                                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Total Items:        25                              │
│  Total Profit Value: ৳25,000                         │
│  Average Stock:      100 units                       │
│  Profit Margin:      35.2%                          │
│  Low Stock Alerts:   3 items                        │
│                                                      │
│  Top Profit Items:                                  │
│  ├─ Item A: ৳500 profit                             │
│  ├─ Item B: ৳450 profit                             │
│  └─ Item C: ৳400 profit                             │
│                                                      │
└──────────────────────────────────────────────────────┘

SERVICES TAB
┌──────────────────────────────────────────────────────┐
│ Statistics Overview                                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Total Services:     15                              │
│  Average Margin:     42.1%                          │
│                                                      │
│  Most Profitable:                                   │
│  ├─ Phone Repair: 400%                             │
│  ├─ Screen Replacement: 380%                       │
│  └─ Battery Service: 350%                          │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## Summary

**One-Click Features:**
✓ Merged Products & Services in single screen
✓ Tab-based navigation (Products | Services)
✓ Real-time profit calculation
✓ Category management built-in
✓ Search by name or SKU
✓ Stock management for products only
✓ Statistics dashboard
✓ Edit, Delete, Restore operations
✓ Soft delete safety

**Result**: Professional inventory management in one unified module!
