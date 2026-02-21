# MQTT Integration for Real-Time Transit Updates

This document describes the MQTT integration added to the Venues & Transit Management application for receiving real-time transit information updates.

## Overview

The MQTT integration allows the application to:
- Connect to MQTT brokers to receive real-time transit updates
- Subscribe to topics for live trip information, position updates, and route data
- Process and display real-time transit information in the UI
- Handle connection management with automatic reconnection

## Architecture

### Core Components

1. **MqttService** (`lib/services/mqtt_service.dart`)
   - Low-level MQTT client wrapper
   - Handles broker connection, subscription management
   - Processes raw MQTT messages and routes them to appropriate streams

2. **TransitMqttManager** (`lib/services/transit_mqtt_manager.dart`)
   - High-level manager for transit-specific MQTT functionality
   - Aggregates and caches transit data from MQTT messages
   - Provides convenient APIs for accessing live transit information

3. **MqttConfig** (`lib/config/mqtt_config.dart`)
   - Configuration class for MQTT broker settings
   - Provides preset configurations for common brokers

4. **UI Components** (`lib/widgets/mqtt_widgets.dart`)
   - Widgets for displaying MQTT connection status
   - Real-time transit updates display components
   - Position updates visualization

5. **MQTT Transit Page** (`lib/pages/mqtt_transit_page.dart`)
   - Dedicated page for viewing real-time transit updates
   - Tabbed interface showing live trips and position data
   - Connection management and error handling

### Message Flow

```
MQTT Broker → MqttService → TransitMqttManager → UI Components
              ↓
         Parse & Route Messages
              ↓
         Update Data Streams
              ↓
         Notify UI Components
```

## MQTT Topics

The application subscribes to the following transit-related topics:

- `transit/{cityId}/live_trips` - Live trip updates
- `transit/{cityId}/trip_observations` - Real-time position updates  
- `transit/{cityId}/trip_data` - Complete trip information
- `transit/{cityId}/route_updates` - Route changes
- `transit/{cityId}/alerts` - Service alerts

Where `{cityId}` can be a specific city ID or `+` as a wildcard to receive updates for all cities.

## Message Formats

### Live Trips (`live_trips`)
```json
{
  "trip_id": "string",
  "direction_id": 0,
  "route_short_name": "A1",
  "route_desc": "Downtown to Airport",
  "route_color": 16711680
}
```

### Trip Observations (`trip_observations`)  
```json
{
  "lat": 37.7749,
  "long": -122.4194,
  "timestamp": 1640995200,
  "bearing": 45.5
}
```

### Trip Data (`trip_data`)
```json
{
  "trip_id": "string",
  "route_id": "string", 
  "service_id": "string",
  "trip_headsign": "string",
  "direction_id": 0,
  "shape_id": "string"
}
```

## Configuration

### MQTT Broker Settings

Configure MQTT broker connection in `main.dart`:

```dart
MqttConfigProvider(
  config: MqttConfig.localhost(enableDiagnostics: true),
  // or
  config: MqttConfig.production(
    host: 'your-broker.com',
    port: 1883,
    username: 'your-username',
    password: 'your-password',
    useTls: true,
  ),
  child: MaterialApp(...),
)
```

### Preset Configurations

- `MqttConfig.localhost()` - Local development broker
- `MqttConfig.mosquittoTest()` - Eclipse Mosquitto test broker
- `MqttConfig.hivemqPublic()` - HiveMQ public broker
- `MqttConfig.production()` - Custom production broker

## Usage

### Basic Integration

```dart
// initialise MQTT manager
final mqttManager = TransitMqttManager(
  config: MqttConfig.localhost(),
  enableDiagnostics: true,
);

// Connect and subscribe
await mqttManager.initialise(cityId: 'your-city');

// Listen to live trips
mqttManager.liveTripsStream.listen((liveTrips) {
  // Handle live trip updates
  print('Received ${liveTrips.length} live trips');
});

// Listen to position updates  
mqttManager.tripObservationsStream.listen((observations) {
  // Handle position updates
  print('Received position updates');
});
```

### UI Integration

```dart
// Display connection status
MqttConnectionWidget(mqttManager: mqttManager)

// Display live transit updates
LiveTransitUpdatesWidget(mqttManager: mqttManager)

// Display position updates
TripObservationsWidget(mqttManager: mqttManager)
```

## Testing

### Test Utility

Use `MqttTestUtil` for testing MQTT functionality:

```dart
// Send test messages
await MqttTestUtil.sendTestMessages(
  brokerHost: 'localhost',
  brokerPort: 1883,
  cityId: 'test-city',
  messageCount: 10,
);

// Start continuous test messages
final stream = MqttTestUtil.startContinuousTestMessages(
  brokerHost: 'localhost',
  cityId: 'test-city',
  interval: Duration(seconds: 5),
);

// Stop continuous messages
MqttTestUtil.stopContinuousTestMessages();
```

### Setting Up a Test Broker

#### Option 1: Local Mosquitto Broker

1. Install Mosquitto MQTT broker
2. Start broker: `mosquitto -v -p 1883`
3. Use configuration: `MqttConfig.localhost()`

#### Option 2: Public Test Brokers

```dart
// Eclipse Mosquitto test broker
MqttConfig.mosquittoTest()

// HiveMQ public broker  
MqttConfig.hivemqPublic()
```

## Error Handling

The MQTT integration includes comprehensive error handling:

- **Connection Errors**: Automatic reconnection with exponential backoff
- **Subscription Failures**: Individual topic subscription retry
- **Message Parsing Errors**: Graceful handling of malformed messages
- **Network Issues**: Connection state monitoring and recovery

## Diagnostics

Enable diagnostics for detailed logging:

```dart
TransitMqttManager(
  config: MqttConfig.localhost(enableDiagnostics: true),
  enableDiagnostics: true,
)
```

Diagnostic output includes:
- Connection status changes
- Message reception and processing
- Subscription management
- Error details and recovery attempts

## Performance Considerations

- **Message Caching**: Recent messages are cached to prevent UI flicker
- **Stream Buffering**: Broadcast streams allow multiple listeners
- **Memory Management**: Automatic cleanup of old observations
- **Connection Pooling**: Single connection shared across the app

## Security

For production deployments:

1. **Use TLS/SSL**: Enable `useTls: true` in configuration
2. **Authentication**: Provide username/password credentials  
3. **Topic Permissions**: Configure broker ACLs for topic access
4. **Certificate Validation**: Implement custom certificate validation if needed

## Dependencies

- `mqtt_client: ^10.2.0` - MQTT client library for Flutter

## Navigation

The MQTT functionality is accessible through:
- Main navigation drawer: "Live Updates" → "MQTT Real-time"
- Route: `/mqtt-transit`

## Troubleshooting

### Common Issues

1. **Connection Timeouts**
   - Check broker hostname/port
   - Verify network connectivity
   - Check firewall settings

2. **No Messages Received**
   - Verify topic subscriptions
   - Check message publisher
   - Enable diagnostics for debugging

3. **Authentication Failures**
   - Verify username/password
   - Check broker ACL configuration

4. **Certificate Errors** (TLS)
   - Verify broker certificate
   - Check system time accuracy
   - Consider certificate validation customization

### Debug Steps

1. Enable diagnostics in configuration
2. Check Flutter debug console for MQTT logs
3. Verify broker status and logs
4. Test with MQTT client tools (e.g., mosquitto_pub/sub)
5. Use `MqttTestUtil` to send test messages