import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'package:flutter/foundation.dart';

class VenuesService {
  static const String _baseUrl = 'http://localhost:3000';
  // static const String _baseUrl =
  //     'https://edgy-nonluminescent-kymani.ngrok-free.dev';
  final http.Client _client;
  final bool enableDiagnostics;

  VenuesService({http.Client? client, this.enableDiagnostics = false})
    : _client = client ?? http.Client();

  /// Disposes the HTTP client
  void dispose() {
    _client.close();
  }

  /// Helper method to handle API responses - completely silent
  Map<String, dynamic> _handleResponse(
    http.Response response,
    String endpoint,
  ) {
    if (enableDiagnostics) {
      debugPrint('🌐 API Call: $endpoint');
      debugPrint('📊 Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          if (data.containsKey('venues')) {
            final venues = data['venues'] as List?;
            debugPrint('✅ Success: Found ${venues?.length ?? 0} venues');
          } else if (data.containsKey('venueGroups')) {
            final groups = data['venueGroups'] as List?;
            debugPrint('✅ Success: Found ${groups?.length ?? 0} venue groups');
          } else if (data.containsKey('observations')) {
            final observations = data['observations'] as List?;
            debugPrint(
              '✅ Success: Found ${observations?.length ?? 0} observations',
            );
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
      throw ApiException(
        message: response.body.isNotEmpty ? response.body : 'Bad Request',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
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

  /// Get venues to monitor
  /// Returns a list of venues that should be monitored
  Future<List<Venue>> getVenuesToMonitor() async {
    const endpoint = '/venue/GetVenuesToMonitor';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final venuesData = data['venues'] as List<dynamic>?;

      if (venuesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing venues array',
          endpoint: endpoint,
        );
      }

      return venuesData
          .map((venue) => Venue.fromJson(venue as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get venues, optionally filtered by city
  /// [city] - Optional city filter
  Future<List<Venue>> getVenues({String? city}) async {
    const endpoint = '/venue/GetVenues';
    final uri = Uri.parse('$_baseUrl$endpoint');
    debugPrint('🔍 DEBUG: uri $uri');
    final uriWithQuery = city != null
        ? uri.replace(queryParameters: {'city': city})
        : uri;

    try {
      final response = await _client.get(
        uriWithQuery,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final venuesData = data['venues'] as List<dynamic>?;

      if (venuesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing venues array',
          endpoint: endpoint,
        );
      }

      return venuesData
          .map((venue) => Venue.fromJson(venue as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get list of cities
  Future<List<City>> getCities() async {
    const endpoint = '/venue/GetCities';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final citiesData =
          data['venues']
              as List<dynamic>?; // API returns cities in 'venues' array

      if (citiesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing venues/cities array',
          endpoint: endpoint,
        );
      }

      return citiesData
          .map((city) => City.fromJson(city as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get venue groups
  Future<List<VenueGroup>> getVenueGroups() async {
    const endpoint = '/venue/GetVenueGroups';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final venueGroupsData = data['venueGroups'] as List<dynamic>?;

      if (venueGroupsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing venueGroups array',
          endpoint: endpoint,
        );
      }

      return venueGroupsData
          .map((group) => VenueGroup.fromJson(group as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get venues by group
  /// [groupId] - Required group ID
  Future<List<Venue>> getVenuesByGroup(int groupId) async {
    const endpoint = '/venue/GetVenuesByGroup';
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: {'groupId': groupId.toString()});

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final venuesData = data['venues'] as List<dynamic>?;

      if (venuesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing venues array',
          endpoint: endpoint,
        );
      }

      return venuesData
          .map((venue) => Venue.fromJson(venue as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get occupancy/observations for a venue
  /// [venueId] - Required venue ID
  Future<List<Observation>> getOccupancyByVenue(int venueId) async {
    const endpoint = '/observations/GetOccupancyByVenue';
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: {'venueId': venueId.toString()});

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final observationsData = data['observations'] as List<dynamic>?;

      if (observationsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing observations array',
          endpoint: endpoint,
        );
      }

      return observationsData
          .map((obs) => Observation.fromJson(obs as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get occupancy for a venue group
  /// [venueGroupId] - Required venue group ID
  Future<List<Observation>> getOccupancyByVenueGroup(int venueGroupId) async {
    const endpoint = '/observations/GetOccupancyByVenueGroup';
    final uri = Uri.parse(
      '$_baseUrl$endpoint',
    ).replace(queryParameters: {'venueGroupId': venueGroupId.toString()});

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final observationsData = data['observations'] as List<dynamic>?;

      if (observationsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing observations array',
          endpoint: endpoint,
        );
      }

      return observationsData
          .map((obs) => Observation.fromJson(obs as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }
}
