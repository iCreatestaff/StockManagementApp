// Product model
class Product {
  final int id;
  final String name;
  final String sku;
  final int quantity;
  final String unit;
  final int minQuantity;
  final String? category;
  final String? location;
  final String? notes;
  final bool isActive;
  final bool isLowStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.unit,
    required this.minQuantity,
    this.category,
    this.location,
    this.notes,
    required this.isActive,
    required this.isLowStock,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      sku: json['sku'],
      quantity: json['quantity'],
      unit: json['unit'],
      minQuantity: json['minQuantity'],
      category: json['category'],
      location: json['location'],
      notes: json['notes'],
      isActive: json['isActive'] ?? true,
      isLowStock: json['isLowStock'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

// User model
class User {
  final int id;
  final String username;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      isActive: json['isActive'] ?? true,
    );
  }
}

// Movement model
class Movement {
  final int id;
  final int productId;
  final String productName;
  final int userId;
  final String username;
  final String operationType;
  final int quantityChange;
  final int oldQuantity;
  final int newQuantity;
  final String? details;
  final int? originalMovementId;
  final bool isUndone;
  final DateTime timestamp;

  Movement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.userId,
    required this.username,
    required this.operationType,
    required this.quantityChange,
    required this.oldQuantity,
    required this.newQuantity,
    this.details,
    this.originalMovementId,
    required this.isUndone,
    required this.timestamp,
  });

  factory Movement.fromJson(Map<String, dynamic> json) {
    return Movement(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'],
      userId: json['userId'],
      username: json['username'],
      operationType: json['operationType'],
      quantityChange: json['quantityChange'],
      oldQuantity: json['oldQuantity'],
      newQuantity: json['newQuantity'],
      details: json['details'],
      originalMovementId: json['originalMovementId'],
      isUndone: json['isUndone'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// Auth response
class AuthResponse {
  final String token;
  final User user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      user: User.fromJson(json['user']),
    );
  }
}

// Paginated response
class PaginatedResponse<T> {
  final List<T> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedResponse(
      data: (json['data'] as List).map((e) => e).toList() as List<T>,
      page: json['pagination']['page'],
      limit: json['pagination']['limit'],
      total: json['pagination']['total'],
      totalPages: json['pagination']['totalPages'],
    );
  }
}

// Stats models
class Stats {
  final InventoryStats inventory;
  final ActivityStats activity;
  final List<TopMover> topMovers;

  Stats({
    required this.inventory,
    required this.activity,
    required this.topMovers,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      inventory: InventoryStats.fromJson(json['inventory']),
      activity: ActivityStats.fromJson(json['activity']),
      topMovers: (json['topMovers'] as List).map((e) => TopMover.fromJson(e)).toList(),
    );
  }
}

class InventoryStats {
  final int totalProducts;
  final int totalQuantity;
  final int lowStockCount;

  InventoryStats({
    required this.totalProducts,
    required this.totalQuantity,
    required this.lowStockCount,
  });

  factory InventoryStats.fromJson(Map<String, dynamic> json) {
    return InventoryStats(
      totalProducts: json['totalProducts'],
      totalQuantity: json['totalQuantity'],
      lowStockCount: json['lowStockCount'],
    );
  }
}

class ActivityStats {
  final int totalMovements;
  final Map<String, int> byType;

  ActivityStats({
    required this.totalMovements,
    required this.byType,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    return ActivityStats(
      totalMovements: json['totalMovements'],
      byType: Map<String, int>.from(json['byType']),
    );
  }
}

class TopMover {
  final int productId;
  final String productName;
  final int count;

  TopMover({
    required this.productId,
    required this.productName,
    required this.count,
  });

  factory TopMover.fromJson(Map<String, dynamic> json) {
    return TopMover(
      productId: json['productId'],
      productName: json['productName'],
      count: json['count'],
    );
  }
}
