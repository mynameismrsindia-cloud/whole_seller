import 'package:flutter/material.dart';

import '../models/product.dart';
import '../widgets/labeled_field.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final key = GlobalKey<FormState>();
  final id = TextEditingController();
  final name = TextEditingController();
  final quantity = TextEditingController();
  bool active = true;

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  String? validateInteger(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < 0 ? 'Enter a whole number' : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Product')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      label: 'Product ID',
                      child: TextFormField(
                        key: const Key('owner-product-id'),
                        controller: id,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.contains('/')) {
                            return 'Slash is not allowed';
                          }
                          return null;
                        },
                      ),
                    ),
                    LabeledField(
                      label: 'Product name',
                      child: TextFormField(
                        key: const Key('owner-product-name'),
                        controller: name,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    LabeledField(
                      label: 'Quantity',
                      child: TextFormField(
                        key: const Key('owner-product-quantity'),
                        controller: quantity,
                        validator: validateInteger,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: const Text('Active'),
                      onChanged: (value) => setState(() => active = value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        if (key.currentState?.validate() != true) return;
                        final parsedQuantity = int.tryParse(
                          quantity.text.trim(),
                        );
                        final productId = id.text.trim();
                        final productName = name.text.trim();
                        if (parsedQuantity == null ||
                            productId.isEmpty ||
                            productName.isEmpty) {
                          return;
                        }
                        Navigator.pop(
                          context,
                          Product(
                            id: productId,
                            name: productName,
                            quantity: parsedQuantity,
                            active: active,
                          ),
                        );
                      },
                      child: const Text('Save Product'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
