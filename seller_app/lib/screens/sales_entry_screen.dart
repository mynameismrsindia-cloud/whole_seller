import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
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
    required this.products,
    this.hasMoreProducts = false,
    this.onLoadMoreProducts,
    this.onRefreshProducts,
    required this.onSubmitSale,
    this.onSubmitOrder,
  });

  final String name;
  final String store;
  final String contact;
  final String location;
  final void Function(String, String, String) onStoreChanged;
  final List<Product> products;
  final bool hasMoreProducts;
  final Future<void> Function()? onLoadMoreProducts;
  final Future<void> Function()? onRefreshProducts;
  final Future<List<Product>> Function({
    required String requestId,
    required Product product,
    required int quantity,
    required int rate,
    required String store,
    required String contact,
    required String location,
  })
  onSubmitSale;
  final Future<List<Product>> Function({
    required String requestId,
    required List<Map<String, Object>> items,
    required String store,
    required String contact,
    required String location,
  })?
  onSubmitOrder;

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final formKey = GlobalKey<FormState>();
  late final store = TextEditingController(text: widget.store);
  late final contact = TextEditingController(text: widget.contact);
  late final location = TextEditingController(text: widget.location);
  late List<Product> _products = widget.products;
  final List<_SaleLine> _lines = [];
  int _nextLineId = 0;
  String requestId = const Uuid().v4();
  String? _requestFingerprint;
  bool _showProductValidation = false;
  bool submitting = false;
  bool loadingMoreProducts = false;

  @override
  void initState() {
    super.initState();
    store.addListener(_onFormChanged);
    contact.addListener(_onFormChanged);
    location.addListener(_onFormChanged);
    _lines.add(_createLine());
  }

  @override
  void didUpdateWidget(covariant SalesEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _products = widget.products;
      for (final line in _lines) {
        final selectedId = line.product?.id;
        if (selectedId == null) continue;
        line.product =
            _availableProducts
                .where((product) => product.id == selectedId)
                .firstOrNull ??
            line.product;
      }
    }
  }

  List<Product> get _availableProducts => _products;

  _SaleLine _createLine() {
    final line = _SaleLine(id: _nextLineId++, product: null);
    line.quantity.addListener(_onFormChanged);
    line.rate.addListener(_onFormChanged);
    return line;
  }

  bool get _formReady {
    return _lines.isNotEmpty &&
        _lines.length <= 10 &&
        store.text.trim().isNotEmpty &&
        contact.text.trim().isNotEmpty &&
        location.text.trim().isNotEmpty &&
        _lines.every((line) {
          final product = line.product;
          final count = int.tryParse(line.quantity.text.trim());
          final appliedRate = int.tryParse(line.rate.text.trim());
          return product != null &&
              product.active &&
              product.quantity > 0 &&
              count != null &&
              count > 0 &&
              count <= product.quantity &&
              appliedRate != null &&
              appliedRate >= 0;
        }) &&
        _lines.map((line) => line.product?.id).toSet().length == _lines.length;
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_onFormChanged);
    contact.removeListener(_onFormChanged);
    location.removeListener(_onFormChanged);
    store.dispose();
    contact.dispose();
    location.dispose();
    for (final line in _lines) {
      _disposeLine(line);
    }
    super.dispose();
  }

  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> submit() async {
    if (submitting || formKey.currentState?.validate() != true) return;
    final items = <Map<String, Object>>[];
    for (final line in _lines) {
      final product = line.product;
      final count = int.tryParse(line.quantity.text.trim());
      final appliedRate = int.tryParse(line.rate.text.trim());
      if (product == null || !product.active || product.quantity == 0) {
        showMessage('Every product must be available.');
        return;
      }
      if (count == null || count <= 0) {
        showMessage('Enter a positive whole-number quantity for each product.');
        return;
      }
      if (count > product.quantity) {
        showMessage(
          'Only ${product.quantity} units of ${product.name} remain.',
        );
        return;
      }
      if (appliedRate == null || appliedRate < 0) {
        showMessage('Enter a valid rate for each product.');
        return;
      }
      items.add({
        'productId': product.id,
        'quantity': count,
        'rate': appliedRate,
      });
    }
    final fingerprint =
        '${items.map((item) => item.toString()).join('|')}|'
        '${store.text.trim()}|${contact.text.trim()}|${location.text.trim()}';
    if (_requestFingerprint != fingerprint) {
      requestId = const Uuid().v4();
      _requestFingerprint = fingerprint;
    }

    setState(() => submitting = true);
    try {
      if (items.length == 1) {
        final item = items.single;
        final product = _lines.single.product!;
        _products = await widget.onSubmitSale(
          requestId: requestId,
          product: product,
          quantity: item['quantity']! as int,
          rate: item['rate']! as int,
          store: store.text.trim(),
          contact: contact.text.trim(),
          location: location.text.trim(),
        );
      } else {
        final submitOrder = widget.onSubmitOrder;
        if (submitOrder == null) {
          throw StateError('Multi-product sales are not configured.');
        }
        _products = await submitOrder(
          requestId: requestId,
          items: items,
          store: store.text.trim(),
          contact: contact.text.trim(),
          location: location.text.trim(),
        );
      }
      if (!mounted) return;
      widget.onStoreChanged(
        store.text.trim(),
        contact.text.trim(),
        location.text.trim(),
      );
      for (final line in _lines) {
        _disposeLine(line);
      }
      _lines
        ..clear()
        ..add(_createLine());
      requestId = const Uuid().v4();
      _requestFingerprint = null;
      showMessage('Sale submitted.');
    } catch (error) {
      if (mounted) showMessage(appErrorMessage(error));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  List<Product> _productsFor(_SaleLine line) =>
      _availableProducts
          .where(
            (product) =>
                product.id == line.product?.id ||
                !_lines.any(
                  (other) =>
                      other.id != line.id && other.product?.id == product.id,
                ),
          )
          .toList()
        ..addAll(
          line.product != null &&
                  !_availableProducts.any(
                    (product) => product.id == line.product!.id,
                  )
              ? [line.product!]
              : const [],
        );

  void _addLine() {
    if (_lines.length >= 10) return;
    setState(() {
      _showProductValidation = true;
      _lines.add(_createLine());
    });
  }

  void _removeLine(_SaleLine line) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines.remove(line);
      _disposeLine(line);
    });
  }

  void _disposeLine(_SaleLine line) {
    line.quantity.removeListener(_onFormChanged);
    line.rate.removeListener(_onFormChanged);
    line.quantity.dispose();
    line.rate.dispose();
  }

  Widget _buildSaleLine(_SaleLine line, int index) {
    final products = _productsFor(line);
    final product = line.product;
    return Card(
      key: ValueKey('seller-sale-line-${line.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Product ${index + 1} of 10',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: index == 0
                      ? const Key('seller-add-product')
                      : ValueKey('seller-add-product-${index + 1}'),
                  tooltip: _lines.length >= 10
                      ? 'Maximum 10 products'
                      : 'Add product',
                  onPressed: submitting || _lines.length >= 10
                      ? null
                      : _addLine,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                ),
                if (_lines.length > 1)
                  IconButton(
                    key: ValueKey('seller-remove-product-${index + 1}'),
                    tooltip: 'Remove product',
                    onPressed: submitting ? null : () => _removeLine(line),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.remove),
                  ),
              ],
            ),
            LabeledField(
              label: 'Product',
              child: DropdownButtonFormField<Product>(
                key: index == 0
                    ? const Key('seller-product')
                    : ValueKey('seller-product-${index + 1}'),
                initialValue: product,
                isExpanded: true,
                autovalidateMode: _showProductValidation
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                items: products
                    .map(
                      (candidate) => DropdownMenuItem(
                        value: candidate,
                        enabled: candidate.active && candidate.quantity > 0,
                        child: Text(
                          '${candidate.name} — Remaining: ${candidate.quantity}'
                          '${candidate.quantity == 0 ? ' · Unavailable' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (selected) {
                  if (selected == null) return 'Product is required';
                  if (!selected.active || selected.quantity <= 0) {
                    return 'This product is unavailable';
                  }
                  if (_lines.any(
                    (other) =>
                        other.id != line.id && other.product?.id == selected.id,
                  )) {
                    return 'Select a different product';
                  }
                  return null;
                },
                onChanged: submitting
                    ? null
                    : (selected) => setState(() {
                        line.product = selected;
                        line.rate.text = selected?.rate.toString() ?? '';
                      }),
                hint: const Text('Select a product'),
              ),
            ),
            if (product != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    product.active && product.quantity > 0
                        ? '${product.quantity} units available'
                        : 'Out of stock',
                    style: TextStyle(
                      color: product.active && product.quantity > 0
                          ? Colors.green.shade800
                          : Colors.red,
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Quantity',
                    child: TextFormField(
                      key: index == 0
                          ? const Key('seller-quantity')
                          : ValueKey('seller-quantity-${index + 1}'),
                      controller: line.quantity,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final count = int.tryParse(value?.trim() ?? '');
                        if (count == null || count <= 0) {
                          return 'Enter a whole number';
                        }
                        if (count > (line.product?.quantity ?? 0)) {
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
                      key: index == 0
                          ? const Key('seller-rate')
                          : ValueKey('seller-rate-${index + 1}'),
                      controller: line.rate,
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
          ],
        ),
      ),
    );
  }

  void showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
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
                if (widget.onRefreshProducts != null)
                  IconButton(
                    tooltip: 'Refresh products',
                    onPressed: () async {
                      try {
                        await widget.onRefreshProducts!.call();
                      } catch (error) {
                        if (mounted) showMessage(appErrorMessage(error));
                      }
                    },
                    icon: const Icon(Icons.refresh),
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
                      key: const Key('store-contact'),
                      controller: contact,
                      validator: requiredValue,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  LabeledField(
                    label: 'Location',
                    child: TextFormField(
                      key: const Key('store-location'),
                      controller: location,
                      validator: requiredValue,
                    ),
                  ),
                  if (widget.hasMoreProducts &&
                      widget.onLoadMoreProducts != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: loadingMoreProducts
                            ? null
                            : () async {
                                setState(() => loadingMoreProducts = true);
                                try {
                                  await widget.onLoadMoreProducts!.call();
                                } catch (error) {
                                  if (mounted) {
                                    showMessage(appErrorMessage(error));
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => loadingMoreProducts = false);
                                  }
                                }
                              },
                        child: Text(
                          loadingMoreProducts
                              ? 'Loading products…'
                              : 'Load more products',
                        ),
                      ),
                    ),
                  for (var index = 0; index < _lines.length; index++)
                    _buildSaleLine(_lines[index], index),
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
                      onPressed: submitting || !_formReady ? null : submit,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) {
                            if (states.contains(WidgetState.disabled)) {
                              return const Color(0xFF9E9E9E);
                            }
                            return _formReady
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF9E9E9E);
                          },
                        ),
                        foregroundColor: const WidgetStatePropertyAll(
                          Colors.white,
                        ),
                      ),
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

class _SaleLine {
  _SaleLine({required this.id, required this.product})
    : quantity = TextEditingController(),
      rate = TextEditingController(text: product?.rate.toString() ?? '');

  final int id;
  Product? product;
  final TextEditingController quantity;
  final TextEditingController rate;
}
