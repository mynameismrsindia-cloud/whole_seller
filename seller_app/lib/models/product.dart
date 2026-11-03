class Product {
  Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.rate,
    this.active = true,
  });

  final String id;
  final String name;
  int quantity;
  final int rate;
  bool active;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
    rate: 0,
    active: json['active'] == true,
  );
}

class Sale {
  Sale({
    required this.salesman,
    required this.userId,
    required this.store,
    required this.contact,
    required this.location,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.rate,
    required this.createdAt,
  });

  final String salesman;
  final String userId;
  final String store;
  final String contact;
  final String location;
  final String productId;
  final String productName;
  final int quantity;
  final int rate;
  final DateTime createdAt;
  final OrderStatus orderStatus = OrderStatus.pending;
}

enum OrderStatus { pending, approved }
