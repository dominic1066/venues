import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../services/transit_service.dart';
// import '../services/mqtt_service.dart';
import '../services/transit_mqtt_manager.dart';
import '../models/models.dart';
import '../config/api_config.dart';
// import '../config/mqtt_config.dart';
import '../widgets/server_selector.dart';
import '../main.dart';
import 'dart:math';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  late TransitService _transitService;
  TransitMqttManager? _mqttManager;
  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  bool _isLoading = true;
  String? _error;

  Map<String, LiveTrip> _liveTrips = {};
  final Set<String> _finishedTrips = {};
  bool _isLoadingTrips = false;
  String? _tripsError;
  Map<String, String> _routes = {};

  // Store loaded trip shapes for display on map
  final Map<String, TripShape> _loadedShapes = {};

  // Store loaded trip data (observations), keyed by cityId-tripId
  final Map<String, TripData> _loadedObservations = {};

  // Store MQTT trip statistics, keyed by cityId-tripId
  final Map<String, Map<String, dynamic>> _tripStats = {};

  // Track subscribed MQTT topics to avoid duplicate subscriptions
  final Set<String> _subscribedTopics = {};

  // Timer for periodic refresh
  Timer? _refreshTimer;

  // Default map center (will be updated when a city is selected)
  // LatLng _mapCenter = LatLng(43.6532, -79.3832); // Toronto as default
  LatLng _mapCenter = LatLng(-41.2865, 174.7762); // Wellington as default
  double _mapZoom = 11.0;

  bool _isinitialised = false;

  // City selector position and size
  double _selectorLeft = 16;
  double _selectorTop = 16;
  double _selectorWidth = 400;
  double _selectorHeight = 56;

  // Show shape distances checkbox
  bool _showShapeDistances = false;

  // Helper methods for accessing live trips
  LiveTrip? getLiveTripById(String tripId) => _liveTrips[tripId];
  
  List<LiveTrip> get allLiveTrips => _liveTrips.values.toList();
  
  bool hasLiveTrip(String tripId) => _liveTrips.containsKey(tripId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isinitialised) {
      _transitService = TransitService(
        server: ApiConfig.of(context).server,
        enableDiagnostics: true,
      );
      
      // initialise MQTT manager
      final mqttConfig = MqttConfigProvider.of(context);
      _mqttManager = TransitMqttManager(
        config: mqttConfig,
        enableDiagnostics: mqttConfig.enableDiagnostics,
      );
      _initialiseMqtt();
      
      _isinitialised = true;
      _loadCities();
      // // Start periodic refresh every 30 seconds
      // _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      //   _loadLiveTrips();
      // });
      _loadLiveTrips();
      
      // Add lifecycle observer
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _mqttManager?.dispose();
    _transitService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - ensure MQTT is connected
      if (_mqttManager != null && !_mqttManager!.isConnected) {
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: App resumed, checking MQTT connection...');
        }
        _retryMqttConnection();
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background - could optionally disconnect to save resources
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: App paused, MQTT connection maintained');
      }
    }
  }

  /// initialise MQTT connection
  Future<void> _initialiseMqtt() async {
    if (_mqttManager == null) return;
    
    try {
      // Connect to MQTT broker
      final success = await _mqttManager!.initialise();
      if (success) {
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: MQTT initialised and connected successfully');
        }
        
        // Set up connection state monitoring
        _mqttManager!.connectionStateStream.listen((state) {
          if (_transitService.enableDiagnostics) {
            debugPrint('🗺️ Map: MQTT connection state changed to $state');
          }
          
          // If we get disconnected, try to reconnect
          if (state == VenuesMqttConnectionState.disconnected || 
              state == VenuesMqttConnectionState.connectionError) {
            _retryMqttConnection();
          }
        });
        
        // Set up live trip updates from MQTT
        _mqttManager!.liveTripsStream.listen((liveTripsMap) {
          if (mounted && liveTripsMap.isNotEmpty) {
            setState(() {
              // Update existing live trips with new data from MQTT
              for (var mqttTrip in liveTripsMap.values) {
                _liveTrips[mqttTrip.tripId] = mqttTrip;
              }
            });
            
            if (_transitService.enableDiagnostics) {
              debugPrint('🗺️ Map: Updated ${liveTripsMap.length} live trips from MQTT');
            }
          }
        });
      } else {
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: MQTT initialisation failed, will retry when needed');
        }
      }
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: MQTT initialisation error: $e');
      }
    }
  }

  /// Retry MQTT connection after a delay
  Future<void> _retryMqttConnection() async {
    if (_mqttManager == null) return;
    
    // Wait 5 seconds before retrying
    await Future.delayed(const Duration(seconds: 5));
    
    if (!mounted) return; // Don't retry if widget is disposed
    
    try {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: Retrying MQTT connection...');
      }
      
      await _mqttManager!.initialise();
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: MQTT reconnection failed: $e');
      }
    }
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cities = await _transitService.getTransitCities();
      setState(() {
        _cities = cities;
        _isLoading = false;
        // Optionally select the first city by default
        if (cities.isNotEmpty) {
          _selectedCity = cities.first;
          _updateMapForCity(_selectedCity!);
        }
      });
      // Load live trips after cities are loaded
      await _loadLiveTrips();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLiveTrips() async {
    setState(() {
      _isLoadingTrips = true;
      _tripsError = null;
    });

    try {
      // Hardcoded cityId = 1 for now
      final trips = await _transitService.getMonitoredLiveTrips(_selectedCity!.id, true);
      setState(() {
        _liveTrips = {for (var trip in trips) trip.tripId: trip};
        _isLoadingTrips = false;
      });

      _routes = await _transitService.getMonitoredRoutes(_selectedCity!.id);
      
      // Subscribe to MQTT trip statistics for all live trips
      await _subscribeToTripStats(_selectedCity!.id, trips);
      
      // Load shapes and observations for first 10 trips in background
      // This won't block the UI since we don't await it
      _loadTripDataInBackground(_selectedCity!.id, trips.take(10).toList());
    } catch (e) {
      setState(() {
        _tripsError = e.toString();
        _isLoadingTrips = false;
      });
    }
  }

  /// Subscribe to MQTT trip statistics for the given trips
  Future<void> _subscribeToTripStats(int cityId, List<LiveTrip> trips) async {
    if (_mqttManager == null) {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: Cannot subscribe to trip stats - MQTT manager not available');
      }
      return;
    }

    // Ensure MQTT is connected before subscribing
    if (!_mqttManager!.isConnected) {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: MQTT not connected, attempting to connect...');
      }
      
      try {
        final success = await _mqttManager!.initialise();
        if (!success) {
          if (_transitService.enableDiagnostics) {
            debugPrint('🗺️ Map: Failed to establish MQTT connection for trip stats');
          }
          return;
        }
      } catch (e) {
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: Error connecting MQTT for trip stats: $e');
        }
        return;
      }
    }

    try {
      // Use the existing MQTT manager's service for subscriptions
      final service = _mqttManager!.mqttService;

      final allStatsTopic = 'transit/tripstats/$cityId/+';
      final success = await service.subscribeToTopic(allStatsTopic);
      if (success) {
        _subscribedTopics.add(allStatsTopic);
        
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: Subscribed to trip stats: $allStatsTopic');
        }
      } else {
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: Failed to subscribe to trip stats: $allStatsTopic');
        }
      }

      for (final trip in trips) {
        final topic = 'transit/tripstats/$cityId/${trip.tripId}';
        
        // Avoid duplicate subscriptions
        if (_subscribedTopics.contains(topic)) {
          continue;
        }
        
        // Subscribe to the custom topic
        final success = await service.subscribeToTopic(topic);
        if (success) {
          _subscribedTopics.add(topic);
          
          if (_transitService.enableDiagnostics) {
            debugPrint('🗺️ Map: Subscribed to trip stats: $topic');
          }
        } else {
          if (_transitService.enableDiagnostics) {
            debugPrint('🗺️ Map: Failed to subscribe to trip stats: $topic');
          }
        }
      }
      
      // Set up message handler for trip statistics if not already done
      _setupTripStatsMessageHandler();
      
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: Error subscribing to trip stats: $e');
      }
    }
  }

  /// Set up message handler for trip statistics MQTT messages
  void _setupTripStatsMessageHandler() {
    if (_mqttManager == null) return;
    
    final service = _mqttManager!.mqttService;
    final messageStream = service.messageStream;
    
    if (messageStream != null) {
      messageStream.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final topic = message.topic;
          
          // Only handle trip stats topics
          if (topic.startsWith('transit/tripstats/')) {
            final payload = MqttPublishPayload.bytesToStringAsString(
              (message.payload as MqttPublishMessage).payload.message,
            );
            
            _handleTripStatsMessage(topic, payload);
          }
        }
      });
    }
  }

  /// Handle incoming trip statistics MQTT messages
  void _handleTripStatsMessage(String topic, String payload) async {
    try {
      final parts = topic.split('/');
      if (parts.length >= 4) {
        final cityId = parts[2];
        final tripId = parts[3];
        final key = '$cityId-$tripId';

        // Parse JSON payload
        final data = json.decode(payload) as Map<String, dynamic>;

        if (_loadedObservations.containsKey(key)) {
          TripData? tripData = _loadedObservations[key];
          if (tripData != null) {
            tripData.finished = data['finished'] ?? false;
            if (tripData.finished) {
              _loadedObservations.remove(key);
              _finishedTrips.add(tripId);
            }
            else{
              tripData.averageSpeedKmh = data['averageSpeed']?.toDouble() ?? -1.0;
              // if (data.containsKey('enteredBusinessDistrict') && data.containsKey('exitedBusinessDistrict')) {
              if (data.containsKey('currentDistrict')) {
                // tripData.inBusinessDistrict = data['enteredBusinessDistrict'] && (!data['exitedBusinessDistrict']);
                tripData.inBusinessDistrict = data['currentDistrict'] > 0;
              }
              tripData.observations.add(TripObservation(
                lat: data['latestLat']?.toDouble() ?? 0.0,
                lon: data['latestLong']?.toDouble() ?? 0.0,
                timestamp: data['latestTimestamp'] ?? 0,
                bearing: data['latestBearing']?.toDouble() ?? 0.0,
                occupancyStatus: data['occupancyStatus'] ?? 0,
                averageOccupancyStatus: data['averageOccupancyStatus']?.toDouble() ?? 0.0,
              ));
              
              // Trigger UI update for map markers/observations
              if (mounted) {
                setState(() {
                  // Update the map entry to signal Flutter that something changed
                  _loadedObservations[key] = tripData;
                  _tripStats[key] = data;
                });
              }
            }
          }
        }
        else{
          if (_transitService.enableDiagnostics) {
            debugPrint('🗺️ Map: Received trip stats for unknown trip $tripId');
          }
          final routeId = data['routeId'];
          debugPrint('🗺️ Map: routeId for unknown trip $tripId is $routeId');
          if (_finishedTrips.contains(tripId)) {
            debugPrint('🗺️ Map: Trip $tripId already marked as finished, ignoring stats.');
            return;
          }
          if (routeId != null) {
            if (!_routes.containsKey(routeId)) {
              debugPrint('🗺️ Map: Received stats for route $routeId which is not in monitored routes, ignoring.');
              return;
            }
            int routeIndex = _routes.keys.toList().indexOf(routeId);
            if (routeIndex != -1) {
              TripData newTrip = TripData(
                cityId: int.parse(cityId),
                tripId: tripId,
                directionId: data['directionId'] ?? 0,
                routeShortName: _routes[routeId] ?? '',
                routeDesc: data['routeDesc'] ?? '',
                routeColour: data['routeColour'] ?? 0,
                observations: [],
                headsign: data['headsign'] ?? '',
              );
              debugPrint('🗺️ Map: Created new TripData for trip $tripId on route $routeId at index $routeIndex.');
              setState(() {
                _loadedObservations[key] = newTrip;
              });

              final tripShape = await _transitService.getShapeForTrip(int.parse(cityId), tripId);

              // Store the loaded shape and update UI
              if (mounted) {
                setState(() {
                  debugPrint('🗺️ Map: Loaded shape for new trip $tripId, updating map.');
                  _loadedShapes[tripShape.key()] = tripShape;
                });
              }

            }
          }
        }

        
        
        if (_transitService.enableDiagnostics) {
          debugPrint('🗺️ Map: Received trip stats for $key: $data');
        }
      }
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('🗺️ Map: Error processing trip stats message: $e');
      }
    }
  }

  /// Load shape and observation data for trips in the background
  /// This runs asynchronously without blocking the UI
  Future<void> _loadTripDataInBackground(int cityId, List<LiveTrip> trips) async {
    for (final trip in trips) {
      try {
        // Load shape first, then observations sequentially to reduce simultaneous connections
        final tripShape = await _transitService.getShapeForTrip(cityId, trip.tripId);
        
        // Store the loaded shape and update UI
        if (mounted) {
          setState(() {
            _loadedShapes[tripShape.key()] = tripShape;
          });
        }
        
        // Small delay between requests to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Load observations after shape
        final tripData = await _transitService.getObservationsForTrip(cityId, trip.tripId, trip.directionId, trip.routeShortName, trip.routeDesc, trip.routeColour, trip.headsign);
        tripData.calculateAverageSpeedKmh(tripShape);
        
        // Store trip data keyed by cityId-tripId
        if (mounted) {
          setState(() {
            _loadedObservations[tripData.key()] = tripData;
          });
        }
        
      } catch (e) {
        // Log error but continue loading other trips
        if (_transitService.enableDiagnostics) {
          debugPrint('Error loading data for trip ${trip.tripId}: $e');
        }
      }
    }
  }

  void _updateMapForCity(TransitCity city) {
    // TODO: In the future, you might want to get actual coordinates from the API
    // For now, using approximate coordinates for common cities
    final coordinates = city.latitude != null && city.longitude != null
        ? LatLng(city.latitude!, city.longitude!)
        : _getCityCoordinates(city.name);
    
    setState(() {
      _mapCenter = coordinates;
      _mapZoom = 11.0;
    });
    // Reload live trips when city changes
    // _loadLiveTrips();
  }

  LatLng _getCityCoordinates(String cityName) {
    // This is a simple mapping - you might want to get these from the API later
    final cityCoords = {
      'Toronto': LatLng(43.6532, -79.3832),
      'Ottawa': LatLng(45.4215, -75.6972),
      'Vancouver': LatLng(49.2827, -123.1207),
      'Montreal': LatLng(45.5017, -73.5673),
      'Calgary': LatLng(51.0447, -114.0719),
      'Edmonton': LatLng(53.5461, -113.4938),
      'Winnipeg': LatLng(49.8951, -97.1384),
      'Hamilton': LatLng(43.2557, -79.8711),
      'Quebec City': LatLng(46.8139, -71.2080),
      'Victoria': LatLng(48.4284, -123.3656),
    };

    return cityCoords[cityName] ?? _mapCenter;
  }

  /// Build tooltip message for trip markers including MQTT statistics if available
  String _buildTripTooltipMessage(TripData tripData, int tripIndex) {
    String baseMessage = '${tripData.routeShortName} - ${tripData.headsign} - '
        '${tripData.averageSpeedKmh >= 0 ? tripData.averageSpeedKmh.toStringAsFixed(1) : 'N/A'} km/h';
    
    // Check if we have MQTT trip statistics
    // final tripStatsKey = tripData.key(); // Using the same key format
    // final tripStats = _tripStats[tripStatsKey];
    // final tripData = _loadedObservations[tripStatsKey];
    
    // if (tripStats != null) {
      // final mqttSpeed = tripStats['averageSpeed'];
      // tripData.finished = tripStats['finished'];
      // final bool enteredBusinessDistrict = tripStats['enteredBusinessDistrict'];
      // final bool exitedBusinessDistrict = tripStats['exitedBusinessDistrict'];
      // final passengers = tripStats['passenger_count'];
      // final delay = tripStats['delay_minutes'];
      
      // baseMessage += '\nSpeed: ${tripData.averageSpeedKmh.toStringAsFixed(1)} km/h';
      if (tripData.inBusinessDistrict) {
        baseMessage += '\nWithin Business District';
      }
      if (tripData.finished) {
        baseMessage += '\nTRIP FINISHED';
      }
      baseMessage += '\nOccupancy: ${tripData.occupancyStatus()}';
      baseMessage += '\n ${tripData.tripId}';
      // if (passengers != null) {
      //   baseMessage += '\nPassengers: $passengers';
      // }
      // if (delay != null) {
      //   baseMessage += '\nDelay: ${delay.toStringAsFixed(1)} min';
      // }
      
      return baseMessage;
    // }
    
    // return baseMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transit Map'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          ServerSelector(),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildMapView(),
          Positioned(
            top: _selectorTop,
            left: _selectorLeft,
            child: _buildDraggableResizableSelector(),
          ),
          Positioned(
            top: _selectorTop + _selectorHeight + 8,
            left: _selectorLeft,
            child: _buildShapeDistancesCheckbox(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
            child: const Text(
              'Navigation',
              style: TextStyle(fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Venues'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/venues');
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Transit'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/transit');
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Map'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Transit Analysis'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/transit-analysis');
            },
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('View Single Trip'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/view-single-trip');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Occupancy Transitions'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/occupancy-transitions');
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Vehicles'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/vehicles');
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Route Configurations'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushReplacementNamed(context, '/route-configs');
            },
          ),
          const Divider(),
          // MQTT Connection Status
          if (_mqttManager != null)
            StreamBuilder<VenuesMqttConnectionState>(
              stream: _mqttManager!.connectionStateStream,
              initialData: VenuesMqttConnectionState.disconnected,
              builder: (context, snapshot) {
                final state = snapshot.data ?? VenuesMqttConnectionState.disconnected;
                return ListTile(
                  leading: Icon(
                    _getMqttStatusIcon(state),
                    color: _getMqttStatusColor(state),
                  ),
                  title: Text('MQTT: ${_getMqttStatusText(state)}'),
                  subtitle: state == VenuesMqttConnectionState.connected || 
                           state == VenuesMqttConnectionState.subscribed
                      ? Text('Subscribed to ${_subscribedTopics.length} topics')
                      : const Text('Real-time updates unavailable'),
                  onTap: state == VenuesMqttConnectionState.disconnected ||
                         state == VenuesMqttConnectionState.connectionError
                      ? () async {
                          // Retry connection
                          await _initialiseMqtt();
                        }
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  // Helper methods for MQTT status display
  IconData _getMqttStatusIcon(VenuesMqttConnectionState state) {
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

  Color _getMqttStatusColor(VenuesMqttConnectionState state) {
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

  String _getMqttStatusText(VenuesMqttConnectionState state) {
    switch (state) {
      case VenuesMqttConnectionState.connected:
        return 'Connected';
      case VenuesMqttConnectionState.subscribed:
        return 'Subscribed';
      case VenuesMqttConnectionState.connecting:
        return 'Connecting...';
      case VenuesMqttConnectionState.connectionError:
        return 'Error';
      case VenuesMqttConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  Widget _buildDraggableResizableSelector() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _selectorLeft += details.delta.dx;
          _selectorTop += details.delta.dy;
          // Keep within bounds
          _selectorLeft = _selectorLeft.clamp(0, MediaQuery.of(context).size.width - _selectorWidth);
          _selectorTop = _selectorTop.clamp(0, MediaQuery.of(context).size.height - _selectorHeight);
        });
      },
      child: Stack(
        children: [
          SizedBox(
            width: _selectorWidth,
            height: _selectorHeight,
            child: _buildCitySelector(),
          ),
          // Resize handle (bottom-right corner)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _selectorWidth += details.delta.dx;
                  _selectorHeight += details.delta.dy;
                  // Minimum size constraints
                  _selectorWidth = _selectorWidth.clamp(300, MediaQuery.of(context).size.width - _selectorLeft);
                  _selectorHeight = _selectorHeight.clamp(50, MediaQuery.of(context).size.height - _selectorTop);
                });
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Icon(
                  Icons.zoom_out_map,
                  size: 12,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onShowShapeDistancesChanged(bool? value) {
    setState(() {
      _showShapeDistances = value ?? false;
    });
    // Add your logic here for what happens when the checkbox changes
    if (_showShapeDistances) {
      debugPrint('Shape distances enabled');
      // TODO: Implement shape distance visualization
    } else {
      debugPrint('Shape distances disabled');
    }
  }

  Widget _buildShapeDistancesCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _showShapeDistances,
            onChanged: _onShowShapeDistancesChanged,
          ),
          const SizedBox(width: 8),
          const Text(
            'Show Shape Distances',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error loading cities: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCities,
            ),
          ],
        ),
      );
    }

    if (_cities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text('No cities available'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_city),
          const SizedBox(width: 12),
          const Text(
            'Select City:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<TransitCity>(
              value: _selectedCity,
              isExpanded: true,
              items: _cities.map((city) {
                // Check if city has midpoint data
                final hasMidPoint = city.midPointLatitude != null && 
                                  city.midPointLongitude != null && 
                                  city.midPointRadius != null &&
                                  city.midPointLatitude! != 0 && 
                                  city.midPointLongitude! != 0 && 
                                  city.midPointRadius! > 0;
                
                return DropdownMenuItem<TransitCity>(
                  value: city,
                  child: Row(
                    children: [
                      Flexible(child: Text(city.name)),
                      if (hasMidPoint) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.radio_button_checked,
                          size: 12,
                          color: Colors.red,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (TransitCity? newCity) {
                if (newCity != null) {
                  setState(() {
                    _selectedCity = newCity;
                    _updateMapForCity(newCity);
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          // Live trips indicator
          if (_isLoadingTrips)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_tripsError != null)
            Tooltip(
              message: _tripsError!,
              child: const Icon(Icons.error, color: Colors.red, size: 20),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '${_liveTrips.length} live trips',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading map',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCities,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.venues',
          maxZoom: 19,
        ),
        // Draw city midpoint circle if coordinates and radius are available
        if (_selectedCity != null) ...[
          // Debug: Print city district and area information
          Builder(
            builder: (context) {
              if (_transitService.enableDiagnostics) {
                debugPrint('🗺️ Map: Selected city: ${_selectedCity!.name}');
                debugPrint('🗺️ Map: Districts: ${_selectedCity!.districts.length}');
                for (final district in _selectedCity!.districts) {
                  debugPrint('🗺️ Map: District "${district.name}" has ${district.areas.length} areas');
                }
              }
              return const SizedBox.shrink();
            },
          ),
          // Draw district area circles for the selected city
          if (_selectedCity != null && _selectedCity!.districts.isNotEmpty)
            CircleLayer(
              circles: _selectedCity!.districts
                  .expand((district) => district.areas)
                  .map((area) => CircleMarker(
                        point: LatLng(area.latitude, area.longitude),
                        radius: area.radius,
                        useRadiusInMeter: true,
                        color: Colors.transparent,
                        borderColor: Colors.blue.withValues(alpha: 0.6),
                        borderStrokeWidth: 2.0,
                      ))
                  .toList(),
            ),
        ],
        PolylineLayer(
          polylines: _loadedShapes.values.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final tripShape = entry.value;
            
            // Generate different colors for each polyline
            final colors = [
              Colors.lightBlue,
              Colors.blue,
              Colors.green,
              Colors.indigo,
              Colors.greenAccent,
              Colors.teal,
              Colors.yellow,
              Colors.orange,
            ];
            final color = colors[index % colors.length];
            
            return Polyline(
              points: tripShape.points.map((point) => LatLng(point.lat, point.lon)).toList(),
              strokeWidth: 1.0,
              color: color.withValues(alpha: 0.7),
            );
          }).toList(),
        ),
        // Draw observation points as circular markers with tooltips
        MarkerLayer(
          markers: _loadedObservations.entries.toList().asMap().entries.expand((tripEntry) {
            final tripIndex = tripEntry.key;
            final tripData = tripEntry.value.value;
            final observations = tripData.observations;
            
            // Color palette for different trips
            final colors = [
              Colors.red,
              Colors.purple,
              Colors.orange,
              Colors.pink,
              Colors.deepOrange,
              Colors.amber,
              Colors.lime,
              Colors.cyan,
            ];
            final color = colors[tripIndex % colors.length];
            
            // Map each observation with increasing radius, excluding the last one (will be an arrow)
            // Only show the most recent 10 observations (excluding the very last)
            final recentObservations = observations.length > 10 
                ? observations.sublist(observations.length - 11, observations.length - 1)  // Get 10 recent, exclude last
                : observations.sublist(0, max(0, observations.length - 1));  // Get all except last if less than 10
            
            return recentObservations.asMap().entries.map((obsEntry) {
              final obsIndex = obsEntry.key;
              final obs = obsEntry.value;
              
              // Calculate radius: starts at 2, increases to 5
              final maxRadius = 5.0;
              final minRadius = 1.0;
              final progress = recentObservations.length > 1 
                  ? obsIndex / (recentObservations.length - 1)
                  : 0.0;
              final radius = minRadius + (maxRadius - minRadius) * progress;
              
              // Format timestamp for tooltip
              final timestamp = DateTime.fromMillisecondsSinceEpoch(obs.timestamp * 1000);
              final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
              
              return Marker(
                point: LatLng(obs.lat, obs.lon),
                width: radius * 2,
                height: radius * 2,
                child: Tooltip(
                  message: '${tripData.routeShortName} (${tripData.routeDesc})\n'
                      'Time: $timeStr of ${observations.length} observations\n'
                      'Occupancy status: ${obs.occupancyStatus}',
                  preferBelow: false,
                  child: Container(
                    width: radius * 2,
                    height: radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      color: Colors.transparent,
                    ),
                  ),
                ),
              );
            });
          }).toList(),
        ),
        // Draw arrows for the final observation in each trip
        MarkerLayer(
          markers: _loadedObservations.entries.toList().asMap().entries.where((entry) => entry.value.value.observations.isNotEmpty).map((tripEntry) {
            final tripIndex = tripEntry.key;
            final tripData = tripEntry.value.value;
            final observations = tripData.observations;
            final lastObs = observations.last;
            // debugPrint('---Trip ${tripData.tripId} last observation at (${lastObs.lat}, ${lastObs.lon}) with bearing ${lastObs.bearing}');
            
            // Color palette matching the circles
            final colors = [
              Colors.red,
              Colors.purple,
              Colors.orange,
              Colors.pink,
              Colors.deepOrange,
              Colors.amber,
              Colors.lime,
              Colors.cyan,
            ];
            Color color = colors[tripIndex % colors.length];
            if (tripData.finished) {
              color = Colors.black; // Grey out finished trips
            }

            final int occupancyStatus = tripData.occupancyStatus();
            
            return Marker(
              point: LatLng(lastObs.lat, lastObs.lon),
              width: 30,
              height: 30,
              child: Tooltip(
                message: _buildTripTooltipMessage(tripData, tripIndex),
                preferBelow: false,
                child: Transform.rotate(
                  angle: lastObs.bearing * 3.14159 / 180, // Convert degrees to radians
                  child: Icon(
                    occupancyStatus < 1 ? Icons.navigation_outlined : Icons.navigation,
                    color: color.withValues(alpha: 0.9),
                    // size: 24,
                    size: 6*(tripData.occupancyStatus() + 3),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Draw distance markers at every 100th point in each shape
        if (_showShapeDistances)
          MarkerLayer(
            markers: _loadedShapes.values.toList().asMap().entries.expand((shapeEntry) {
              final shapeIndex = shapeEntry.key;
              final tripShape = shapeEntry.value;
              
              // Color palette matching the polylines
              final colors = [
                Colors.lightBlue,
                Colors.blue,
                Colors.green,
                Colors.indigo,
                Colors.greenAccent,
                Colors.teal,
                Colors.yellow,
                Colors.orange,
              ];
              final color = colors[shapeIndex % colors.length];
              
              // Get every 100th point
              return tripShape.points.asMap().entries
                  .where((entry) => entry.key % 100 == 0)
                  .map((pointEntry) {
                final point = pointEntry.value;
                final distanceKm = (point.distanceTravelled / 1000).toStringAsFixed(2);
                
                return Marker(
                  point: LatLng(point.lat, point.lon),
                  width: 20,
                  height: 20,
                  child: Tooltip(
                    message: 'Distance: $distanceKm km\nSequence: ${point.sequence}',
                    preferBelow: false,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
                      ),
                      child: Icon(
                        Icons.star,
                        size: 16,
                        color: color.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                );
              });
            }).toList(),
          ),
        // Add markers or other layers here in the future
      ],
    );
  }
}
