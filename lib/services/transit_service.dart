import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/models.dart';

class TransitService {
  static const String _baseUrl = 'http://localhost:3000';
  // static const String _baseUrl =
  //     'https://edgy-nonluminescent-kymani.ngrok-free.dev';
  final http.Client _client;
  final bool enableDiagnostics;

  TransitService({http.Client? client, this.enableDiagnostics = false})
      : _client = client ?? http.Client();

  /// Disposes the HTTP client
  void dispose() {
    _client.close();
  }

  /// Helper method to handle API responses
  Map<String, dynamic> _handleResponse(
    http.Response response,
    String endpoint,
  ) {
    if (enableDiagnostics) {
      debugPrint('🚊 Transit API Call: $endpoint');
      debugPrint('📊 Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          if (data.containsKey('types')) {
            final types = data['types'] as List?;
            debugPrint('✅ Success: Found ${types?.length ?? 0} transit types');
          } else if (data.containsKey('routes')) {
            final routes = data['routes'] as List?;
            debugPrint('✅ Success: Found ${routes?.length ?? 0} transit routes');
          } else if (data.containsKey('cities')) {
            final cities = data['cities'] as List?;
            debugPrint('✅ Success: Found ${cities?.length ?? 0} transit cities');
          } else if (data.containsKey('success')) {
            debugPrint('✅ Success: Operation completed');
          } else {
            debugPrint('✅ Success: Data received');
          }
        } catch (e) {
          debugPrint('✅ Success: Response received (parsing will continue)');
        }
      } else {
        debugPrint('❌ Error: HTTP ${response.statusCode}');
      }
      debugPrint(''); // Clean spacing
    }

    if (response.statusCode == 200) {
      try {
        return json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException(
          message: 'Failed to parse JSON response: $e',
          statusCode: response.statusCode,
          endpoint: endpoint,
        );
      }
    } else if (response.statusCode == 400) {
      // For validation errors, try to parse JSON error response
      try {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error'] as String? ?? 'Bad Request';
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
          endpoint: endpoint,
        );
      } catch (e) {
        throw ApiException(
          message: response.body.isNotEmpty ? response.body : 'Bad Request',
          statusCode: response.statusCode,
          endpoint: endpoint,
        );
      }
    } else if (response.statusCode == 500) {
      throw ApiException(
        message: response.body.isNotEmpty
            ? response.body
            : 'Internal Server Error',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
    } else {
      throw ApiException(
        message: 'HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
    }
  }

  /// Get transit types
  /// Returns a list of available transit route types
  Future<List<TransitType>> getTransitTypes() async {
    const endpoint = '/transit/GetTransitTypes';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final typesData = data['types'] as List<dynamic>?;

      if (typesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing types array',
          endpoint: endpoint,
        );
      }

      return typesData
          .map((type) => TransitType.fromJson(type as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get transit routes
  /// Returns a list of all transit routes
  Future<List<TransitRoute>> getTransitRoutes() async {
    const endpoint = '/transit/GetTransitRoutes';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final routesData = data['routes'] as List<dynamic>?;

      if (routesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing routes array',
          endpoint: endpoint,
        );
      }

      return routesData
          .map((route) => TransitRoute.fromJson(route as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get transit cities
  /// Returns a list of cities that have transit data
  Future<List<TransitCity>> getTransitCities() async {
    const endpoint = '/transit/GetTransitCities';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final citiesData = data['cities'] as List<dynamic>?;

      if (citiesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing cities array',
          endpoint: endpoint,
        );
      }

      return citiesData
          .map((city) => TransitCity.fromJson(city as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Submit a new transit route
  /// Creates or updates a transit route with validation
  Future<bool> submitRoute(RouteSubmission routeSubmission) async {
    const endpoint = '/transit/SubmitRoute';

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(routeSubmission.toJson()),
      );

      final data = _handleResponse(response, endpoint);
      return data['success'] as bool? ?? false;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Monitor a transit route
  /// Adds a route to the monitoring list
  Future<bool> monitorRoute(String routeId) async {
    const endpoint = '/transit/MonitorRoute';
    final request = MonitorRouteRequest(routeId: routeId);

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      final data = _handleResponse(response, endpoint);
      return data['success'] as bool? ?? false;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Unmonitor a transit route
  /// Removes a route from the monitoring list
  Future<bool> unmonitorRoute(String routeId) async {
    const endpoint = '/transit/UnmonitorRoute';
    final request = MonitorRouteRequest(routeId: routeId);

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      final data = _handleResponse(response, endpoint);
      return data['success'] as bool? ?? false;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }
}