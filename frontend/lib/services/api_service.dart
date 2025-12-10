import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// API Base URL - Change this to your Tailscale address in production
const String apiBaseUrl = 'http://localhost:3000/api';

// Auth Token Notifier
class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void setToken(String? token) {
    state = token;
  }
}

final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(() {
  return AuthTokenNotifier();
});

// Current User Notifier
class CurrentUserNotifier extends Notifier<User?> {
  @override
  User? build() {
    return null;
  }

  void setUser(User? user) {
    state = user;
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, User?>(() {
  return CurrentUserNotifier();
});

// Is Logged In Provider
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authTokenProvider) != null;
});

// Is Admin Provider
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isAdmin ?? false;
});

// Dio Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(authTokenProvider);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        ref.read(authTokenProvider.notifier).setToken(null);
        ref.read(currentUserProvider.notifier).setUser(null);
      }
      return handler.next(error);
    },
  ));

  return dio;
});

// API Service
class ApiService {
  final Dio dio;

  ApiService(this.dio);

  // Auth
  Future<AuthResponse> login(String username, String password) async {
    final response = await dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  // Products
  Future<PaginatedResponse<Product>> getProducts({
    String? search,
    String? category,
    bool? isActive,
    bool? lowStock,
    String sortBy = 'name',
    String sortOrder = 'asc',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await dio.get('/products', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null) 'category': category,
      if (isActive != null) 'isActive': isActive.toString(),
      if (lowStock == true) 'lowStock': 'true',
      'sortBy': sortBy,
      'sortOrder': sortOrder,
      'page': page.toString(),
      'limit': limit.toString(),
    });

    final data = response.data;
    return PaginatedResponse<Product>(
      data: (data['data'] as List).map((e) => Product.fromJson(e)).toList(),
      page: data['pagination']['page'],
      limit: data['pagination']['limit'],
      total: data['pagination']['total'],
      totalPages: data['pagination']['totalPages'],
    );
  }

  Future<Product> getProduct(int id) async {
    final response = await dio.get('/products/$id');
    return Product.fromJson(response.data);
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await dio.post('/products', data: data);
    return Product.fromJson(response.data);
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/products/$id', data: data);
    return Product.fromJson(response.data);
  }

  Future<Product> takeFromStock(int id, int quantity, String? details) async {
    final response = await dio.post('/products/$id/take', data: {
      'quantity': quantity,
      if (details != null) 'details': details,
    });
    return Product.fromJson(response.data);
  }

  Future<Product> adjustStock(int id, int quantity, String? details) async {
    final response = await dio.post('/products/$id/adjust', data: {
      'quantity': quantity,
      if (details != null) 'details': details,
    });
    return Product.fromJson(response.data);
  }

  Future<Product> setProductActive(int id, bool isActive) async {
    final response = await dio.patch('/products/$id/activate', data: {
      'isActive': isActive,
    });
    return Product.fromJson(response.data);
  }

  // Users
  Future<List<User>> getUsers() async {
    final response = await dio.get('/users');
    return (response.data as List).map((e) => User.fromJson(e)).toList();
  }

  Future<User> createUser(String username, String password, String role) async {
    final response = await dio.post('/users', data: {
      'username': username,
      'password': password,
      'role': role,
    });
    return User.fromJson(response.data);
  }

  Future<User> updateUser(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/users/$id', data: data);
    return User.fromJson(response.data);
  }

  Future<void> resetPassword(int id, String password) async {
    await dio.post('/users/$id/reset-password', data: {'password': password});
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await dio.post('/users/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // Movements
  Future<PaginatedResponse<Movement>> getMovements({
    int? productId,
    int? userId,
    String? operationType,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    String sortBy = 'timestamp',
    String sortOrder = 'desc',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await dio.get('/movements', queryParameters: {
      if (productId != null) 'productId': productId.toString(),
      if (userId != null) 'userId': userId.toString(),
      if (operationType != null) 'operationType': operationType,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (search != null && search.isNotEmpty) 'search': search,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
      'page': page.toString(),
      'limit': limit.toString(),
    });

    final data = response.data;
    return PaginatedResponse<Movement>(
      data: (data['data'] as List).map((e) => Movement.fromJson(e)).toList(),
      page: data['pagination']['page'],
      limit: data['pagination']['limit'],
      total: data['pagination']['total'],
      totalPages: data['pagination']['totalPages'],
    );
  }

  Future<void> undoMovement(int id) async {
    await dio.post('/movements/$id/undo');
  }

  // Stats
  Future<Stats> getStats() async {
    final response = await dio.get('/stats');
    return Stats.fromJson(response.data);
  }
}

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});
