import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/models.dart';

enum VenuesMqttConnectionState {
  disconnected,
  connecting,
  connected,
  connectionError,
  subscribed
}

class MqttService {
  static const String _clientIdentifier = 'venues_flutter_client';
  static const int _keepAlivePeriod = 60;
  static const int _connectionTimeout = 30;

  // Default MQTT broker configuration
  String _brokerHost = 'localhost';
  int _brokerPort = 1883;
  String? _username;
  String? _password;

  MqttServerClient? _client;
  final bool enableDiagnostics;

  // Connection state
  VenuesMqttConnectionState _connectionState = VenuesMqttConnectionState.disconnected;
  VenuesMqttConnectionState get connectionState => _connectionState;

  // Stream controllers for different message types
  final StreamController<LiveTrip> _liveTripsController = StreamController<LiveTrip>.broadcast();
  final StreamController<TripObservation> _tripObservationsController = StreamController<TripObservation>.broadcast();
  final StreamController<TripData> _tripDataController = StreamController<TripData>.broadcast();
  final StreamController<VenuesMqttConnectionState> _connectionStateController = StreamController<VenuesMqttConnectionState>.broadcast();

  // Public streams
  Stream<LiveTrip> get liveTripsStream => _liveTripsController.stream;
  Stream<TripObservation> get tripObservationsStream => _tripObservationsController.stream;
  Stream<TripData> get tripDataStream => _tripDataController.stream;
  Stream<VenuesMqttConnectionState> get connectionStateStream => _connectionStateController.stream;

  // Topic subscriptions
  final Set<String> _subscribedTopics = {};

  MqttService({
    String? brokerHost,
    int? brokerPort,
    String? username,
    String? password,
    this.enableDiagnostics = false,
  }) {
    if (brokerHost != null) _brokerHost = brokerHost;
    if (brokerPort != null) _brokerPort = brokerPort;
    _username = username;
    _password = password;
  }

  /// initialise and configure the MQTT client
  Future<void> _initialiseClient() async {
    final clientId = '${_clientIdentifier}_${DateTime.now().millisecondsSinceEpoch}';
    
    _client = MqttServerClient(_brokerHost, clientId);
    _client!.port = _brokerPort;
    _client!.keepAlivePeriod = _keepAlivePeriod;
    _client!.connectTimeoutPeriod = _connectionTimeout;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;

    // Set up logging if diagnostics are enabled
    if (enableDiagnostics) {
      _client!.logging(on: true);
    }

    // Set up connection message
    final connMessage = MqttConnectMessage()
        .authenticateAs(_username, _password)
        .withWillTopic('clients/$clientId/status')
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce)
        .withClientIdentifier(clientId)
        .startClean();
    
    _client!.keepAlivePeriod = _keepAlivePeriod;
    
    _client!.connectionMessage = connMessage;

    // Set up event handlers
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onUnsubscribed = _onUnsubscribed;
    _client!.onSubscribed = _onSubscribed;
    _client!.onSubscribeFail = _onSubscribeFail;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;

    // Set up message handler
    if (_client!.updates != null) {
      _client!.updates!.listen(_onMessage);
    }
  }

  /// Connect to the MQTT broker
  Future<bool> connect() async {
    try {
      _updateConnectionState(VenuesMqttConnectionState.connecting);
      
      await _initialiseClient();
      
      if (enableDiagnostics) {
        debugPrint('🔌 MQTT: Attempting to connect to $_brokerHost:$_brokerPort');
      }

      await _client!.connect(_username, _password);
      
      final connectionStatus = _client!.connectionStatus;
      return connectionStatus?.state == MqttConnectionState.connected;
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Connection failed: $e');
      }
      _updateConnectionState(VenuesMqttConnectionState.connectionError);
      return false;
    }
  }

  /// Disconnect from the MQTT broker
  Future<void> disconnect() async {
    try {
      if (_client != null) {
        _client!.disconnect();
      }
      _updateConnectionState(VenuesMqttConnectionState.disconnected);
      _subscribedTopics.clear();
      
      if (enableDiagnostics) {
        debugPrint('🔌 MQTT: Disconnected from broker');
      }
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Disconnect error: $e');
      }
    }
  }

  /// Subscribe to transit-related topics
  Future<bool> subscribeToTransitUpdates({String? cityId}) async {
    if (_client == null || _connectionState != VenuesMqttConnectionState.connected) {
      if (enableDiagnostics) {
        debugPrint('⚠️ MQTT: Cannot subscribe - not connected');
      }
      return false;
    }

    final topics = _getTransitTopics(cityId: cityId);
    bool allSuccessful = true;

    for (final topic in topics) {
      try {
        if (_client != null) {
          _client!.subscribe(topic, MqttQos.atLeastOnce);
        }
        _subscribedTopics.add(topic);
        
        if (enableDiagnostics) {
          debugPrint('📡 MQTT: Subscribed to $topic');
        }
      } catch (e) {
        if (enableDiagnostics) {
          debugPrint('❌ MQTT: Failed to subscribe to $topic: $e');
        }
        allSuccessful = false;
      }
    }

    if (allSuccessful && _subscribedTopics.isNotEmpty) {
      _updateConnectionState(VenuesMqttConnectionState.subscribed);
    }

    return allSuccessful;
  }

  /// Subscribe to a custom topic
  Future<bool> subscribeToTopic(String topic) async {
    if (_client == null || _connectionState != VenuesMqttConnectionState.connected) {
      if (enableDiagnostics) {
        debugPrint('⚠️ MQTT: Cannot subscribe to $topic - not connected');
      }
      return false;
    }

    try {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      _subscribedTopics.add(topic);
      
      if (enableDiagnostics) {
        debugPrint('📡 MQTT: Subscribed to custom topic: $topic');
      }
      return true;
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Failed to subscribe to $topic: $e');
      }
      return false;
    }
  }

  /// Unsubscribe from all topics
  Future<void> unsubscribeFromAll() async {
    if (_client == null) return;

    for (final topic in _subscribedTopics.toList()) {
      try {
        if (_client != null) {
          _client!.unsubscribe(topic);
        }
        if (enableDiagnostics) {
          debugPrint('📡 MQTT: Unsubscribed from $topic');
        }
      } catch (e) {
        if (enableDiagnostics) {
          debugPrint('❌ MQTT: Failed to unsubscribe from $topic: $e');
        }
      }
    }
    
    _subscribedTopics.clear();
    if (_connectionState == VenuesMqttConnectionState.subscribed) {
      _updateConnectionState(VenuesMqttConnectionState.connected);
    }
  }

  /// Get list of transit-related MQTT topics
  List<String> _getTransitTopics({String? cityId}) {
    return [];
    // final basePath = cityId != null ? 'transit/$cityId' : 'transit/+';
    
    // return [
    //   '$basePath/live_trips',           // Live trip updates
    //   '$basePath/trip_observations',    // Real-time position updates
    //   '$basePath/trip_data',           // Complete trip information
    //   '$basePath/route_updates',       // Route changes
    //   '$basePath/alerts',              // Service alerts
    // ];
  }

  /// Handle incoming MQTT messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );

      if (enableDiagnostics) {
        debugPrint('📨 MQTT: Received message on $topic');
        debugPrint('📨 MQTT: Payload length: ${payload.length} characters');
      }

      _processMessage(topic, payload);
    }
  }

  /// Process and route messages based on topic
  void _processMessage(String topic, String payload) {
    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      
      if (topic.endsWith('/live_trips')) {
        _handleLiveTripMessage(data);
      } else if (topic.endsWith('/trip_observations')) {
        _handleTripObservationMessage(data);
      } else if (topic.endsWith('/trip_data')) {
        _handleTripDataMessage(data);
      } else if (topic.endsWith('/route_updates')) {
        _handleRouteUpdateMessage(data);
      } else if (topic.endsWith('/alerts')) {
        _handleAlertMessage(data);
      }
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Failed to process message from $topic: $e');
      }
    }
  }

  /// Handle live trip messages
  void _handleLiveTripMessage(Map<String, dynamic> data) {
    try {
      final liveTrip = LiveTrip.fromJson(data);
      
      // Only add to controller if it's not closed
      if (!_liveTripsController.isClosed) {
        _liveTripsController.add(liveTrip);
      }
      
      if (enableDiagnostics) {
        debugPrint('🚊 MQTT: Processed live trip: ${liveTrip.tripId}');
      }
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Failed to parse live trip: $e');
      }
    }
  }

  /// Handle trip observation messages
  void _handleTripObservationMessage(Map<String, dynamic> data) {
    try {
      final observation = TripObservation.fromJson(data);
      
      // Only add to controller if it's not closed
      if (!_tripObservationsController.isClosed) {
        _tripObservationsController.add(observation);
      }
      
      if (enableDiagnostics) {
        debugPrint('📍 MQTT: Processed trip observation at (${observation.lat}, ${observation.lon})');
      }
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Failed to parse trip observation: $e');
      }
    }
  }

  /// Handle trip data messages
  void _handleTripDataMessage(Map<String, dynamic> data) {
    try {
      // Extract required fields from data map for TripData constructor
      final tripData = TripData.fromJson(
        data,
        data['cityId'] ?? 0,
        data['tripId'] ?? '',
        data['direction'] ?? 0,
        data['routeShortName'] ?? '',
        data['routeDesc'] ?? '',
        data['routeColour'] ?? 0,
        data['headsign'] ?? ''
      );
      
      // Only add to controller if it's not closed
      if (!_tripDataController.isClosed) {
        _tripDataController.add(tripData);
      }
      
      if (enableDiagnostics) {
        debugPrint('🚍 MQTT: Processed trip data: ${tripData.tripId}');
      }
    } catch (e) {
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Failed to parse trip data: $e');
      }
    }
  }

  /// Handle route update messages
  void _handleRouteUpdateMessage(Map<String, dynamic> data) {
    if (enableDiagnostics) {
      debugPrint('🛤️ MQTT: Received route update');
    }
    // Route updates can be handled based on your specific requirements
  }

  /// Handle alert messages
  void _handleAlertMessage(Map<String, dynamic> data) {
    if (enableDiagnostics) {
      debugPrint('🚨 MQTT: Received transit alert');
    }
    // Alerts can be handled based on your specific requirements
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(VenuesMqttConnectionState newState) {
    _connectionState = newState;
    
    // Only add to controller if it's not closed
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
    
    if (enableDiagnostics) {
      debugPrint('🔌 MQTT: Connection state changed to $newState');
    }
  }

  // Event handlers
  void _onConnected() {
    _updateConnectionState(VenuesMqttConnectionState.connected);
    if (enableDiagnostics) {
      debugPrint('✅ MQTT: Connected to $_brokerHost:$_brokerPort');
    }
  }

  void _onDisconnected() {
    _updateConnectionState(VenuesMqttConnectionState.disconnected);
    if (enableDiagnostics) {
      debugPrint('🔌 MQTT: Disconnected from broker');
    }
  }

  void _onSubscribed(String topic) {
    if (enableDiagnostics) {
      debugPrint('✅ MQTT: Successfully subscribed to $topic');
    }
  }

  void _onUnsubscribed(String? topic) {
    if (topic != null) {
      _subscribedTopics.remove(topic);
      if (enableDiagnostics) {
        debugPrint('❌ MQTT: Unsubscribed from $topic');
      }
    }
  }

  void _onSubscribeFail(String topic) {
    if (enableDiagnostics) {
      debugPrint('❌ MQTT: Failed to subscribe to $topic');
    }
  }

  void _onAutoReconnect() {
    if (enableDiagnostics) {
      debugPrint('🔄 MQTT: Auto-reconnecting...');
    }
  }

  void _onAutoReconnected() {
    if (enableDiagnostics) {
      debugPrint('✅ MQTT: Auto-reconnected successfully');
    }
  }

  /// Get current subscribed topics
  Set<String> get subscribedTopics => Set.from(_subscribedTopics);

  /// Get raw MQTT message stream for custom handling
  Stream<List<MqttReceivedMessage<MqttMessage>>>? get messageStream {
    if (_client?.updates != null) {
      return _client!.updates!;
    }
    return null;
  }

  /// Check if connected to broker
  bool get isConnected => _connectionState == VenuesMqttConnectionState.connected || 
                          _connectionState == VenuesMqttConnectionState.subscribed;

  /// Dispose resources
  void dispose() {
    _liveTripsController.close();
    _tripObservationsController.close();
    _tripDataController.close();
    _connectionStateController.close();
    
    if (_client != null) {
      _client!.disconnect();
    }
    
    if (enableDiagnostics) {
      debugPrint('🧹 MQTT: Service disposed');
    }
  }
}