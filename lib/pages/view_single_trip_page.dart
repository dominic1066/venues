import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/transit_service.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';
import 'dart:math';

class ViewSingleTripPage extends StatefulWidget {
  const ViewSingleTripPage({super.key});

  @override
  State<ViewSingleTripPage> createState() => _ViewSingleTripPageState();
}

class _ViewSingleTripPageState extends State<ViewSingleTripPage> {
  late TransitService _transitService;
  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  bool _isLoading = true;
  String? _error;

  // Monitored routes
  Map<String, String> _monitoredRoutes = {}; // RouteId -> RouteShortName
  String? _selectedRouteId;
  bool _isLoadingRoutes = false;
  String? _routesError;

  // Trips for selected route
  List<Trip> _trips = [];
  Trip? _selectedTrip;
  bool _isLoadingTrips = false;
  String? _tripsError;

  // Trip loading
  bool _isLoadingTrip = false;
  String? _tripError;

  // Store loaded trip data
  TripData? _tripData;
  TripShape? _tripShape;

  // Default map center (will be updated when a city is selected)
  LatLng _mapCenter = LatLng(-41.2865, 174.7762); // Wellington as default
  double _mapZoom = 11.0;

  bool _isInitialised = false;

  // City selector position and size
  double _selectorLeft = 16;
  double _selectorTop = 16;
  double _selectorWidth = 400;
  double _selectorHeight = 220; // Taller to accommodate route selector, trip selector, and load button

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialised) {
      _transitService = TransitService(
        server: ApiConfig.of(context).server,
        enableDiagnostics: true,
      );
      
      _isInitialised = true;
      _loadCities();
    }
  }

  @override
  void dispose() {
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
          // Load monitored routes for the first city
          _loadMonitoredRoutes(_selectedCity!.id);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMonitoredRoutes(int cityId) async {
    setState(() {
      _isLoadingRoutes = true;
      _routesError = null;
      _monitoredRoutes.clear();
      _selectedRouteId = null;
      // Clear trips when routes are reloaded
      _trips.clear();
      _selectedTrip = null;
    });

    try {
      final routes = await _transitService.getMonitoredRoutes(cityId);
      setState(() {
        _monitoredRoutes = routes;
        _isLoadingRoutes = false;
      });
    } catch (e) {
      setState(() {
        _routesError = e.toString();
        _isLoadingRoutes = false;
      });
    }
  }

  Future<void> _loadTripsForRoute(int cityId, String routeId) async {
    setState(() {
      _isLoadingTrips = true;
      _tripsError = null;
      _trips.clear();
      _selectedTrip = null;
    });

    try {
      final trips = await _transitService.getTripsForRoute(cityId, routeId);
      setState(() {
        _trips = trips;
        _isLoadingTrips = false;
      });
    } catch (e) {
      setState(() {
        _tripsError = e.toString();
        _isLoadingTrips = false;
      });
    }
  }

  Future<void> _loadTrip() async {
    if (_selectedCity == null || _selectedTrip == null) {
      return;
    }

    setState(() {
      _isLoadingTrip = true;
      _tripError = null;
      _tripData = null;
      _tripShape = null;
    });

    try {
      // Load trip shape
      final tripShape = await _transitService.getShapeForTrip(_selectedCity!.id, _selectedTrip!.tripId);
      
      // Load trip observations (we'll need to determine route info)
      final tripData = await _transitService.getObservationsForTrip(
        _selectedCity!.id, 
        _selectedTrip!.tripId, 
        0, // Default direction
        'Unknown Route', // Will be updated if we find it
        'Trip ${_selectedTrip!.tripId}',
        0, // Default color
        'Unknown Destination'
      );
      
      // Calculate average speed
      tripData.calculateAverageSpeedKmh(tripShape);
      
      setState(() {
        _tripShape = tripShape;
        _tripData = tripData;
        _isLoadingTrip = false;
      });
      
      // Center map on trip if we have shape data
      if (tripShape.points.isNotEmpty) {
        _centerMapOnTrip(tripShape);
      }
      
    } catch (e) {
      setState(() {
        _tripError = e.toString();
        _isLoadingTrip = false;
      });
    }
  }

  void _updateMapForCity(TransitCity city) {
    // Use city coordinates if available
    final coordinates = city.latitude != null && city.longitude != null
        ? LatLng(city.latitude!, city.longitude!)
        : _getCityCoordinates(city.name);
    
    setState(() {
      _mapCenter = coordinates;
      _mapZoom = 11.0;
    });
  }

  void _centerMapOnTrip(TripShape tripShape) {
    if (tripShape.points.isEmpty) return;
    
    // Calculate center of trip shape
    double minLat = tripShape.points.first.lat;
    double maxLat = tripShape.points.first.lat;
    double minLon = tripShape.points.first.lon;
    double maxLon = tripShape.points.first.lon;
    
    for (final point in tripShape.points) {
      minLat = min(minLat, point.lat);
      maxLat = max(maxLat, point.lat);
      minLon = min(minLon, point.lon);
      maxLon = max(maxLon, point.lon);
    }
    
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    
    setState(() {
      _mapCenter = LatLng(centerLat, centerLon);
      _mapZoom = 13.0; // Zoom in more to see the trip details
    });
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

  /// Build tooltip message for trip
  String _buildTripTooltipMessage() {
    if (_tripData == null) return 'No trip data';
    
    String baseMessage = '${_tripData!.routeShortName} - ${_tripData!.headsign}\n'
        'Speed: ${_tripData!.averageSpeedKmh >= 0 ? _tripData!.averageSpeedKmh.toStringAsFixed(1) : 'N/A'} km/h\n'
        'Trip ID: ${_tripData!.tripId}';
    
    if (_tripData!.finished) {
      baseMessage += '\nTRIP FINISHED';
    }
    
    return baseMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Single Trip'),
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
            onTap: () {
              Navigator.pushReplacementNamed(context, '/map');
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
            selected: true,
            onTap: () {
              Navigator.pop(context);
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
        ],
      ),
    );
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
            child: _buildCityAndTripSelector(),
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
                  _selectorWidth = _selectorWidth.clamp(350, MediaQuery.of(context).size.width - _selectorLeft);
                  _selectorHeight = _selectorHeight.clamp(120, MediaQuery.of(context).size.height - _selectorTop);
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

  Widget _buildCityAndTripSelector() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City selector
          Row(
            children: [
              const Icon(Icons.location_city),
              const SizedBox(width: 12),
              const Text(
                'Select City:',
                style: TextStyle(
                  fontSize: 14,
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
                      child: Text(
                        city.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (TransitCity? newCity) {
                    if (newCity != null) {
                      setState(() {
                        _selectedCity = newCity;
                        _updateMapForCity(newCity);
                        // Clear trip data when city changes
                        _tripData = null;
                        _tripShape = null;
                      });
                      // Load monitored routes for the new city
                      _loadMonitoredRoutes(newCity.id);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route selector
          Row(
            children: [
              const Icon(Icons.route),
              const SizedBox(width: 12),
              const Text(
                'Select Route:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isLoadingRoutes
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _routesError != null
                        ? Container(
                            height: 40,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Error loading routes',
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButton<String>(
                            value: _selectedRouteId,
                            isExpanded: true,
                            hint: const Text(
                              'Select a route...',
                              style: TextStyle(fontSize: 14),
                            ),
                            items: _monitoredRoutes.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  entry.value, // RouteShortName
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newRouteId) {
                              setState(() {
                                _selectedRouteId = newRouteId;
                                _selectedTrip = null; // Clear selected trip when route changes
                              });
                              // Load trips for the new route
                              if (newRouteId != null && _selectedCity != null) {
                                _loadTripsForRoute(_selectedCity!.id, newRouteId);
                              }
                            },
                          ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Trip selection dropdown
          Row(
            children: [
              const Icon(Icons.route),
              const SizedBox(width: 12),
              const Text(
                'Trip:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isLoadingTrips
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _tripsError != null
                        ? Container(
                            height: 40,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Error loading trips',
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _selectedRouteId == null
                            ? Container(
                                height: 40,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Select a route first',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ),
                              )
                            : DropdownButton<Trip>(
                                value: _selectedTrip,
                                isExpanded: true,
                                hint: const Text(
                                  'Select a trip...',
                                  style: TextStyle(fontSize: 14),
                                ),
                                items: _trips.map((trip) {
                                  return DropdownMenuItem<Trip>(
                                    value: trip,
                                    child: Text(
                                      trip.tripId,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (Trip? newTrip) {
                                  setState(() {
                                    _selectedTrip = newTrip;
                                  });
                                },
                              ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_isLoadingTrip || _selectedTrip == null) ? null : _loadTrip,
                child: _isLoadingTrip
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedTrip == null ? null : () {
                  Clipboard.setData(ClipboardData(text: _selectedTrip!.tripId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trip ID copied: ${_selectedTrip!.tripId}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Icon(Icons.copy, size: 16),
              ),
            ],
          ),
          // Trip status indicator
          if (_tripError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: $_tripError',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else if (_tripData != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(
                    _tripData!.finished ? Icons.check_circle : Icons.directions_bus,
                    color: _tripData!.finished ? Colors.grey : Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tripData!.finished 
                          ? 'Trip Finished - ${_tripData!.routeShortName}'
                          : 'Active Trip - ${_tripData!.routeShortName} (${_tripData!.observations.length} observations)',
                      style: TextStyle(
                        color: _tripData!.finished ? Colors.grey : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
        // Draw city district area circles if city is selected
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
        // Draw trip shape if available
        if (_tripShape != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _tripShape!.points.map((point) => LatLng(point.lat, point.lon)).toList(),
                strokeWidth: 3.0,
                color: Colors.blue.withValues(alpha: 0.8),
              ),
            ],
          ),
        // Draw observation points if available
        if (_tripData != null && _tripData!.observations.isNotEmpty)
          MarkerLayer(
            markers: [
              // Historical observations as circles
              ..._tripData!.observations.take(_tripData!.observations.length - 1).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final obs = entry.value;
                
                // Calculate radius: starts at 2, increases to 8
                final maxRadius = 8.0;
                final minRadius = 2.0;
                final progress = _tripData!.observations.length > 1 
                    ? index / (_tripData!.observations.length - 2)
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
                    message: 'Time: $timeStr\nObservation ${index + 1} of ${_tripData!.observations.length}\nOccupancy status: ${obs.occupancyStatus}',
                    preferBelow: false,
                    child: CustomPaint(
                      size: Size(radius * 2, radius * 2),
                      painter: _OccupancyShapePainter(
                        occupancyStatus: obs.occupancyStatus,
                        radius: radius,
                      ),
                    ),
                  ),
                );
              }),
              // Current position as arrow (if trip is not finished)
              if (!(_tripData?.finished ?? false) && _tripData!.observations.isNotEmpty)
                Marker(
                  point: LatLng(_tripData!.observations.last.lat, _tripData!.observations.last.lon),
                  width: 30,
                  height: 30,
                  child: Tooltip(
                    message: _buildTripTooltipMessage(),
                    preferBelow: false,
                    child: Transform.rotate(
                      angle: _tripData!.observations.last.bearing * 3.14159 / 180,
                      child: Icon(
                        Icons.navigation,
                        color: Colors.red.withValues(alpha: 0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _OccupancyShapePainter extends CustomPainter {
  final int occupancyStatus;
  final double radius;

  _OccupancyShapePainter({
    required this.occupancyStatus,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final r = radius - 1; // slight inset so stroke isn't clipped

    switch (occupancyStatus) {
      case 0: // Circle
        canvas.drawCircle(center, r, paint);
        break;

      case 1: // Line (horizontal)
        canvas.drawLine(
          Offset(center.dx - r, center.dy),
          Offset(center.dx + r, center.dy),
          paint,
        );
        break;

      case 2: // Square
      case 4: // Square
        final half = r * 0.9;
        canvas.drawRect(
          Rect.fromCenter(center: center, width: half * 2, height: half * 2),
          paint,
        );
        break;

      case 3: // Triangle
        _drawPolygon(canvas, paint, center, r, 3, -pi / 2);
        break;

      case 5: // Pentagon
        _drawPolygon(canvas, paint, center, r, 5, -pi / 2);
        break;

      case 6: // Hexagon
        _drawPolygon(canvas, paint, center, r, 6, 0);
        break;

      default: // fallback: circle
        canvas.drawCircle(center, r, paint);
        break;
    }
  }

  void _drawPolygon(Canvas canvas, Paint paint, Offset center, double r, int sides, double startAngle) {
    final path = ui.Path();
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + (2 * pi * i / sides);
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OccupancyShapePainter oldDelegate) =>
      oldDelegate.occupancyStatus != occupancyStatus || oldDelegate.radius != radius;
}