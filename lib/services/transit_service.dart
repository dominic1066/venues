import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/models.dart';

enum ApiServer {
  localhost('http://localhost:3000'),
  ngrok('https://edgy-nonluminescent-kymani.ngrok-free.dev');

  final String url;
  const ApiServer(this.url);
}

class TransitService {
  final String _baseUrl;
  final http.Client _client;
  final bool enableDiagnostics;

  // Map from trip key (cityId-tripId) to shape key (cityId-shapeId)
  final Map<String, String> _tripToShapeMap = {};
  
  // Map from shape key (cityId-shapeId) to TripShape object
  final Map<String, TripShape> _shapeCache = {};

  TransitService({
    ApiServer server = ApiServer.localhost,
    http.Client? client,
    this.enableDiagnostics = false,
  })  : _baseUrl = server.url,
        _client = client ?? http.Client();

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
          } else if (data.containsKey('districts')) {
            final districts = data['districts'] as List?;
            debugPrint('✅ Success: Found ${districts?.length ?? 0} districts');
          } else if (data.containsKey('observations')) {
            final observations = data['observations'] as List?;
            debugPrint('✅ Success: Found ${observations?.length ?? 0} live trips');
          } else if (data.containsKey('trips')) {
            final trips = data['trips'] as List?;
            debugPrint('✅ Success: Found ${trips?.length ?? 0} trips');
          } else if (data.containsKey('routeDistrictStats')) {
            final stats = data['routeDistrictStats'] as List?;
            debugPrint('✅ Success: Found ${stats?.length ?? 0} route district stats');
          } else if (data.containsKey('transitions')) {
            final transitions = data['transitions'] as List?;
            debugPrint('✅ Success: Found ${transitions?.length ?? 0} occupancy transitions');
          } else if (data.containsKey('success')) {
            debugPrint('✅ Success: Operation completed');
          } else {
            // debugPrint('✅ Success: Data received');
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
  /// Returns a list of cities that have transit data with their associated districts
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

      // Load cities with their districts
      final List<TransitCity> cities = [];
      for (final cityData in citiesData) {
        final cityMap = cityData as Map<String, dynamic>;
        final cityId = cityMap['Id'] as int;
        
        // Load districts for this city
        List<District> districts = [];
        try {
          districts = await getCityDistricts(cityId);
        } catch (e) {
          if (enableDiagnostics) {
            debugPrint('⚠️ Failed to load districts for city $cityId: $e');
          }
          // Continue with empty districts list if loading fails
        }
        
        // Create TransitCity with districts
        final city = TransitCity.fromJson(cityMap, districts: districts);
        cities.add(city);
      }

      return cities;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get districts for a city
  /// Returns a list of districts for the specified city
  Future<List<District>> getCityDistricts(int cityId) async {
    final endpoint = '/transit/GetCityDistricts?cityId=$cityId';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final districtsData = data['districts'] as List<dynamic>?;

      if (districtsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing districts array',
          endpoint: endpoint,
        );
      }

      return districtsData
          .map((district) => District.fromJson(district as Map<String, dynamic>))
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
  Future<bool> monitorRoute(int cityId, String routeId) async {
    const endpoint = '/transit/MonitorRoute';
    final request = MonitorRouteRequest(cityId: cityId, routeId: routeId);

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
  Future<bool> unmonitorRoute(int cityId, String routeId) async {
    const endpoint = '/transit/UnmonitorRoute';
    final request = MonitorRouteRequest(cityId: cityId, routeId: routeId);

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

  /// Get occupancy transitions for a city
  /// Returns all occupancy increment/decrement events for transit trips in a specific city
  Future<List<OccupancyTransition>> getOccupancyTransitions(int cityId, {String? tripDate}) async {
    final queryParams = <String, String>{
      'cityId': cityId.toString(),
    };
    
    if (tripDate != null) queryParams['tripDate'] = tripDate;
    
    final uri = Uri.parse('$_baseUrl/transit/GetOccupancyTransitions')
        .replace(queryParameters: queryParams);
    final endpoint = '/transit/GetOccupancyTransitions?${uri.query}';

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final transitionsData = data['transitions'] as List<dynamic>?;

      if (transitionsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing transitions array',
          endpoint: endpoint,
        );
      }

      return transitionsData
          .map((transition) => OccupancyTransition.fromJson(transition as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get live trips for a city
  /// Returns a list of currently active trips
  Future<List<LiveTrip>> getLiveTrips(int cityId) async {
    final endpoint = '/transit/GetLiveTrips?cityId=$cityId';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'application/json'},
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
          .map((trip) => LiveTrip.fromJson(trip as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  Future<List<LiveTrip>> getMonitoredLiveTrips(int cityId, bool includeObservations) async {
    final endpoint = '/transit/GetMonitoredLiveTrips?cityId=$cityId&includeObservations=$includeObservations';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'application/json'},
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
          .map((trip) => LiveTrip.fromJson(trip as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  Future<Map<String, String>> getMonitoredRoutes(int cityId) async {
    final endpoint = '/transit/GetMonitoredRoutes?cityId=$cityId';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'application/json'},
      );

      final data = _handleResponse(response, endpoint);
      final routesData = data['routes'] as List<dynamic>?;

      if (routesData == null) {
        throw ApiException(
          message: 'Invalid response format: missing routes array',
          endpoint: endpoint,
        );
      }

      return Map.fromEntries(routesData.map((route) {
        final routeMap = route as Map<String, dynamic>;
        return MapEntry(
          routeMap['RouteId'].toString(),
          routeMap['RouteShortName'].toString(),
        );
      }));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get shape data for a specific trip
  /// Returns the geographic path/route for a transit trip
  Future<TripShape> getShapeForTrip(int cityId, String tripId) async {
    final endpoint = '/transit/GetShapeForTrip?cityId=$cityId&tripId=$tripId';

    if (_tripToShapeMap.containsKey('$cityId-$tripId')) {
      final shapeKey = _tripToShapeMap['$cityId-$tripId']!;
      if (_shapeCache.containsKey(shapeKey)) {
        return _shapeCache[shapeKey]!;
      }
    }
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      
      // Extract shapeId from response or use tripId as fallback
      final shapeId = data['shapeId'] as String? ?? tripId;

      // Cache the shape data
      final shape = TripShape.fromJson(data, cityId, shapeId);
      _tripToShapeMap['$cityId-$tripId'] = shape.key();
      _shapeCache[shape.key()] = shape;
      
      return shape;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get route statistics by district
  /// Returns statistical data for transit routes aggregated by district
  Future<List<RouteDistrictStats>> getRouteDistrictStats(
    int cityId, {
    String? routeId,
    int? districtId,
    String? tripDate,
  }) async {
    final queryParams = <String, String>{
      'cityId': cityId.toString(),
    };
    
    if (routeId != null) queryParams['routeId'] = routeId;
    if (districtId != null) queryParams['districtId'] = districtId.toString();
    if (tripDate != null) queryParams['tripDate'] = tripDate;
    
    final uri = Uri.parse('$_baseUrl/transit/GetRouteDistrictStats')
        .replace(queryParameters: queryParams);
    final endpoint = '/transit/GetRouteDistrictStats?${uri.query}';

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final statsData = data['routeDistrictStats'] as List<dynamic>?;

      if (statsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing routeDistrictStats array',
          endpoint: endpoint,
        );
      }

      return statsData
          .map((stat) => RouteDistrictStats.fromJson(stat as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get trips for a specific route
  /// Returns all trips that belong to a specific transit route in a city
  Future<List<Trip>> getTripsForRoute(int cityId, String routeId) async {
    final endpoint = '/transit/GetTripsForRoute?cityId=$cityId&routeId=$routeId';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final tripsData = data['trips'] as List<dynamic>?;

      if (tripsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing trips array',
          endpoint: endpoint,
        );
      }

      return tripsData
          .map((trip) => Trip.fromJson(trip as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get observations for a specific trip
  /// Returns all recorded location observations for a transit trip
  Future<TripData> getObservationsForTrip(int cityId, String tripId, int directionId, String routeShortName, String routeDesc, int routeColour, String headsign) async {
    final endpoint = '/transit/GetObservationsForTrip?cityId=$cityId&tripId=$tripId';

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      
      return TripData.fromJson(data, cityId, tripId, directionId, routeShortName, routeDesc, routeColour, headsign);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Get all vehicles for a city
  Future<List<Vehicle>> getCityVehicles(int cityId) async {
    final endpoint = '/transit/GetCityVehicles?cityId=$cityId';

    try {
      if (enableDiagnostics) {
        debugPrint('🚌 Transit: Getting vehicles for city $cityId');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      
      if (data.containsKey('vehicles')) {
        final vehicles = (data['vehicles'] as List<dynamic>)
            .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
            .toList();
        
        if (enableDiagnostics) {
          debugPrint('✅ Success: Found ${vehicles.length} vehicles');
        }
        
        return vehicles;
      } else {
        throw ApiException(
          message: 'Invalid response format: expected "vehicles" array',
          endpoint: endpoint,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

  /// Submit vehicle data to the server
  Future<bool> submitVehicleData(Vehicle vehicle) async {
    const endpoint = '/transit/SubmitVehicleData';

    try {
      if (enableDiagnostics) {
        debugPrint('🚌 Transit: Submitting vehicle data for ${vehicle.vehicleId}');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(vehicle.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        
        if (enableDiagnostics) {
          debugPrint('✅ Vehicle data submitted successfully');
        }
        
        return success;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          message: data['error'] as String? ?? 'Validation error',
          endpoint: endpoint,
        );
      } else {
        throw ApiException(
          message: 'Server error: ${response.statusCode} - ${response.body}',
          endpoint: endpoint,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }


  /// Get hourly speed data by district
  /// Returns hourly speed statistics for transit routes grouped by route and hour,
  /// with separate inward and outward speed measurements
  Future<List<DistrictHourlySpeed>> getDistrictHourlySpeeds(
    int cityId, {
    String? tripDate,
  }) async {
    final queryParams = <String, String>{
      'cityId': cityId.toString(),
    };

    if (tripDate != null) queryParams['tripDate'] = tripDate;

    final uri = Uri.parse('$_baseUrl/transit/GetDistrictHourlySpeeds')
        .replace(queryParameters: queryParams);
    final endpoint = '/transit/GetDistrictHourlySpeeds?${uri.query}';

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'text/plain'},
      );

      final data = _handleResponse(response, endpoint);
      final speedsData = data['speeds'] as List<dynamic>?;

      if (speedsData == null) {
        throw ApiException(
          message: 'Invalid response format: missing speeds array',
          endpoint: endpoint,
        );
      }

      return speedsData
          .map((speed) => DistrictHourlySpeed.fromJson(speed as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e', endpoint: endpoint);
    }
  }

}