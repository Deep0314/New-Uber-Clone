# API Integration Guide

This guide shows how to replace the mock implementations with real backend APIs.

## Current Architecture

```
Flutter App (Frontend)
    ↓
Repositories (Mock Implementation) ← YOU ARE HERE
    ↓
Backend API (To Be Implemented)
    ↓
Database
```

---

## Step 1: Set Up HTTP Client

### Install Dio (Recommended over http package)

```yaml
# pubspec.yaml
dependencies:
  dio: ^5.4.0
  pretty_dio_logger: ^1.3.1  # For debugging
```

### Create API Client Service

Create `lib/core/services/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:uber_clone/core/constants/app_constants.dart';
import 'package:uber_clone/core/services/storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final StorageService _storage;

  ApiClient({required StorageService storage}) : _storage = storage {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.apiTimeout,
      receiveTimeout: AppConstants.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Add dio logger for debugging
    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ));
    }
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add auth token to all requests
    final token = await _storage.getSecure(AppConstants.keyAuthToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    // Handle successful responses
    return handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle token refresh on 401
    if (error.response?.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry the request
        final options = error.requestOptions;
        final response = await _dio.fetch(options);
        return handler.resolve(response);
      }
    }

    return handler.next(error);
  }

  Future<bool> _refreshToken() async {
    // Implement token refresh logic
    try {
      final refreshToken = await _storage.getSecure('refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final newToken = response.data['accessToken'];
      await _storage.saveSecure(AppConstants.keyAuthToken, newToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  // HTTP Methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
```

### Add to Providers

```dart
// lib/core/providers/providers.dart

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(storage: storage);
});
```

---

## Step 2: Replace AuthRepository

Update `lib/data/repositories/auth_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:uber_clone/core/services/api_client.dart';
import 'package:uber_clone/core/services/storage_service.dart';
import 'package:uber_clone/domain/models/user.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final StorageService _storage;

  AuthRepository({
    required ApiClient apiClient,
    required StorageService storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    try {
      final response = await _apiClient.post('/auth/send-otp', data: {
        'phoneNumber': phoneNumber,
      });

      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Error sending OTP: ${e.message}');
      return false;
    }
  }

  /// Verify OTP and login
  Future<User?> verifyOTP(String phoneNumber, String otp) async {
    try {
      final response = await _apiClient.post('/auth/verify-otp', data: {
        'phoneNumber': phoneNumber,
        'otp': otp,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Save tokens
        await _storage.saveSecure('auth_token', data['accessToken']);
        await _storage.saveSecure('refresh_token', data['refreshToken']);

        // Parse and save user
        final user = User.fromJson(data['user']);
        await _saveUser(user);

        return user;
      }

      return null;
    } on DioException catch (e) {
      print('Error verifying OTP: ${e.message}');
      return null;
    }
  }

  /// Get current user from backend
  Future<User?> getCurrentUser() async {
    try {
      // Check if logged in
      final token = await _storage.getSecure('auth_token');
      if (token == null) return null;

      // Fetch from API
      final response = await _apiClient.get('/auth/me');

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        await _saveUser(user);
        return user;
      }

      return null;
    } on DioException catch (e) {
      print('Error getting current user: ${e.message}');
      // Return cached user if API fails
      final cachedData = _storage.getJson('user_data');
      return cachedData != null ? User.fromJson(cachedData) : null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.getSecure('auth_token');
    return token != null && token.isNotEmpty;
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (e) {
      // Continue with local logout even if API fails
    } finally {
      await _storage.clear();
    }
  }

  /// Update user profile
  Future<User?> updateProfile({String? name, String? email}) async {
    try {
      final response = await _apiClient.patch('/auth/profile', data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      });

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        await _saveUser(user);
        return user;
      }

      return null;
    } on DioException catch (e) {
      print('Error updating profile: ${e.message}');
      return null;
    }
  }

  Future<void> _saveUser(User user) async {
    await _storage.saveJson('user_data', user.toJson());
    await _storage.saveString('user_id', user.id);
    await _storage.saveString('user_role', user.role.name);
    await _storage.saveBool('is_logged_in', true);
  }
}
```

Update provider:

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthRepository(apiClient: apiClient, storage: storage);
});
```

---

## Step 3: Replace RideRepository

Update `lib/data/repositories/ride_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:uber_clone/core/services/api_client.dart';
import 'package:uber_clone/domain/models/ride.dart';
import 'package:uber_clone/domain/models/location.dart';
import 'package:uber_clone/domain/models/user.dart';
import 'package:uber_clone/core/constants/app_constants.dart';

class RideRepository {
  final ApiClient _apiClient;

  RideRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Create a new ride
  Future<Ride> createRide({
    required User user,
    required LocationModel pickup,
    required LocationModel destination,
    required VehicleType vehicleType,
    required double estimatedFare,
    required double distance,
    required int estimatedDuration,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      final response = await _apiClient.post('/rides', data: {
        'userId': user.id,
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'vehicleType': vehicleType.name,
        'estimatedFare': estimatedFare,
        'distance': distance,
        'estimatedDuration': estimatedDuration,
        'paymentMethod': paymentMethod.name,
      });

      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to create ride: ${e.message}');
    }
  }

  /// Assign driver to ride
  Future<Ride?> assignDriver(String rideId, String driverId) async {
    try {
      final response = await _apiClient.patch('/rides/$rideId/assign', data: {
        'driverId': driverId,
      });

      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      print('Error assigning driver: ${e.message}');
      return null;
    }
  }

  /// Update ride status
  Future<Ride?> updateRideStatus(String rideId, RideStatus status) async {
    try {
      final response = await _apiClient.patch('/rides/$rideId/status', data: {
        'status': status.name,
      });

      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      print('Error updating ride status: ${e.message}');
      return null;
    }
  }

  /// Get ride by ID
  Future<Ride?> getRideById(String rideId) async {
    try {
      final response = await _apiClient.get('/rides/$rideId');
      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      print('Error getting ride: ${e.message}');
      return null;
    }
  }

  /// Get user's rides with pagination
  Future<List<Ride>> getUserRides(String userId, {int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get('/users/$userId/rides', queryParameters: {
        'page': page,
        'limit': limit,
      });

      return (response.data['rides'] as List)
          .map((json) => Ride.fromJson(json))
          .toList();
    } on DioException catch (e) {
      print('Error getting user rides: ${e.message}');
      return [];
    }
  }

  /// Get driver's rides with pagination
  Future<List<Ride>> getDriverRides(String driverId, {int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get('/drivers/$driverId/rides', queryParameters: {
        'page': page,
        'limit': limit,
      });

      return (response.data['rides'] as List)
          .map((json) => Ride.fromJson(json))
          .toList();
    } on DioException catch (e) {
      print('Error getting driver rides: ${e.message}');
      return [];
    }
  }

  /// Get all rides (admin only)
  Future<List<Ride>> getAllRides({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get('/rides', queryParameters: {
        'page': page,
        'limit': limit,
      });

      return (response.data['rides'] as List)
          .map((json) => Ride.fromJson(json))
          .toList();
    } on DioException catch (e) {
      print('Error getting all rides: ${e.message}');
      return [];
    }
  }

  /// Cancel ride
  Future<Ride?> cancelRide(String rideId, String cancelledBy, String? reason) async {
    try {
      final response = await _apiClient.patch('/rides/$rideId/cancel', data: {
        'cancelledBy': cancelledBy,
        'reason': reason,
      });

      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      print('Error cancelling ride: ${e.message}');
      return null;
    }
  }

  /// Rate ride
  Future<Ride?> rateRide({
    required String rideId,
    double? userRating,
    double? driverRating,
    String? userReview,
    String? driverReview,
  }) async {
    try {
      final response = await _apiClient.patch('/rides/$rideId/rate', data: {
        if (userRating != null) 'userRating': userRating,
        if (driverRating != null) 'driverRating': driverRating,
        if (userReview != null) 'userReview': userReview,
        if (driverReview != null) 'driverReview': driverReview,
      });

      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      print('Error rating ride: ${e.message}');
      return null;
    }
  }

  /// Complete payment
  Future<Ride?> completePayment(String rideId, double actualFare) async {
    try {
      final response = await _apiClient.patch('/rides/$rideId/payment', data: {
        'actualFare': actualFare,
        'isPaid': true,
      });

      return Ride.fromJson(response.data);
    } on DioException catch (e) {
      print('Error completing payment: ${e.message}');
      return null;
    }
  }
}
```

---

## Step 4: Replace DriverRepository

Update `lib/data/repositories/driver_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:uber_clone/core/services/api_client.dart';
import 'package:uber_clone/domain/models/driver.dart';
import 'package:uber_clone/core/constants/app_constants.dart';

class DriverRepository {
  final ApiClient _apiClient;

  DriverRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get driver by user ID
  Future<Driver?> getDriverByUserId(String userId) async {
    try {
      final response = await _apiClient.get('/drivers/by-user/$userId');
      return Driver.fromJson(response.data);
    } on DioException catch (e) {
      print('Error getting driver: ${e.message}');
      return null;
    }
  }

  /// Get driver by ID
  Future<Driver?> getDriverById(String driverId) async {
    try {
      final response = await _apiClient.get('/drivers/$driverId');
      return Driver.fromJson(response.data);
    } on DioException catch (e) {
      print('Error getting driver: ${e.message}');
      return null;
    }
  }

  /// Get nearby drivers
  Future<List<Driver>> getNearbyDrivers({
    required LatLng location,
    required VehicleType vehicleType,
    double radiusKm = 5.0,
  }) async {
    try {
      final response = await _apiClient.get('/drivers/nearby', queryParameters: {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'vehicleType': vehicleType.name,
        'radius': radiusKm,
      });

      return (response.data['drivers'] as List)
          .map((json) => Driver.fromJson(json))
          .toList();
    } on DioException catch (e) {
      print('Error getting nearby drivers: ${e.message}');
      return [];
    }
  }

  /// Update driver status
  Future<Driver?> updateDriverStatus({
    required String driverId,
    bool? isOnline,
    bool? isAvailable,
  }) async {
    try {
      final response = await _apiClient.patch('/drivers/$driverId/status', data: {
        if (isOnline != null) 'isOnline': isOnline,
        if (isAvailable != null) 'isAvailable': isAvailable,
      });

      return Driver.fromJson(response.data);
    } on DioException catch (e) {
      print('Error updating driver status: ${e.message}');
      return null;
    }
  }

  /// Update driver location
  Future<void> updateDriverLocation(String driverId, LatLng location) async {
    try {
      await _apiClient.post('/drivers/$driverId/location', data: {
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
    } on DioException catch (e) {
      print('Error updating driver location: ${e.message}');
    }
  }

  /// Get driver location
  LatLng? getDriverLocation(String driverId) {
    // This would typically come from WebSocket or polling
    // Implementation depends on your real-time strategy
    return null;
  }

  /// Assign ride to driver
  Future<Driver?> assignRide(String driverId, String rideId) async {
    try {
      final response = await _apiClient.post('/drivers/$driverId/assign-ride', data: {
        'rideId': rideId,
      });

      return Driver.fromJson(response.data);
    } on DioException catch (e) {
      print('Error assigning ride: ${e.message}');
      return null;
    }
  }

  /// Complete ride for driver
  Future<Driver?> completeRide(String driverId, double earnings) async {
    try {
      final response = await _apiClient.post('/drivers/$driverId/complete-ride', data: {
        'earnings': earnings,
      });

      return Driver.fromJson(response.data);
    } on DioException catch (e) {
      print('Error completing ride: ${e.message}');
      return null;
    }
  }

  /// Get all drivers (admin only)
  Future<List<Driver>> getAllDrivers() async {
    try {
      final response = await _apiClient.get('/drivers');

      return (response.data['drivers'] as List)
          .map((json) => Driver.fromJson(json))
          .toList();
    } on DioException catch (e) {
      print('Error getting all drivers: ${e.message}');
      return [];
    }
  }
}
```

---

## Step 5: Backend API Specification

Here's what your backend API should implement:

### Authentication Endpoints

```
POST   /api/auth/send-otp
POST   /api/auth/verify-otp
POST   /api/auth/refresh
GET    /api/auth/me
POST   /api/auth/logout
PATCH  /api/auth/profile
```

### Ride Endpoints

```
POST   /api/rides                    # Create ride
GET    /api/rides/:id                # Get ride details
PATCH  /api/rides/:id/assign         # Assign driver
PATCH  /api/rides/:id/status         # Update status
PATCH  /api/rides/:id/cancel         # Cancel ride
PATCH  /api/rides/:id/rate           # Rate ride
PATCH  /api/rides/:id/payment        # Complete payment
GET    /api/users/:userId/rides      # User's rides
GET    /api/drivers/:driverId/rides  # Driver's rides
GET    /api/rides                    # All rides (admin)
```

### Driver Endpoints

```
GET    /api/drivers/:id              # Get driver
GET    /api/drivers/by-user/:userId  # Get by user ID
GET    /api/drivers/nearby           # Search nearby
PATCH  /api/drivers/:id/status       # Update status
POST   /api/drivers/:id/location     # Update location
POST   /api/drivers/:id/assign-ride  # Assign ride
POST   /api/drivers/:id/complete-ride # Complete ride
GET    /api/drivers                  # All drivers (admin)
```

### User Endpoints

```
GET    /api/users/:id                # Get user
PATCH  /api/users/:id                # Update user
DELETE /api/users/:id                # Delete user
GET    /api/users                    # All users (admin)
```

---

## Step 6: Error Handling

Create error models:

```dart
// lib/core/utils/api_exception.dart

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioError(DioException error) {
    String message = 'Something went wrong';
    int? statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout. Please check your internet connection.';
    } else if (error.type == DioExceptionType.badResponse) {
      statusCode = error.response?.statusCode;
      message = error.response?.data['message'] ?? 'Server error occurred';
    } else if (error.type == DioExceptionType.cancel) {
      message = 'Request was cancelled';
    } else {
      message = 'Network error. Please try again.';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      data: error.response?.data,
    );
  }

  @override
  String toString() => message;
}
```

Use in repositories:

```dart
try {
  final response = await _apiClient.get('/rides/$rideId');
  return Ride.fromJson(response.data);
} on DioException catch (e) {
  throw ApiException.fromDioError(e);
}
```

---

## Step 7: Testing API Integration

```dart
// test/data/repositories/auth_repository_test.dart

void main() {
  late AuthRepository authRepository;
  late Mock MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
    authRepository = AuthRepository(apiClient: mockApiClient);
  });

  group('AuthRepository', () {
    test('sendOTP returns true on success', () async {
      when(mockApiClient.post('/auth/send-otp', data: anyNamed('data')))
          .thenAnswer((_) async => Response(
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      final result = await authRepository.sendOTP('+919876543211');

      expect(result, true);
      verify(mockApiClient.post('/auth/send-otp', data: {
        'phoneNumber': '+919876543211',
      })).called(1);
    });
  });
}
```

---

## Complete Migration Checklist

- [ ] Install Dio package
- [ ] Create ApiClient service
- [ ] Add ApiClient to providers
- [ ] Update AuthRepository with real API calls
- [ ] Update RideRepository with real API calls
- [ ] Update DriverRepository with real API calls
- [ ] Create error handling utilities
- [ ] Update base URL in app_constants.dart
- [ ] Test all API endpoints
- [ ] Handle edge cases (no internet, timeout, etc.)
- [ ] Add retry logic for failed requests
- [ ] Implement request caching if needed
- [ ] Add analytics/logging for API calls
- [ ] Test on real devices
- [ ] Performance testing
- [ ] Load testing

---

## Next Steps

1. Set up your backend server (Node.js, Django, Laravel, etc.)
2. Implement the API endpoints listed above
3. Replace mock repositories one by one
4. Test thoroughly with real data
5. Monitor API performance
6. Optimize as needed

Your Flutter app is **ready** for backend integration! 🚀
