import 'package:flutter/material.dart';
import '../services/transit_mqtt_manager.dart';
import '../models/models.dart';

/// Widget that displays MQTT connection status and controls
class MqttConnectionWidget extends StatefulWidget {
  final TransitMqttManager mqttManager;

  const MqttConnectionWidget({
    super.key,
    required this.mqttManager,
  });

  @override
  State<MqttConnectionWidget> createState() => _MqttConnectionWidgetState();
}

class _MqttConnectionWidgetState extends State<MqttConnectionWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VenuesMqttConnectionState>(
      stream: widget.mqttManager.connectionStateStream,
      builder: (context, snapshot) {
        final connectionState = snapshot.data ?? VenuesMqttConnectionState.disconnected;
        
        return Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: _getConnectionColor(connectionState).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _getConnectionColor(connectionState)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getConnectionIcon(connectionState),
                color: _getConnectionColor(connectionState),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _getConnectionText(connectionState),
                style: TextStyle(
                  color: _getConnectionColor(connectionState),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (connectionState == VenuesMqttConnectionState.subscribed) ...[
                const SizedBox(width: 8),
                Text(
                  '(${widget.mqttManager.subscribedTopics.length} topics)',
                  style: TextStyle(
                    color: _getConnectionColor(connectionState),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getConnectionColor(VenuesMqttConnectionState state) {
    switch (state) {
      case VenuesMqttConnectionState.connected:
      case VenuesMqttConnectionState.subscribed:
        return Colors.green;
      case VenuesMqttConnectionState.connecting:
        return Colors.orange;
      case VenuesMqttConnectionState.connectionError:
        return Colors.red;
      case VenuesMqttConnectionState.disconnected:
        return Colors.grey;
    }
  }

  IconData _getConnectionIcon(VenuesMqttConnectionState state) {
    switch (state) {
      case VenuesMqttConnectionState.connected:
      case VenuesMqttConnectionState.subscribed:
        return Icons.wifi;
      case VenuesMqttConnectionState.connecting:
        return Icons.wifi_find;
      case VenuesMqttConnectionState.connectionError:
        return Icons.wifi_off;
      case VenuesMqttConnectionState.disconnected:
        return Icons.portable_wifi_off;
    }
  }

  String _getConnectionText(VenuesMqttConnectionState state) {
    switch (state) {
      case VenuesMqttConnectionState.connected:
        return 'MQTT Connected';
      case VenuesMqttConnectionState.subscribed:
        return 'MQTT Subscribed';
      case VenuesMqttConnectionState.connecting:
        return 'MQTT Connecting...';
      case VenuesMqttConnectionState.connectionError:
        return 'MQTT Error';
      case VenuesMqttConnectionState.disconnected:
        return 'MQTT Disconnected';
    }
  }
}

/// Widget that displays live transit updates from MQTT
class LiveTransitUpdatesWidget extends StatefulWidget {
  final TransitMqttManager mqttManager;
  final int maxDisplayItems;

  const LiveTransitUpdatesWidget({
    super.key,
    required this.mqttManager,
    this.maxDisplayItems = 10,
  });

  @override
  State<LiveTransitUpdatesWidget> createState() => _LiveTransitUpdatesWidgetState();
}

class _LiveTransitUpdatesWidgetState extends State<LiveTransitUpdatesWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.directions_transit, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'Live Transit Updates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            MqttConnectionWidget(mqttManager: widget.mqttManager),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<Map<String, LiveTrip>>(
            stream: widget.mqttManager.liveTripsStream,
            builder: (context, snapshot) {
              final liveTrips = snapshot.data ?? {};
              
              if (liveTrips.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_transit_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No live transit updates',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Waiting for MQTT messages...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final trips = liveTrips.values.take(widget.maxDisplayItems).toList();

              return ListView.builder(
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _buildTripCard(trip);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(LiveTrip trip) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(trip.routeColour).withValues(alpha: 0.8),
          child: Text(
            trip.routeShortName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          trip.routeDesc,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Trip ID: ${trip.tripId} • Direction: ${trip.directionId}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.radio_button_checked, color: Colors.green),
      ),
    );
  }
}

/// Widget that displays real-time position updates from MQTT
class TripObservationsWidget extends StatefulWidget {
  final TransitMqttManager mqttManager;
  final int maxDisplayItems;

  const TripObservationsWidget({
    super.key,
    required this.mqttManager,
    this.maxDisplayItems = 20,
  });

  @override
  State<TripObservationsWidget> createState() => _TripObservationsWidgetState();
}

class _TripObservationsWidgetState extends State<TripObservationsWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.my_location, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Real-time Positions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<Map<String, List<TripObservation>>>(
            stream: widget.mqttManager.tripObservationsStream,
            builder: (context, snapshot) {
              final observationsMap = snapshot.data ?? {};
              
              if (observationsMap.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No position updates',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Flatten all observations and sort by timestamp
              final allObservations = <TripObservation>[];
              for (final observations in observationsMap.values) {
                allObservations.addAll(observations);
              }
              allObservations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

              final displayObservations = allObservations.take(widget.maxDisplayItems).toList();

              return ListView.builder(
                itemCount: displayObservations.length,
                itemBuilder: (context, index) {
                  final observation = displayObservations[index];
                  return _buildObservationCard(observation);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildObservationCard(TripObservation observation) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(observation.timestamp * 1000);
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.location_on, color: Colors.red, size: 20),
        title: Text(
          '${observation.lat.toStringAsFixed(5)}, ${observation.lon.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Bearing: ${observation.bearing.toStringAsFixed(1)}° • $timeStr',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          timeStr,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }
}