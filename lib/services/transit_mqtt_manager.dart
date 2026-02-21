import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/mqtt_service.dart';
import '../models/models.dart';
import '../config/mqtt_config.dart';

/// Manager for handling MQTT-based transit updates
class TransitMqttManager {
  final MqttService _mqttService;
  final bool enableDiagnostics;

  // Stream controllers for aggregated transit data
  final StreamController<Map<String, LiveTrip>> _liveTripsController = 
      StreamController<Map<String, LiveTrip>>.broadcast();
  final StreamController<Map<String, List<TripObservation>>> _tripObservationsController = 
      StreamController<Map<String, List<TripObservation>>>.broadcast();

  // Data storage
  final Map<String, LiveTrip> _liveTrips = {};
  final Map<String, List<TripObservation>> _tripObservations = {};
  final Map<String, TripData> _tripDataCache = {};

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Public streams
  Stream<Map<String, LiveTrip>> get liveTripsStream => _liveTripsController.stream;
  Stream<Map<String, List<TripObservation>>> get tripObservationsStream => 
      _tripObservationsController.stream;
  Stream<VenuesMqttConnectionState> get connectionStateStream => _mqttService.connectionStateStream;

  TransitMqttManager({
    MqttConfig? config,
    this.enableDiagnostics = false,
  }) : _mqttService = MqttService(
          brokerHost: config?.brokerHost,
          brokerPort: config?.brokerPort,
          username: config?.username,
          password: config?.password,
          enableDiagnostics: config?.enableDiagnostics ?? enableDiagnostics,
        ) {
    _setupMessageHandlers();
  }

  /// Set up message handlers for different types of transit updates
  void _setupMessageHandlers() {
    // Handle live trip updates
    _subscriptions.add(
      _mqttService.liveTripsStream.listen(
        _handleLiveTripUpdate,
        onError: (error) {
          if (enableDiagnostics) {
            debugPrint('❌ Transit MQTT: Live trip stream error: $error');
          }
        },
      ),
    );

    // Handle trip observations (position updates)
    _subscriptions.add(
      _mqttService.tripObservationsStream.listen(
        _handleTripObservationUpdate,
        onError: (error) {
          if (enableDiagnostics) {
            debugPrint('❌ Transit MQTT: Trip observation stream error: $error');
          }
        },
      ),
    );

    // Handle complete trip data
    _subscriptions.add(
      _mqttService.tripDataStream.listen(
        _handleTripDataUpdate,
        onError: (error) {
          if (enableDiagnostics) {
            debugPrint('❌ Transit MQTT: Trip data stream error: $error');
          }
        },
      ),
    );
  }

  /// Connect to MQTT broker and subscribe to transit updates
  Future<bool> initialise({String? cityId}) async {
    try {
      if (enableDiagnostics) {
        debugPrint('🚊 Transit MQTT: initialising connection...');
      }

      final connected = await _mqttService.connect();
      if (!connected) {
        if (enableDiagnostics) {
          debugPrint('❌ Transit MQTT: Failed to connect to broker');
        }
        return false;
      }

      final subscribed = await _mqttService.subscribeToTransitUpdates(cityId: cityId);
      if (!subscribed) {
        if (enableDiagnostics) {
          debugPrint('❌ Transit MQTT: Failed to subscribe to transit topics');
        }
        return false;
      }

      if (enableDiagnostics) {
        debugPrint('✅ Transit MQTT: Successfully initialised and subscribed');
      }

      return true;
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ Transit MQTT: initialisation error: $e');
      }
      return false;
    }
  }

  /// Disconnect from MQTT broker
  Future<void> shutdown() async {
    try {
      await _mqttService.unsubscribeFromAll();
      await _mqttService.disconnect();
      
      if (enableDiagnostics) {
        debugPrint('🚊 Transit MQTT: Shutdown complete');
      }
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ Transit MQTT: Shutdown error: $e');
      }
    }
  }

  /// Handle live trip updates
  void _handleLiveTripUpdate(LiveTrip liveTrip) {
    _liveTrips[liveTrip.tripId] = liveTrip;
    _liveTripsController.add(Map.from(_liveTrips));

    if (enableDiagnostics) {
      debugPrint('🚊 Transit MQTT: Updated live trip ${liveTrip.tripId} (${liveTrip.routeShortName})');
    }
  }

  /// Handle trip observation updates (real-time positions)
  void _handleTripObservationUpdate(TripObservation observation) {
    // Group observations by a key (you may need to add tripId to TripObservation model)
    // For now, we'll use timestamp as a simple grouping mechanism
    final key = 'obs_${observation.timestamp}';
    
    if (!_tripObservations.containsKey(key)) {
      _tripObservations[key] = [];
    }
    
    _tripObservations[key]!.add(observation);
    
    // Keep only recent observations (last 100 per key)
    if (_tripObservations[key]!.length > 100) {
      _tripObservations[key] = _tripObservations[key]!.sublist(
        _tripObservations[key]!.length - 100,
      );
    }

    _tripObservationsController.add(Map.from(_tripObservations));

    if (enableDiagnostics) {
      debugPrint('📍 Transit MQTT: Updated trip observation at (${observation.lat}, ${observation.lon})');
    }
  }

  /// Handle complete trip data updates
  void _handleTripDataUpdate(TripData tripData) {
    _tripDataCache[tripData.tripId] = tripData;

    if (enableDiagnostics) {
      debugPrint('🚍 Transit MQTT: Updated trip data for ${tripData.tripId}');
    }
  }

  /// Get current live trips
  Map<String, LiveTrip> get currentLiveTrips => Map.from(_liveTrips);

  /// Get current trip observations
  Map<String, List<TripObservation>> get currentTripObservations => Map.from(_tripObservations);

  /// Get cached trip data
  Map<String, TripData> get cachedTripData => Map.from(_tripDataCache);

  /// Get access to the underlying MQTT service for custom subscriptions
  MqttService get mqttService => _mqttService;

  /// Get live trip by ID
  LiveTrip? getLiveTrip(String tripId) => _liveTrips[tripId];

  /// Get trip data by ID
  TripData? getTripData(String tripId) => _tripDataCache[tripId];

  /// Get observations for a specific key
  List<TripObservation>? getObservations(String key) => _tripObservations[key];

  /// Clear all cached data
  void clearCache() {
    _liveTrips.clear();
    _tripObservations.clear();
    _tripDataCache.clear();

    if (enableDiagnostics) {
      debugPrint('🧹 Transit MQTT: Cache cleared');
    }
  }

  /// Get connection status
  bool get isConnected => _mqttService.isConnected;

  /// Get current connection state
  VenuesMqttConnectionState get connectionState => _mqttService.connectionState;

  /// Get subscribed topics
  Set<String> get subscribedTopics => _mqttService.subscribedTopics;

  /// Dispose resources
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _liveTripsController.close();
    _tripObservationsController.close();

    _mqttService.dispose();

    if (enableDiagnostics) {
      debugPrint('🧹 Transit MQTT: Manager disposed');
    }
  }
}