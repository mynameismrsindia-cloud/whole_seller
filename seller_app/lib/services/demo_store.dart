import '../models/product.dart';

class DemoStore {
  static final products = <Product>[
    Product(id: 'P001', name: 'Basmati Rice', quantity: 98, rate: 50),
    Product(id: 'P002', name: 'Mustard Oil', quantity: 45, rate: 140),
    Product(id: 'P003', name: 'Wheat Flour', quantity: 0, rate: 40),
  ];

  static final sales = <Sale>[
    Sale(
      salesman: 'Rahul',
      userId: 'demo-rahul',
      store: 'Bandel Traders',
      contact: '98765 43210',
      location: 'Bandel, West Bengal',
      productId: 'P001',
      productName: 'Basmati Rice',
      quantity: 2,
      rate: 50,
      createdAt: DateTime(2026, 11, 3, 11, 30),
    ),
  ];

  static void submit({
    required Product product,
    required int quantity,
    required int rate,
    required String salesman,
    required String store,
    required String contact,
    required String location,
  }) {
    if (!product.active || product.quantity <= 0) {
      throw StateError('This product is out of stock.');
    }
    if (quantity <= 0 || quantity > product.quantity) {
      throw StateError('Requested quantity exceeds remaining stock.');
    }
    if (rate < 0) {
      throw StateError('Rate cannot be negative.');
    }
    product.quantity -= quantity;
    sales.insert(
      0,
      Sale(
        salesman: salesman,
        userId: 'demo-rahul',
        store: store,
        contact: contact,
        location: location,
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        rate: rate,
        createdAt: DateTime.now(),
      ),
    );
  }
}
