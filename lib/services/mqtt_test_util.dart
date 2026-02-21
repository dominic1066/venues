import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Utility class for testing MQTT functionality
class MqttTestUtil {
  static const String _testClientId = 'venues_test_publisher';
  
  /// Send test transit messages to MQTT broker for testing
  static Future<bool> sendTestMessages({
    String brokerHost = 'localhost',
    int brokerPort = 1883,
    String? username,
    String? password,
    String cityId = 'test-city',
    int messageCount = 5,
  }) async {
    MqttServerClient? client;
    
    try {
      // initialise test client
      final clientId = '${_testClientId}_${DateTime.now().millisecondsSinceEpoch}';
      client = MqttServerClient(brokerHost, clientId);
      client.port = brokerPort;
      client.keepAlivePeriod = 20;
      client.connectTimeoutPeriod = 10;
      client.logging(on: true);

      // Connect to broker
      debugPrint('🧪 MQTT Test: Connecting to $brokerHost:$brokerPort');
      await client.connect(username, password);
      
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        debugPrint('❌ MQTT Test: Failed to connect');
        return false;
      }

      debugPrint('✅ MQTT Test: Connected, sending $messageCount test messages');

      // Send test messages
      for (int i = 0; i < messageCount; i++) {
        await _sendTestLiveTrip(client, cityId, i);
        await _sendTestTripObservation(client, cityId, i);
        await _sendTestTripData(client, cityId, i);
        
        // Wait between messages
        await Future.delayed(const Duration(seconds: 1));
      }

      debugPrint('✅ MQTT Test: All test messages sent successfully');
      return true;
      
    } catch (e) {
      debugPrint('❌ MQTT Test: Error sending test messages: $e');
      return false;
    } finally {
      client?.disconnect();
    }
  }

  /// Send a test live trip message
  static Future<void> _sendTestLiveTrip(MqttServerClient client, String cityId, int index) async {
    final random = Random();
    
    final liveTrip = {
      'trip_id': 'test-trip-${index + 1}',
      'direction_id': random.nextInt(2),
      'route_short_name': ['A${index + 1}', 'B${index + 1}', 'C${index + 1}'][random.nextInt(3)],
      'route_desc': 'Test Route ${index + 1} - Downtown to Airport',
      'route_color': random.nextInt(0xFFFFFF),
    };

    final topic = 'transit/$cityId/live_trips';
    final payload = json.encode(liveTrip);
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('📤 MQTT Test: Sent live trip to $topic');
  }

  /// Send a test trip observation message
  static Future<void> _sendTestTripObservation(MqttServerClient client, String cityId, int index) async {
    final random = Random();
    
    // Generate coordinates around a test area (e.g., San Francisco-ish area)
    final baseLat = 37.7749 + (random.nextDouble() - 0.5) * 0.1;
    final baseLon = -122.4194 + (random.nextDouble() - 0.5) * 0.1;
    
    final observation = {
      'lat': baseLat,
      'long': baseLon, // Note: API uses 'long' not 'lon'
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'bearing': random.nextDouble() * 360,
    };

    final topic = 'transit/$cityId/trip_observations';
    final payload = json.encode(observation);
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('📤 MQTT Test: Sent trip observation to $topic');
  }

  /// Send a test trip data message
  static Future<void> _sendTestTripData(MqttServerClient client, String cityId, int index) async {
    final random = Random();
    
    final tripData = {
      'trip_id': 'test-trip-${index + 1}',
      'route_id': 'test-route-${index + 1}',
      'service_id': 'weekday-service',
      'trip_headsign': 'Test Destination ${index + 1}',
      'direction_id': random.nextInt(2),
      'shape_id': 'test-shape-${index + 1}',
    };

    final topic = 'transit/$cityId/trip_data';
    final payload = json.encode(tripData);
    
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('📤 MQTT Test: Sent trip data to $topic');
  }

  /// Send a continuous stream of test messages (useful for testing)
  static StreamController<String>? _testStreamController;
  
  static Stream<String> startContinuousTestMessages({
    String brokerHost = 'localhost',
    int brokerPort = 1883,
    String? username,
    String? password,
    String cityId = 'test-city',
    Duration interval = const Duration(seconds: 5),
  }) {
    _testStreamController = StreamController<String>.broadcast();
    
    _sendContinuousMessages(
      brokerHost: brokerHost,
      brokerPort: brokerPort,
      username: username,
      password: password,
      cityId: cityId,
      interval: interval,
    );
    
    return _testStreamController!.stream;
  }
  
  static void stopContinuousTestMessages() {
    _testStreamController?.close();
    _testStreamController = null;
  }
  
  static Future<void> _sendContinuousMessages({
    required String brokerHost,
    required int brokerPort,
    String? username,
    String? password,
    required String cityId,
    required Duration interval,
  }) async {
    MqttServerClient? client;
    int messageCounter = 0;
    
    try {
      // initialise client
      final clientId = '${_testClientId}_continuous_${DateTime.now().millisecondsSinceEpoch}';
      client = MqttServerClient(brokerHost, clientId);
      client.port = brokerPort;
      client.keepAlivePeriod = 60;
      client.connectTimeoutPeriod = 30;
      
      await client.connect(username, password);
      
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        _testStreamController?.addError('Failed to connect to MQTT broker');
        return;
      }
      
      _testStreamController?.add('Connected to MQTT broker, starting continuous messages');
      
      // Send messages continuously
      while (_testStreamController != null && !_testStreamController!.isClosed) {
        messageCounter++;
        
        await _sendTestLiveTrip(client, cityId, messageCounter);
        await _sendTestTripObservation(client, cityId, messageCounter);
        
        _testStreamController?.add('Sent message batch $messageCounter');
        
        await Future.delayed(interval);
      }
      
    } catch (e) {
      _testStreamController?.addError('Error in continuous messaging: $e');
    } finally {
      client?.disconnect();
      _testStreamController?.add('Disconnected from MQTT broker');
    }
  }
}