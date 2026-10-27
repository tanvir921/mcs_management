import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../customer/models/customer_model.dart';
import '../../customer/providers/customer_provider.dart';

/// Debounced (~200ms) real-time customer autocomplete field using the already-loaded
/// [CustomerProvider.customers] list (no Firestore query per keystroke).
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

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _showDropdown = false);
        }
      });
    } else {
      _runFilter(widget.controller.text);
    }
  }

  void _onTextChanged(String value) {
    // If user edits the text manually after selecting a customer, clear customerId
    // unless it still matches exactly
    if (widget.selectedCustomerId != null) {
      final customers = context.read<CustomerProvider>().customers;
      final existing = customers.where((c) => c.id == widget.selectedCustomerId);
      if (existing.isEmpty ||
          existing.first.name.toLowerCase() != value.trim().toLowerCase()) {
        widget.onCustomerSelected(null);
      }
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _runFilter(value);
    });
  }

  void _runFilter(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    final allCustomers = context
        .read<CustomerProvider>()
        .customers
        .where((c) => c.isActive && c.id != 'guest_customer')
        .toList();

    if (query.isEmpty) {
      setState(() {
        _matches = widget.requireExistingCustomer
            ? allCustomers.take(6).toList()
            : [];
        _showDropdown = _matches.isNotEmpty && _focusNode.hasFocus;
      });
      return;
    }

    final filtered = allCustomers
        .where((c) {
          final nameMatch = c.name.toLowerCase().contains(query);
          final phoneMatch = (c.phone ?? '').toLowerCase().contains(query);
          return nameMatch || phoneMatch;
        })
        .take(6)
        .toList();

    setState(() {
      _matches = filtered;
      _showDropdown = filtered.isNotEmpty && _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLinked =
        widget.selectedCustomerId != null &&
        widget.selectedCustomerId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onChanged: _onTextChanged,
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
            fillColor: isLinked ? Colors.green.shade50 : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        if (_showDropdown && _matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
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
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                      if (c.totalDue > 0)
                        'বকেয়া: ৳${c.totalDue.toStringAsFixed(0)}',
                    ].join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    widget.controller.text = c.name;
                    widget.onCustomerSelected(c);
                    setState(() => _showDropdown = false);
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

