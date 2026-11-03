import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../services/demo_store.dart';
import '../services/providers.dart';
import '../widgets/labeled_field.dart';

class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({
    super.key,
    required this.name,
    required this.store,
    required this.contact,
    required this.location,
    required this.onStoreChanged,
    this.products,
    this.onSubmitSale,
  });

  final String name;
  final String store;
  final String contact;
  final String location;
  final void Function(String, String, String) onStoreChanged;
  final List<Product>? products;
  final Future<List<Product>> Function({
    required String requestId,
    required Product product,
    required int quantity,
    required int rate,
    required String store,
    required String contact,
    required String location,
  })?
  onSubmitSale;

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final formKey = GlobalKey<FormState>();
  late final store = TextEditingController(text: widget.store);
  late final contact = TextEditingController(text: widget.contact);
  late final location = TextEditingController(text: widget.location);
  final quantity = TextEditingController();
  final rate = TextEditingController();
  Product? selected;
  List<Product>? _remoteProducts;
  String requestId = const Uuid().v4();
  String? _requestFingerprint;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _remoteProducts = widget.products;
    selected = _availableProducts
        .where((p) => p.active && p.quantity > 0)
        .firstOrNull;
    rate.text = selected?.rate.toString() ?? '';
  }

  @override
  void didUpdateWidget(covariant SalesEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _remoteProducts = widget.products;
      final selectedId = selected?.id;
      selected = _availableProducts
          .where((product) => product.id == selectedId)
          .firstOrNull;
    }
  }

  List<Product> get _availableProducts => _remoteProducts ?? DemoStore.products;

  @override
  void dispose() {
    store.dispose();
    contact.dispose();
    location.dispose();
    quantity.dispose();
    rate.dispose();
    super.dispose();
  }

  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> submit() async {
    if (submitting || formKey.currentState?.validate() != true) return;
    final product = selected;
    final count = int.tryParse(quantity.text.trim());
    final appliedRate = int.tryParse(rate.text.trim());
    if (product == null || !product.active || product.quantity == 0) {
      showMessage('This product is unavailable.');
      return;
    }
    if (count == null || count <= 0) {
      showMessage('Enter a positive whole-number quantity.');
      return;
    }
    if (count > product.quantity) {
      showMessage('Only ${product.quantity} units are remaining.');
      return;
    }
    if (appliedRate == null || appliedRate < 0) {
      showMessage('Enter a valid rate of zero or more.');
      return;
    }
    final fingerprint =
        '${product.id}|$count|$appliedRate|${store.text.trim()}|'
        '${contact.text.trim()}|${location.text.trim()}';
    if (_requestFingerprint != fingerprint) {
      requestId = const Uuid().v4();
      _requestFingerprint = fingerprint;
    }

    setState(() => submitting = true);
    try {
      final submitRemote = widget.onSubmitSale;
      if (submitRemote == null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        DemoStore.submit(
          product: product,
          quantity: count,
          rate: appliedRate,
          salesman: widget.name,
          store: store.text.trim(),
          contact: contact.text.trim(),
          location: location.text.trim(),
        );
      } else {
        _remoteProducts = await submitRemote(
          requestId: requestId,
          product: product,
          quantity: count,
          rate: appliedRate,
          store: store.text.trim(),
          contact: contact.text.trim(),
          location: location.text.trim(),
        );
        selected = _availableProducts
            .where((item) => item.id == product.id)
            .firstOrNull;
        rate.text = selected?.rate.toString() ?? rate.text;
      }
      if (!mounted) return;
      widget.onStoreChanged(
        store.text.trim(),
        contact.text.trim(),
        location.text.trim(),
      );
      quantity.clear();
      requestId = const Uuid().v4();
      _requestFingerprint = null;
      showMessage(
        submitRemote == null ? 'Entry saved in this demo.' : 'Sale submitted.',
      );
    } catch (error) {
      if (mounted) showMessage(appErrorMessage(error));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final salesmanName = widget.name.trim().isEmpty
        ? 'Salesman'
        : widget.name.trim();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFD8F4EB),
                  child: Text(salesmanName.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Salesman · $salesmanName',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: formKey,
              child: Column(
                children: [
                  LabeledField(
                    label: 'Store name',
                    child: TextFormField(
                      key: const Key('store-name'),
                      controller: store,
                      validator: requiredValue,
                    ),
                  ),
                  LabeledField(
                    label: 'Store contact',
                    child: TextFormField(
                      controller: contact,
                      validator: requiredValue,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  LabeledField(
                    label: 'Location',
                    child: TextFormField(
                      controller: location,
                      validator: requiredValue,
                    ),
                  ),
                  LabeledField(
                    label: 'Product',
                    child: DropdownButtonFormField<Product>(
                      initialValue: selected,
                      isExpanded: true,
                      items: _availableProducts
                          .map(
                            (product) => DropdownMenuItem(
                              value: product,
                              enabled: product.active && product.quantity > 0,
                              child: Text(
                                '${product.name} — Remaining: ${product.quantity}'
                                '${product.quantity == 0 ? ' · Unavailable' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (product) => product == null
                          ? 'Select an available product'
                          : null,
                      onChanged: (product) => setState(() {
                        selected = product;
                        rate.text = product?.rate.toString() ?? '';
                      }),
                    ),
                  ),
                  if (selected case final product?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          product.quantity > 0 && product.active
                              ? '${product.quantity} units available'
                              : 'Out of stock',
                          style: TextStyle(
                            color: product.quantity > 0 && product.active
                                ? Colors.green.shade800
                                : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'Quantity',
                          child: TextFormField(
                            key: const Key('seller-quantity'),
                            controller: quantity,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a whole number';
                              }
                              if (parsed > (selected?.quantity ?? 0)) {
                                return 'Exceeds remaining stock';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Rate',
                          child: TextFormField(
                            key: const Key('seller-rate'),
                            controller: rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                            validator: (value) {
                              final parsed = int.tryParse(value?.trim() ?? '');
                              return parsed == null || parsed < 0
                                  ? 'Enter a valid rate'
                                  : null;
                            },
                            decoration: const InputDecoration(prefixText: '₹ '),
                          ),
                        ),
                      ),
                    ],
                  ),
                  LabeledField(
                    label: 'Date & time',
                    child: TextFormField(
                      key: const Key('seller-date'),
                      readOnly: true,
                      initialValue:
                          '${now.day.toString().padLeft(2, '0')} ${_month(now.month)} '
                          '${now.year} · ${_formatTime(now)}',
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('seller-submit'),
                      onPressed: submitting ? null : submit,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit Entry'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _month(int n) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][n - 1];

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')} '
      '${time.hour >= 12 ? 'PM' : 'AM'}';
}
