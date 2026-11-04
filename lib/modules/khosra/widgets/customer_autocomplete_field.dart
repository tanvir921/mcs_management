import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/providers/customer_provider.dart';
import '../models/khosra_entry.dart';
import '../providers/khosra_provider.dart';

/// Real-time customer autocomplete field that:
/// 1. Watches [CustomerProvider] live and automatically loads customers if empty.
/// 2. Integrates today's intraday pending Khosra customers so new customers entered today
///    are instantly selectable without duplicating records.
/// 3. Uses instantaneous pointer-down tap dispatch so selection NEVER gets aborted by focus changes.
/// 4. Provides clear visual confirmation and easy 1-tap clear/reset.
class CustomerAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? selectedCustomerId;
  final ValueChanged<Customer?> onCustomerSelected;
  final String labelText;
  final String hintText;
  final bool requireExistingCustomer;
  final bool autofocus;

  const CustomerAutocompleteField({
    super.key,
    required this.controller,
    required this.selectedCustomerId,
    required this.onCustomerSelected,
    this.labelText = 'নাম / গ্রাহক (Name / Customer)',
    this.hintText = 'নাম বা মোবাইল নম্বর লিখুন...',
    this.requireExistingCustomer = false,
    this.autofocus = false,
  });

  @override
  State<CustomerAutocompleteField> createState() =>
      _CustomerAutocompleteFieldState();
}

class _CustomerAutocompleteFieldState extends State<CustomerAutocompleteField> {
  Timer? _debounce;
  List<Customer> _matches = [];
  bool _showDropdown = false;
  final FocusNode _focusNode = FocusNode();
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onControllerChanged() {
    final currentText = widget.controller.text;
    if (currentText != _lastText) {
      _lastText = currentText;

      // If user clears the text field, notify parent that selection is cleared
      if (currentText.trim().isEmpty && widget.selectedCustomerId != null) {
        widget.onCustomerSelected(null);
      }

      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _runFilter(currentText);
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _runFilter(widget.controller.text);
    } else {
      // Small safety delay to let in-flight pointer events complete
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _showDropdown = false);
        }
      });
    }
  }

  void _runFilter(String rawQuery) {
    if (!mounted) return;

    final query = rawQuery.trim().toLowerCase();
    final customerProvider = context.read<CustomerProvider>();
    final allRegistered = customerProvider.customers
        .where((c) => c.isActive && c.id != 'guest_customer')
        .toList();

    // Also collect intraday customer names from today's pending khosra entries
    final khosraEntries = context.read<KhosraProvider>().entries;
    final intradayCustomers = <Customer>[];
    final seenNames = <String>{};

    for (final e in khosraEntries) {
      final name = e.name.trim();
      if (name.isEmpty) continue;

      // Skip if already in registered customers by ID or exact name
      final alreadyRegistered = allRegistered.any(
        (c) =>
            c.name.toLowerCase() == name.toLowerCase() ||
            (e.customerId != null && c.id == e.customerId),
      );
      if (alreadyRegistered || seenNames.contains(name.toLowerCase())) continue;

      // Calculate total pending due today for this intraday customer
      int pendingDuePaisa = 0;
      for (final pe in khosraEntries) {
        if (pe.name.trim().toLowerCase() == name.toLowerCase() &&
            (pe.type == KhosraEntryType.baki ||
                (pe.type == KhosraEntryType.sale && pe.duePaisa > 0))) {
          pendingDuePaisa += pe.type == KhosraEntryType.sale
              ? pe.duePaisa
              : pe.amountPaisa;
        }
      }

      seenNames.add(name.toLowerCase());
      final syntheticId = e.customerId ?? 'intraday_${name.toLowerCase().replaceAll(' ', '_')}';
      intradayCustomers.add(
        Customer(
          id: syntheticId,
          name: name,
          phone: e.details?['phone'] as String?,
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
          isActive: true,
          productDue: KhosraMoney.paisaToTaka(pendingDuePaisa),
        ),
      );
    }

    final combinedList = [...allRegistered, ...intradayCustomers];

    if (query.isEmpty) {
      setState(() {
        _matches = widget.requireExistingCustomer
            ? combinedList.take(6).toList()
            : [];
        _showDropdown = _matches.isNotEmpty && _focusNode.hasFocus;
      });
      return;
    }

    final filtered = combinedList
        .where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final phoneMatch = (c.phone ?? '').toLowerCase().contains(query);
          return nameMatch || phoneMatch;
        })
        .take(8)
        .toList();

    setState(() {
      _matches = filtered;
      _showDropdown = filtered.isNotEmpty && _focusNode.hasFocus;
    });
  }

  void _selectCustomer(Customer c) {
    widget.controller.text = c.name;
    _lastText = c.name;
    widget.onCustomerSelected(c);
    setState(() {
      _showDropdown = false;
      _matches = [];
    });
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customerProv, _) {
        // Auto-load if empty
        if (customerProv.customers.isEmpty && !customerProv.isLoading && customerProv.error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) customerProv.loadCustomers();
          });
        }

        final isLinked =
            widget.selectedCustomerId != null &&
            widget.selectedCustomerId!.isNotEmpty;

        final selectedCustomer = customerProv.customers
            .where((c) => c.id == widget.selectedCustomerId)
            .firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: Icon(
                  isLinked ? Icons.verified_user_rounded : Icons.person_search,
                  color: isLinked ? Colors.green.shade700 : Colors.blue.shade700,
                ),
                suffixIcon: widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onCustomerSelected(null);
                          setState(() {
                            _matches = [];
                            _showDropdown = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isLinked ? Colors.green.shade50.withValues(alpha: 0.5) : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            if (isLinked)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.controller.text}${selectedCustomer != null && selectedCustomer.totalDue > 0 ? " • বকেয়া: ৳${selectedCustomer.totalDue.toStringAsFixed(0)}" : ""}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        widget.controller.clear();
                        widget.onCustomerSelected(null);
                        setState(() {
                          _matches = [];
                          _showDropdown = false;
                        });
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
            if (_showDropdown && _matches.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _matches.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _matches[index];
                    final isIntraday = c.id.startsWith('intraday_');

                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _selectCustomer(c),
                      child: Container(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isIntraday ? Colors.amber.shade100 : Colors.blue.shade100,
                            child: Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: isIntraday ? Colors.amber.shade900 : Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isIntraday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'আজকের নতুন',
                                    style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                              if (c.totalDue > 0)
                                'বকেয়া: ৳${c.totalDue.toStringAsFixed(0)}',
                            ].join(' • '),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
