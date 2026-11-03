import '../models/product.dart';

class DemoStore {
  static final products = <Product>[
    Product(id: 'P001', name: 'Basmati Rice', quantity: 98),
    Product(id: 'P002', name: 'Mustard Oil', quantity: 45),
    Product(id: 'P003', name: 'Wheat Flour', quantity: 0),
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
    Sale(
      salesman: 'Amit',
      userId: 'demo-amit',
      store: 'City Store',
      contact: '98765 12345',
      location: 'Hooghly, West Bengal',
      productId: 'P002',
      productName: 'Mustard Oil',
      quantity: 1,
      rate: 140,
      createdAt: DateTime(2026, 11, 3, 10, 45),
    ),
  ];
}
