# Khosra (`খসড়া`) Firestore Security Rules & Indexes

## 1. Firestore Security Rules Snippet

Add the following rules inside your `match /databases/{database}/documents` block in `firestore.rules` (do **not** overwrite existing collection rules):

```javascript
// Helper functions (reuse if already present in your firestore.rules)
function isSignedIn() {
  return request.auth != null;
}

function getUserData() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
}

function isActiveUser() {
  return isSignedIn() && getUserData().isActive == true;
}

function isMasterAdmin() {
  return isActiveUser() && getUserData().role == 'masterAdmin';
}

function hasKhosraConfirmPermission() {
  return isMasterAdmin() || (
    isActiveUser() &&
    ('khosra' in getUserData().permissions || 'dailyClosing' in getUserData().permissions)
  );
}

// Temporary daily scratch log entries
match /khosra_entries/{entryId} {
  // Any active authenticated staff/admin can read and create pending khosra entries
  allow read: if isActiveUser();

  allow create: if isActiveUser()
    && request.resource.data.status == 'pending'
    && request.resource.data.amountPaisa is int
    && request.resource.data.amountPaisa >= 0;

  // Staff can edit/discard pending or failed entries;
  // only users with khosra confirm permission can transition status to 'committed'
  allow update: if isActiveUser() && (
    (
      resource.data.status != 'committed' &&
      request.resource.data.status in ['pending', 'discarded', 'failed']
    ) || (
      hasKhosraConfirmPermission() &&
      request.resource.data.status == 'committed'
    )
  );

  // Never hard-delete committed entries immediately (keep for audit)
  allow delete: if isMasterAdmin() && resource.data.status != 'committed';
}

// Distributed commit lock to prevent two devices from committing simultaneously
match /khosra_meta/{docId} {
  allow read: if isActiveUser();
  allow write: if hasKhosraConfirmPermission();
}
```

---

## 2. Firestore Indexes & Concurrency Design

### Composite Indexes (`firestore.indexes.json`)
`KhosraStore` queries `khosra_entries` using single-field equality/in filters (`where('businessDate', isEqualTo: ...)` and `where('status', isIn: ['pending', 'failed'])`) and sorts in memory, so it works out-of-the-box with Firestore's automatic single-field indexes. For large datasets, you may optionally add:

```json
{
  "indexes": [
    {
      "collectionGroup": "khosra_entries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "businessDate", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "khosra_entries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "businessDate", "order": "ASCENDING" }
      ]
    }
  ]
}
```

### Multi-Device Commit Lock & Idempotency Choice
We combine **both** a Firestore transaction lock on `khosra_meta/commit_lock` (with a 2-minute TTL expiration so a disconnected device never permanently blocks the shop) **and** a per-entry status check (`status == committed` -> skip) before each entry commit:
1. `khosra_meta/commit_lock` ensures two devices cannot run the day-end batch commit at the same time (preventing sequential `saleNumber` collisions and concurrent customer due balance overwrites).
2. Per-entry status tracking (`pending` -> `committed` / `failed`) ensures that retrying failed entries or double-tapping Confirm never commits an entry twice.

