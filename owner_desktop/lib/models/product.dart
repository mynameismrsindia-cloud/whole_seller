class Product {
  Product({
    this.id = '',
    required this.name,
    required this.quantity,
    this.active = true,
  });

  final String id;
  String name;
  int quantity;
  bool active;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
    active: json['active'] == true,
  );
}

class Sale {
  Sale({
    this.id = '',
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
    this.orderStatus = OrderStatus.pending,
  });

  final String id;
  final String salesman;
  final String userId;
  final String store;
  final String contact;
  final String location;
  final String productId;
  final String productName;
  final int quantity;
  final int rate;
  int get totalAmount => quantity * rate;
  final DateTime createdAt;
  OrderStatus orderStatus;

  factory Sale.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Sale(
      id: json['id']?.toString() ?? '',
      salesman: json['salesman']?.toString() ?? '',
      userId: json['sellerId']?.toString() ?? '',
      store: json['store']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      rate: int.tryParse(json['rate']?.toString() ?? '') ?? 0,
      createdAt: createdAt,
      orderStatus:
          json['orderStatus']?.toString().trim().toLowerCase() == 'approved'
          ? OrderStatus.approved
          : OrderStatus.pending,
    );
  }
}

enum OrderStatus { pending, approved }
