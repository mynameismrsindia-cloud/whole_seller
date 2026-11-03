class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.storeName = '',
    this.contact = '',
    this.location = '',
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String storeName;
  final String contact;
  final String location;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    storeName: json['storeName']?.toString() ?? '',
    contact: json['contact']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
  );
}
