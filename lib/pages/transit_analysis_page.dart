import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../services/transit_service.dart';
import '../services/transit_mqtt_manager.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';
import '../main.dart';

class TransitAnalysisPage extends StatefulWidget {
  const TransitAnalysisPage({super.key});

  @override
  State<TransitAnalysisPage> createState() => _TransitAnalysisPageState();
}

class _TransitAnalysisPageState extends State<TransitAnalysisPage> with WidgetsBindingObserver {
  late TransitService _transitService;
  TransitMqttManager? _mqttManager;
  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  District? _selectedDistrict;
  bool _isLoading = true;
  String? _error;

  // Track subscribed MQTT topics to avoid duplicate subscriptions
  final Set<String> _subscribedTopics = {};

  // Store analytics data collected from MQTT
  final Map<String, Map<String, dynamic>> _routeAnalytics = {};
  List<dynamic> _netAnalyticData = [];
  final List<Map<String, dynamic>> _realtimeEvents = [];
  
  // Store the latest combined data from MQTT netDelivered
  List<Map<String, dynamic>> _combinedMqttData = [];

  // Store initial API data from getRouteDistrictStats
  final Map<String, List<RouteDistrictStats>> _initialRouteStats = {};
  List<RouteDistrictStats> _combinedRouteStats = [];
  List<DistrictHourlySpeed> _routeSpeeds = [];
  Map<String, dynamic> _routeSpeedsMap = {};
  bool _isLoadingInitialData = false;

  // Display mode: false = Occupancy Status, true = Passenger Estimates
  bool _showPassengerEstimates = false;

  // Map of route IDs to route short names
  Map<String, String> _routes = {};
  bool _isLoadingRoutes = false;
  String? _routesError;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _transitService = TransitService(
        server: ApiConfig.of(context).server,
        enableDiagnostics: true,
      );
      
      // Initialize MQTT manager
      final mqttConfig = MqttConfigProvider.of(context);
      _mqttManager = TransitMqttManager(
        config: mqttConfig,
        enableDiagnostics: mqttConfig.enableDiagnostics,
      );
      _initializeMqtt();
      
      _isInitialized = true;
      _loadCities();
      
      // Add lifecycle observer
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          debugPrint('📊 Analysis: App resumed, checking MQTT connection...');
        }
        _retryMqttConnection();
      }
    }
  }

  /// Initialize MQTT connection
  Future<void> _initializeMqtt() async {
    if (_mqttManager == null) return;
    
    try {
      // Connect to MQTT broker
      final success = await _mqttManager!.initialise();
      if (success) {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: MQTT initialized and connected successfully');
        }
        
        // Set up connection state monitoring
        _mqttManager!.connectionStateStream.listen((state) {
          if (_transitService.enableDiagnostics) {
            debugPrint('📊 Analysis: MQTT connection state changed to $state');
          }
          
          // If we get disconnected, try to reconnect
          if (state == VenuesMqttConnectionState.disconnected || 
              state == VenuesMqttConnectionState.connectionError) {
            _retryMqttConnection();
          }
        });
        
        // Set up message handler for analytics
        _setupAnalyticsMessageHandler();
        
      } else {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: MQTT initialization failed, will retry when needed');
        }
      }
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: MQTT initialization error: $e');
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
        debugPrint('📊 Analysis: Retrying MQTT connection...');
      }
      
      await _mqttManager!.initialise();
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: MQTT reconnection failed: $e');
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
        if (cities.isNotEmpty) {
          _selectedCity = cities.first;
          _selectedDistrict = cities.first.districts.isNotEmpty
              ? cities.first.districts.first
              : null;
        }
      });
      // Load routes and start analytics collection after cities are loaded
      await _loadRoutes();
      await _loadInitialAnalyticsData();
      await _startAnalyticsCollection();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Load routes for the selected city
  Future<void> _loadRoutes() async {
    if (_selectedCity == null) {
      setState(() {
        _isLoadingRoutes = false;
        _routesError = 'No city selected';
      });
      return;
    }

    setState(() {
      _isLoadingRoutes = true;
      _routesError = null;
    });

    try {
      final routes = await _transitService.getMonitoredRoutes(_selectedCity!.id);
      setState(() {
        _routes = routes;
        _isLoadingRoutes = false;
        _routesError = routes.isEmpty ? 'No monitored routes found for ${_selectedCity!.name}' : null;
      });
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Loaded ${routes.length} routes for ${_selectedCity!.name}');
      }
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Error loading routes: $e');
      }
      setState(() {
        _isLoadingRoutes = false;
        _routesError = 'Failed to load routes: $e';
      });
    }
  }

  /// Load initial analytics data from API
  Future<void> _loadInitialAnalyticsData() async {
    if (_selectedCity == null) return;

    setState(() {
      _isLoadingInitialData = true;
    });

    try {
      // Add a small delay to ensure server is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Load combined stats for all routes (routeId = null)
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Loading combined route district stats for city ${_selectedCity!.id}');
      }
      
      try {
        final combinedStats = await _transitService.getRouteDistrictStats(
          _selectedCity!.id,
          districtId: _selectedDistrict?.districtId,
        );
        _combinedRouteStats = combinedStats;
      } catch (e) {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: Error loading combined stats: $e');
        }
        // Continue with individual routes even if combined fails
      }

      try {
        final routeSpeeds = await _transitService.getDistrictHourlySpeeds(_selectedCity!.id);

        // turn it into a mapping from routeId to list of speeds for that route
        _routeSpeeds = routeSpeeds;
        String thisRouteId = '';
        List<SpeedPair> thisRouteSpeeds = [];
        for (final speed in routeSpeeds) {
          if (speed.routeId != thisRouteId) {
            if (thisRouteSpeeds.isNotEmpty) {
              _routeSpeedsMap[thisRouteId] = thisRouteSpeeds;
            }
            thisRouteId = speed.routeId;
            thisRouteSpeeds = [];
          }
          thisRouteSpeeds.add(
            SpeedPair(inwardSpeed: speed.inwardSpeed, 
              outwardSpeed: speed.outwardSpeed, 
              theHour: speed.theHour));
        }
        if (thisRouteSpeeds.isNotEmpty) {
          _routeSpeedsMap[thisRouteId] = thisRouteSpeeds;
        }

      } catch (e) {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: Error loading district hourly speeds: $e');
        }
      }
      
      // Load stats for each individual route with retry logic
      for (final routeId in _routes.keys) {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: Loading route district stats for route $routeId');
        }
        
        try {
          final routeStats = await _loadRouteStatsWithRetry(_selectedCity!.id, routeId, districtId: _selectedDistrict?.districtId);
          _initialRouteStats[routeId] = routeStats;
        } catch (e) {
          if (_transitService.enableDiagnostics) {
            debugPrint('📊 Analysis: Error loading stats for route $routeId: $e');
          }
          // Continue with other routes
        }
      }
      
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Loaded initial data - Combined: ${_combinedRouteStats.length}, Routes: ${_initialRouteStats.length}');
      }
      
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Error loading initial analytics data: $e');
      }
    } finally {
      // Defer the final setState to after the current frame.  When chart data
      // changes, Syncfusion replaces internal CustomLayoutBuilderElement children
      // during the rebuild triggered by this setState.  Those old elements call
      // markNeedsLayout inside their unmount(), which Flutter's debug assertion
      // rejects if it happens mid-frame.  addPostFrameCallback ensures the
      // previous frame has fully committed before the rebuild runs.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoadingInitialData = false;
          });
        }
      });
    }
  }

  /// Load route stats with retry logic
  Future<List<RouteDistrictStats>> _loadRouteStatsWithRetry(int cityId, String routeId, {int maxRetries = 3, int? districtId}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final stats = await _transitService.getRouteDistrictStats(cityId, routeId: routeId, districtId: districtId);
        return stats;
      } catch (e) {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: Attempt $attempt failed for route $routeId: $e');
        }
        
        if (attempt == maxRetries) {
          rethrow; // Last attempt, give up
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    
    return []; // Should never reach here, but just in case
  }

  /// Start collecting analytics data from MQTT
  Future<void> _startAnalyticsCollection() async {
    if (_mqttManager == null || _selectedCity == null) return;

    // Ensure MQTT is connected before subscribing
    if (!_mqttManager!.isConnected) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: MQTT not connected, attempting to connect...');
      }
      
      try {
        final success = await _mqttManager!.initialise();
        if (!success) {
          if (_transitService.enableDiagnostics) {
            debugPrint('📊 Analysis: Failed to establish MQTT connection for analytics');
          }
          return;
        }
      } catch (e) {
        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: Error connecting MQTT for analytics: $e');
        }
        return;
      }
    }

    try {
      // Use the existing MQTT manager's service for subscriptions
      final service = _mqttManager!.mqttService;

      // Subscribe to route statistics for each monitored route in the selected city
      for (final routeId in _routes.keys) {
        // Subscribe to all districts for this route using wildcard
        final routeStatsTopic = 'transit/routestats/${_selectedCity!.id}/$routeId/+';
        final success = await service.subscribeToTopic(routeStatsTopic);
        if (success) {
          _subscribedTopics.add(routeStatsTopic);
          
          if (_transitService.enableDiagnostics) {
            debugPrint('📊 Analysis: Subscribed to route stats: $routeStatsTopic');
          }
        } else {
          if (_transitService.enableDiagnostics) {
            debugPrint('📊 Analysis: Failed to subscribe to route stats: $routeStatsTopic');
          }
        }
      }
      
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Error subscribing to analytics data: $e');
      }
    }
  }

  /// Set up message handler for analytics MQTT messages
  void _setupAnalyticsMessageHandler() {
    if (_mqttManager == null) return;
    
    final service = _mqttManager!.mqttService;
    final messageStream = service.messageStream;
    
    if (messageStream != null) {
      messageStream.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          final topic = message.topic;
          
          // Only handle route stats topics for analytics
          if (topic.startsWith('transit/routestats/')) {
            final payload = MqttPublishPayload.bytesToStringAsString(
              (message.payload as MqttPublishMessage).payload.message,
            );
            
            _processAnalyticsMessage(topic, payload);
          }
        }
      });
    }
  }

  /// Process incoming analytics messages and update statistics
  void _processAnalyticsMessage(String topic, String payload) {
    try {
      final parts = topic.split('/');
      if (parts.length >= 5) {
        final cityId = parts[2];
        final routeId = parts[3];
        final district = parts[4];
        final key = '$cityId-$routeId-$district';

        // Parse JSON payload
        final data = json.decode(payload) as Map<String, dynamic>;

        // Store/update route analytics data
        _routeAnalytics[key] = {
          ...(_routeAnalytics[key] ?? {}),
          ...data,
          'lastUpdate': DateTime.now().millisecondsSinceEpoch,
          'routeId': routeId,
          'cityId': cityId,
          'district': district,
        };

        // Extract netDelivered for combined chart (only update if this is for the selected district)
        final selectedDistrictId = _selectedDistrict?.districtId?.toString();
        if (district == selectedDistrictId && data.containsKey('netDelivered')) {
          final netDelivered = data['netDelivered'] as List<dynamic>?;
          if (netDelivered != null) {
            _combinedMqttData = netDelivered.cast<Map<String, dynamic>>();
            if (_transitService.enableDiagnostics) {
              debugPrint('📊 Analysis: Updated combined MQTT data with ${_combinedMqttData.length} entries');
            }
          }
        }

        // Add to realtime events (keep last 100)
        _realtimeEvents.add({
          'timestamp': DateTime.now(),
          'routeId': routeId,
          'district': district,
          'event': data,
        });

        // Trigger UI update to redraw the charts
        if (mounted) {
          setState(() {
            // Charts will be rebuilt automatically since they read from _routeAnalytics
          });
        }

        if (_transitService.enableDiagnostics) {
          debugPrint('📊 Analysis: Processed analytics for $key');
        }
      }
    } catch (e) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: Error processing analytics message: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transit Analysis'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          ServerSelector(),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildAnalyticsView(),
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
            onTap: () {
              Navigator.pushReplacementNamed(context, '/map');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Transit Analysis'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
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
                          await _initializeMqtt();
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

  Widget _buildAnalyticsView() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading transit analytics...'),
          ],
        ),
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
              'Error loading analytics',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City selector
          _buildCitySelector(),
          const SizedBox(height: 12),

          // District selector and display mode selector side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDistrictSelector()),
              const SizedBox(width: 8),
              Expanded(child: _buildDisplayModeSelector()),
            ],
          ),
          const SizedBox(height: 24),

          // Combined routes delivery chart (at the top)
          if (_combinedRouteStats.isNotEmpty || _isLoadingInitialData)
            _buildCombinedRouteChart(),

          // Route delivery charts
          _buildRouteCharts(),
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    if (_cities.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No cities available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.location_city),
            const SizedBox(width: 12),
            const Text(
              'Analyzing City:',
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
                  return DropdownMenuItem<TransitCity>(
                    value: city,
                    child: Text(city.name),
                  );
                }).toList(),
                onChanged: (TransitCity? newCity) {
                  if (newCity != null && newCity != _selectedCity) {
                    setState(() {
                      _selectedCity = newCity;
                      _selectedDistrict = newCity.districts.isNotEmpty
                          ? newCity.districts.first
                          : null;
                      // Clear MQTT/event data immediately (doesn't affect charts)
                      _routeAnalytics.clear();
                      _realtimeEvents.clear();
                      _combinedMqttData.clear();
                      // Signal loading without removing chart data from the tree —
                      // clearing _routes/_combinedRouteStats here would cause
                      // SfCartesianChart to unmount mid-frame and trigger a
                      // markNeedsLayout assert inside Syncfusion's element.unmount.
                      _isLoadingRoutes = true;
                      _routesError = null;
                      _isLoadingInitialData = true;
                    });
                    _loadRoutes();
                    _loadInitialAnalyticsData();
                    _startAnalyticsCollection();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictSelector() {
    final districts = _selectedCity?.districts ?? [];

    if (districts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text('No districts available for this city'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined),
                const SizedBox(width: 12),
                const Text(
                  'District:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            DropdownButton<District>(
                value: _selectedDistrict,
                items: districts.map((district) {
                  return DropdownMenuItem<District>(
                    value: district,
                    child: Text(district.name),
                  );
                }).toList(),
                onChanged: (District? newDistrict) {
                  if (newDistrict != null && newDistrict != _selectedDistrict) {
                    // Defer to the next frame so the current frame (including any
                    // in-flight Syncfusion chart element lifecycle) finishes before
                    // we swap the chart data.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedDistrict = newDistrict;
                          // Clear MQTT/event data immediately (doesn't affect charts)
                          _routeAnalytics.clear();
                          _realtimeEvents.clear();
                          _combinedMqttData.clear();
                          _isLoadingInitialData = true;
                        });
                        _loadInitialAnalyticsData();
                      }
                    });
                  }
                },
            ),
          ],
        ),
      ),
    );
  }

  /// Build combined route delivery chart for all routes
  Widget _buildCombinedRouteChart() {
    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Combined Routes - ${_selectedDistrict?.name ?? 'District'} Deliveries (All Routes)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              // Keep SfCartesianChart in the tree while refreshing data to avoid
              // Syncfusion's markNeedsLayout-during-unmount assert.
              child: _isLoadingInitialData && _combinedRouteStats.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading combined route data...'),
                        ],
                      ),
                    )
                  : _combinedRouteStats.isEmpty
                      ? Center(
                          child: Text(
                            'No combined delivery data available yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            _buildCombinedBarChart(_combinedRouteStats),
                            if (_isLoadingInitialData)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.white54,
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build route delivery charts for the selected district
  Widget _buildRouteCharts() {
    // Only show the spinner when there are no existing charts to display —
    // if we have prior route data, keep the SfCartesianChart widgets in the
    // tree while the refresh runs to avoid Syncfusion's markNeedsLayout assert.
    if (_isLoadingRoutes && _routes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading routes...'),
            ],
          ),
        ),
      );
    }

    if (_routesError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _routesError!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadRoutes,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_routes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No routes available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final routeCharts = <Widget>[];
    
    // Determine chart width based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 32.0; // Account for page padding
    final cardMargin = 16.0; // Card margin
    
    double chartWidth;
    if (screenWidth < 800) {
      // Narrow: 1 chart per row
      chartWidth = screenWidth - padding;
    } else if (screenWidth < 1200) {
      // Normal: 2 charts per row
      chartWidth = (screenWidth - padding - cardMargin) / 2;
    } else {
      // Wide: 3 charts per row
      chartWidth = (screenWidth - padding - (cardMargin * 2)) / 3;
    }
    
    for (final routeId in _routes.keys) {
      final routeShortName = _routes[routeId] ?? routeId;
      final deliveryData = _getDeliveryDataForRoute(routeId);
      final apiData = _getApiDataForRoute(routeId);
      final List<SpeedPair> speedData = _getSpeedsForRoute(routeId);
      
      routeCharts.add(
        SizedBox(
          width: chartWidth,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16.0, right: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Route $routeShortName ($routeId) - ${_selectedDistrict?.name ?? 'District'} Deliveries',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: (deliveryData.isEmpty && apiData.isEmpty)
                        ? Center(
                            child: Text(
                              'No delivery data available yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          )
                        : _buildRouteBarChart(deliveryData, apiData, speedData),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return Wrap(
      alignment: WrapAlignment.start,
      children: routeCharts,
    );
  }

  /// Get delivery data for a specific route in the selected district
  List<Map<String, dynamic>> _getDeliveryDataForRoute(String routeId) {
    final districtId = _selectedDistrict?.districtId ?? 1;
    final key = '${_selectedCity?.id}-$routeId-$districtId';
    final routeData = _routeAnalytics[key];
    
    if (routeData == null || !routeData.containsKey('delivered')) {
      return [];
    }
    
    final delivered = routeData['delivered'] as List<dynamic>?;
    return delivered?.cast<Map<String, dynamic>>() ?? [];
  }

  List<SpeedPair> _getSpeedsForRoute(String routeId) {
    final speeds = _routeSpeedsMap[routeId] as List<SpeedPair>?;
    if (speeds == null) {
      if (_transitService.enableDiagnostics) {
        debugPrint('📊 Analysis: No speed data found for route $routeId');
      }
      return [];
    }
    return speeds;
  } 
  /// Get API data for a specific route in the selected district
  List<RouteDistrictStats> _getApiDataForRoute(String routeId) {
    // API already filtered by district; return all cached rows for this route.
    return _initialRouteStats[routeId] ?? [];
  }

  Widget _buildDisplayModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.show_chart),
                const SizedBox(width: 12),
                const Text(
                  'Display:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Occupancy Status'),
                  icon: Icon(Icons.people_outline),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Passenger Estimates'),
                  icon: Icon(Icons.people),
                ),
              ],
              selected: {_showPassengerEstimates},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _showPassengerEstimates = selection.first;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build bar chart for combined routes using MQTT data when available, otherwise API data
  Widget _buildCombinedBarChart(List<RouteDistrictStats> stats) {
    // Use MQTT data if available, otherwise fall back to API data
    if (_combinedMqttData.isNotEmpty) {
      return _buildCombinedChartFromMqtt(_combinedMqttData);
    }
    
    if (stats.isEmpty) return const SizedBox.shrink();

    // The API already filtered by district, so aggregate all returned rows by hour.
    final Map<int, int> deliveryByHour = {};
    for (final stat in stats) {
      final value = _showPassengerEstimates
          ? (stat.passengersDelivered ?? 0)
          : stat.delivered;
      deliveryByHour[stat.hour] = (deliveryByHour[stat.hour] ?? 0) + value;
    }

    if (deliveryByHour.isEmpty) return const SizedBox.shrink();

    final sortedHours = deliveryByHour.keys.toList()..sort();
    final chartData = sortedHours
        .map((hour) => {'formattedHour': '$hour:00', 'delivered': deliveryByHour[hour]!})
        .toList();

    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(
        labelRotation: -45,
        labelStyle: TextStyle(fontSize: 10),
      ),
      primaryYAxis: NumericAxis(
        plotBands: <PlotBand>[
          PlotBand(
            start: 0,
            end: 0,
            borderWidth: 1,
            borderColor: Colors.black,
          ),
        ],
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<Map<String, dynamic>, String>>[
        ColumnSeries<Map<String, dynamic>, String>(
          dataSource: chartData,
          xValueMapper: (datum, _) => datum['formattedHour'] as String,
          yValueMapper: (datum, _) => datum['delivered'] as num,
          pointColorMapper: (datum, _) =>
              (datum['delivered'] as num) < 0 ? Colors.red.shade400 : Colors.purple.shade400,
        ),
      ],
    );
  }

  /// Build bar chart for individual route using both MQTT and API data
  Widget _buildRouteBarChart(List<Map<String, dynamic>> mqttData, List<RouteDistrictStats> apiData, List<SpeedPair> speedData) {
    if (mqttData.isEmpty && apiData.isEmpty) return const SizedBox.shrink();

    // Use MQTT data if available, otherwise use API data
    if (mqttData.isNotEmpty) {
      return _buildBarChart(mqttData);
    }

    if (apiData.isEmpty) return const SizedBox.shrink();

    // Check whether passenger estimate data is actually available
    final hasPassengerData = apiData.any((s) => (s.passengersDelivered ?? 0) != 0);
    final usePassenger = _showPassengerEstimates && hasPassengerData;

    final sortedData = apiData..sort((a, b) => a.hour.compareTo(b.hour));
    final chartData = sortedData
        .map((s) => {
              'formattedHour': '${s.hour}:00',
              'delivered': usePassenger
                  ? (s.passengersDelivered ?? 0)
                  : s.delivered,
            })
        .toList();

    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(
        labelRotation: -45,
        labelStyle: TextStyle(fontSize: 9),
      ),
      primaryYAxis: NumericAxis(
        plotBands: <PlotBand>[
          PlotBand(
            start: 0,
            end: 0,
            borderWidth: 1,
            borderColor: Colors.black,
          ),
        ],
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<Map<String, dynamic>, String>>[
        ColumnSeries<Map<String, dynamic>, String>(
          dataSource: chartData,
          xValueMapper: (datum, _) => datum['formattedHour'] as String,
          yValueMapper: (datum, _) => datum['delivered'] as num,
          pointColorMapper: (datum, _) =>
              (datum['delivered'] as num) < 0 ? Colors.red.shade400 : Colors.green.shade400,
        ),
      ],
    );
  }

  /// Build combined chart from MQTT data with both bars and cumulative line
  Widget _buildCombinedChartFromMqtt(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final chartData = data
        .map((item) => {
              'formattedHour': '${item['hour']}:00',
              'delivered': (_showPassengerEstimates
                  ? (item['passengersDelivered'] as num?)?.toInt()
                  : (item['delivered'] as num?)?.toInt()) ?? 0,
              'cumulativeDelivered': (_showPassengerEstimates
                  ? (item['cumulativePassengersDelivered'] as num?)?.toInt()
                  : (item['cumulativeDelivered'] as num?)?.toInt()) ?? 0,
            })
        .toList();

    return SizedBox(
      height: 250,
      child: SfCartesianChart(
        primaryXAxis: const CategoryAxis(
          labelRotation: -45,
          labelStyle: TextStyle(fontSize: 10),
        ),
        primaryYAxis: NumericAxis(
          plotBands: <PlotBand>[
            PlotBand(
              start: 0,
              end: 0,
              borderWidth: 1,
              borderColor: Colors.black,
            ),
          ],
        ),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<Map<String, dynamic>, String>>[
          ColumnSeries<Map<String, dynamic>, String>(
            name: 'Delivered',
            dataSource: chartData,
            xValueMapper: (datum, _) => datum['formattedHour'] as String,
            yValueMapper: (datum, _) => datum['delivered'] as num,
            pointColorMapper: (datum, _) =>
                (datum['delivered'] as num) < 0 ? Colors.red.shade400 : Colors.purple.shade400,
          ),
          LineSeries<Map<String, dynamic>, String>(
            name: 'Cumulative',
            dataSource: chartData,
            xValueMapper: (datum, _) => datum['formattedHour'] as String,
            yValueMapper: (datum, _) => datum['cumulativeDelivered'] as num,
            color: Colors.deepPurple,
            width: 3,
            markerSettings: const MarkerSettings(
              isVisible: true,
              color: Colors.deepPurple,
              shape: DataMarkerType.circle,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a combination chart with bars and cumulative line (existing MQTT data)
  Widget _buildBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final chartData = data
        .map((item) => {
              'formattedHour': '${item['hour']}:00',
              'delivered': (_showPassengerEstimates
                  ? (item['passengersDelivered'] as num?)?.toInt()
                  : (item['delivered'] as num?)?.toInt()) ?? 0,
              'cumulativeDelivered': (_showPassengerEstimates
                  ? (item['cumulativePassengersDelivered'] as num?)?.toInt()
                  : (item['cumulativeDelivered'] as num?)?.toInt()) ?? 0,
            })
        .toList();

    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        primaryXAxis: const CategoryAxis(
          labelRotation: -45,
          labelStyle: TextStyle(fontSize: 9),
        ),
        primaryYAxis: NumericAxis(
          plotBands: <PlotBand>[
            PlotBand(
              start: 0,
              end: 0,
              borderWidth: 1,
              borderColor: Colors.black,
            ),
          ],
        ),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<Map<String, dynamic>, String>>[
          ColumnSeries<Map<String, dynamic>, String>(
            name: 'Delivered',
            dataSource: chartData,
            xValueMapper: (datum, _) => datum['formattedHour'] as String,
            yValueMapper: (datum, _) => datum['delivered'] as num,
            pointColorMapper: (datum, _) =>
                (datum['delivered'] as num) < 0 ? Colors.red.shade400 : Colors.green.shade400,
          ),
          LineSeries<Map<String, dynamic>, String>(
            name: 'Cumulative',
            dataSource: chartData,
            xValueMapper: (datum, _) => datum['formattedHour'] as String,
            yValueMapper: (datum, _) => datum['cumulativeDelivered'] as num,
            color: Colors.blue,
            width: 3,
            markerSettings: const MarkerSettings(
              isVisible: true,
              color: Colors.blue,
              shape: DataMarkerType.circle,
            ),
          ),
        ],
      ),
    );
  }
}