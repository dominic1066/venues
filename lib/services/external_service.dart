import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'transit_service.dart' show ApiServer;

class ExternalService {
  final String _baseUrl;
  final http.Client _client;
  final bool enableDiagnostics;

  ExternalService({
    ApiServer server = ApiServer.localhost,
    http.Client? client,
    this.enableDiagnostics = false,
  })  : _baseUrl = server.url,
        _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  /// Search the Bus Australia fleet database for a vehicle
  /// Returns registration, chassis, seating code and operator information
  Future<BusAustraliaSearchResponse> busAustraliaSearch(int cityId, String vehicleId) async {
    final endpoint = '/external/busAustraliaSearch?cityId=$cityId&vehicleId=${Uri.encodeComponent(vehicleId)}';

    try {
      if (enableDiagnostics) {
        debugPrint('🔍 External: Bus Australia search for vehicle $vehicleId');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = BusAustraliaSearchResponse.fromJson(data);

        if (enableDiagnostics) {
          debugPrint('✅ Bus Australia: ${result.results.length} result(s) for $vehicleId');
        }

        return result;
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw ApiException(
          message: data['error'] as String? ?? 'Bad Request',
          statusCode: response.statusCode,
          endpoint: endpoint,
        );
      } else {
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw ApiException(
          message: data['error'] as String? ?? 'Server error',
          statusCode: response.statusCode,
          endpoint: endpoint,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }
}
