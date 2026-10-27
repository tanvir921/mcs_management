import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_time.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/providers/customer_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';

/// Modal sheet to link an existing customer, create a new customer on the spot,
/// or map to "Guest" (for cash sales).
Future<void> showKhosraCustomerLinkSheet(
  BuildContext context,
  KhosraEntry entry, {
  required bool allowGuest,
}) async {
  final searchCtrl = TextEditingController(
    text: entry.name == 'Walk-in' || entry.name == 'Sale' ? '' : entry.name,
  );
  final newPhoneCtrl = TextEditingController();
  final newAddressCtrl = TextEditingController();
  bool isCreatingNew = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final customerProvider = context.watch<CustomerProvider>();
          final query = searchCtrl.text.trim().toLowerCase();
          final matches = customerProvider.customers.where((c) {
            if (!c.isActive || c.id == 'guest_customer') return false;
            if (query.isEmpty) return true;
            return c.name.toLowerCase().contains(query) ||
                (c.phone?.toLowerCase().contains(query) ?? false);
          }).take(10).toList();

          Future<void> applyCustomer(String customerId, String customerName) async {
            final updatedDetails = <String, dynamic>{
              if (entry.details != null) ...entry.details!,
              'customerName': customerName,
            };
            final updated = entry.copyWith(
              customerId: customerId,
              name: (entry.type == KhosraEntryType.baki ||
                      entry.type == KhosraEntryType.aday ||
                      entry.name == 'Walk-in')
                  ? customerName
                  : entry.name,
              details: updatedDetails,
            );
            await sheetCtx.read<KhosraProvider>().updateEntry(updated);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'গ্রাহক যুক্ত করুন (Link Customer)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (allowGuest)
                        TextButton.icon(
                          onPressed: () =>
                              applyCustomer('guest_customer', 'Guest'),
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: const Text('Guest হিসেবে রাখুন'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: 'গ্রাহকের নাম বা মোবাইল নম্বর খুঁজুন',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (matches.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final c = matches[idx];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (c.phone != null && c.phone!.isNotEmpty)
                                  c.phone!,
                                'বকেয়া: ৳${c.totalDue.toStringAsFixed(0)}',
                              ].join(' • '),
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: () => applyCustomer(c.id, c.name),
                              child: const Text('যুক্ত করুন'),
                            ),
                          );
                        },
                      ),
                    ),
                  const Divider(height: 20),
                  Text(
                    'নতুন গ্রাহক তৈরি করুন ("${searchCtrl.text.trim().isEmpty ? entry.name : searchCtrl.text.trim()}")',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'মোবাইল নম্বর (ঐচ্ছিক)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: newAddressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ঠিকানা (ঐচ্ছিক)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: isCreatingNew
                        ? null
                        : () async {
                            final name = searchCtrl.text.trim().isEmpty
                                ? entry.name.trim()
                                : searchCtrl.text.trim();
                            if (name.isEmpty) return;
                            setSheetState(() => isCreatingNew = true);
                            try {
                              final newId = FirebaseFirestore.instance
                                  .collection('customers')
                                  .doc()
                                  .id;
                              final now = AppTime.utcNow();
                              final newCustomer = Customer(
                                id: newId,
                                name: name,
                                phone: newPhoneCtrl.text.trim().isEmpty
                                    ? null
                                    : newPhoneCtrl.text.trim(),
                                address: newAddressCtrl.text.trim().isEmpty
                                    ? null
                                    : newAddressCtrl.text.trim(),
                                createdAt: now,
                                updatedAt: now,
                                isActive: true,
                              );
                              final customerProvider = sheetCtx
                                  .read<CustomerProvider>();
                              final authProvider = sheetCtx
                                  .read<AuthProvider>();
                              await customerProvider.addCustomer(newCustomer);
                              await authProvider.logAction(
                                action: 'CREATE_CUSTOMER',
                                module: 'Khosra',
                                details:
                                    'Created customer from Khosra Review: $name',
                              );
                              await applyCustomer(newId, name);
                            } finally {
                              if (sheetCtx.mounted) {
                                setSheetState(() => isCreatingNew = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'নতুন গ্রাহক তৈরি ও লিংক করুন (Create & Link)',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

