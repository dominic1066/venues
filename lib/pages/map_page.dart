import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/transit_service.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late TransitService _transitService;
  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  bool _isLoading = true;
  String? _error;

  List<LiveTrip> _liveTrips = [];
  bool _isLoadingTrips = false;
  String? _tripsError;

  // Store loaded trip shapes for display on map
  final Map<String, TripShape> _loadedShapes = {};

  // Store loaded trip data (observations), keyed by cityId-tripId
  final Map<String, TripData> _loadedObservations = {};

  // Timer for periodic refresh
  Timer? _refreshTimer;

  // Default map center (will be updated when a city is selected)
  // LatLng _mapCenter = LatLng(43.6532, -79.3832); // Toronto as default
  LatLng _mapCenter = LatLng(-41.2865, 174.7762); // Wellington as default
  double _mapZoom = 11.0;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _transitService = TransitService(
        server: ApiConfig.of(context).server,
        enableDiagnostics: true,
      );
      _isInitialized = true;
      _loadCities();
      // Start periodic refresh every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _loadLiveTrips();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _transitService.dispose();
    super.dispose();
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
      final trips = await _transitService.getMonitoredLiveTrips(1);
      setState(() {
        _liveTrips = trips;
        _isLoadingTrips = false;
      });
      
      // Load shapes and observations for first 5 trips in background
      // This won't block the UI since we don't await it
      _loadTripDataInBackground(1, trips.take(10).toList());
    } catch (e) {
      setState(() {
        _tripsError = e.toString();
        _isLoadingTrips = false;
      });
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
        final tripData = await _transitService.getObservationsForTrip(cityId, trip.tripId, trip.directionId, trip.routeShortName, trip.routeDesc, trip.routeColour);
        
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
    final coordinates = _getCityCoordinates(city.name);
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
      body: Column(
        children: [
          _buildCitySelector(),
          Expanded(
            child: _buildMapView(),
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
        ],
      ),
    );
  }

  Widget _buildCitySelector() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.red.shade100,
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
        child: const Text('No cities available'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
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
                return DropdownMenuItem<TransitCity>(
                  value: city,
                  child: Text(city.name),
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
              strokeWidth: 3.0,
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
            return observations.asMap().entries.where((entry) => entry.key < observations.length - 1).map((obsEntry) {
              final obsIndex = obsEntry.key;
              final obs = obsEntry.value;
              
              // Calculate radius: starts at 2, increases to 5
              final maxRadius = 5.0;
              final minRadius = 2.0;
              final progress = observations.length > 1 
                  ? obsIndex / (observations.length - 1)
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
                      'Time: $timeStr\n'
                      'Observation ${obsIndex + 1} of ${observations.length}',
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
            final color = colors[tripIndex % colors.length];
            
            return Marker(
              point: LatLng(lastObs.lat, lastObs.lon),
              width: 30,
              height: 30,
              child: Tooltip(
                message: '${tripData.routeShortName} (${tripData.routeDesc})',
                preferBelow: false,
                child: Transform.rotate(
                  angle: lastObs.bearing * 3.14159 / 180, // Convert degrees to radians
                  child: Icon(
                    Icons.navigation,
                    color: color.withValues(alpha: 0.9),
                    size: 24,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // Add markers or other layers here in the future
      ],
    );
  }
}
