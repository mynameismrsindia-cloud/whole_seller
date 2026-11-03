import 'package:flutter/material.dart';

import '../models/product.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({
    super.key,
    required this.products,
    required this.onAdd,
    required this.onUpdate,
    required this.onRestock,
    required this.onSetActive,
  });

  final List<Product> products;
  final ValueChanged<Product> onAdd;
  final void Function(Product, String) onUpdate;
  final void Function(Product, int) onRestock;
  final void Function(Product, bool) onSetActive;

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute<Product>(builder: (_) => const AddProductScreen()),
    );
    if (!messenger.mounted) return;
    if (product == null) return;
    if (products.any((existing) => existing.id == product.id)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Product ID already exists.')),
      );
      return;
    }
    onAdd(product);
  }

  Future<void> _edit(BuildContext context, Product product) async {
    final updatedName = await showDialog<String>(
      context: context,
      builder: (_) => _EditProductDialog(product: product),
    );
    if (updatedName != null && updatedName.trim().isNotEmpty) {
      onUpdate(product, updatedName.trim());
    }
  }

  Future<void> _adjustStock(BuildContext context, Product product) async {
    final formKey = GlobalKey<FormState>();
    final quantityKey = GlobalKey<FormFieldState<String>>();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${product.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: quantityKey,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Units to add'),
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              return parsed == null || parsed <= 0
                  ? 'Enter a positive whole number'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              final parsedQuantity = int.tryParse(
                quantityKey.currentState?.value?.trim() ?? '',
              );
              if (parsedQuantity == null || parsedQuantity <= 0) return;
              onRestock(product, parsedQuantity);
              Navigator.pop(context);
            },
            child: const Text('Add stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Products',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'No products yet. Add a product to get started.',
                textAlign: TextAlign.center,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product ID')),
                  DataColumn(label: Text('Product name')),
                  DataColumn(label: Text('Remaining')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: products.map((product) {
                  return DataRow(
                    cells: [
                      DataCell(Text(product.id)),
                      DataCell(Text(product.name)),
                      DataCell(
                        Text(
                          '${product.quantity}',
                          style: TextStyle(
                            color: product.quantity == 0 ? Colors.red : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          product.quantity == 0
                              ? 'Out of stock'
                              : product.active
                              ? 'Active'
                              : 'Inactive',
                          style: TextStyle(
                            color: product.active && product.quantity > 0
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Edit product',
                              onPressed: () => _edit(context, product),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Restock',
                              onPressed: () => _adjustStock(context, product),
                              icon: const Icon(
                                Icons.add_box_outlined,
                                color: Color(0xFF00665D),
                              ),
                            ),
                            Switch.adaptive(
                              value: product.active,
                              onChanged: (value) => onSetActive(product, value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    ),
  );
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product});

  final Product product;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product.name);

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Edit ${widget.product.id}'),
    content: Form(
      key: formKey,
      child: TextFormField(
        key: const Key('edit-product-name'),
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Product name'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Product name is required'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('edit-product-save'),
        onPressed: () {
          if (formKey.currentState?.validate() != true) return;
          final updatedName = name.text.trim();
          if (updatedName.isEmpty) return;
          Navigator.pop(context, updatedName);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
