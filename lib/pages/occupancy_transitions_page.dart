import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/transit_service.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';
import 'dart:math';

class OccupancyTransitionsPage extends StatefulWidget {
  const OccupancyTransitionsPage({super.key});

  @override
  State<OccupancyTransitionsPage> createState() => _OccupancyTransitionsPageState();
}

class _OccupancyTransitionsPageState extends State<OccupancyTransitionsPage> {
  late TransitService _transitService;
  List<TransitCity> _cities = [];
  TransitCity? _selectedCity;
  bool _isLoading = true;
  String? _error;

  // Date selection
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingTransitions = false;
  String? _transitionsError;

  // Store loaded occupancy transitions
  List<OccupancyTransition> _transitions = [];

  // Default map center (will be updated when a city is selected)
  LatLng _mapCenter = LatLng(-41.2865, 174.7762); // Wellington as default
  double _mapZoom = 11.0;

  bool _isInitialised = false;

  // City selector position and size
  double _selectorLeft = 16;
  double _selectorTop = 16;
  double _selectorWidth = 500;
  double _selectorHeight = 300; // Accommodate city selector, date picker, and load button

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
          // Load transitions for today by default
          _loadOccupancyTransitions();
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateMapForCity(TransitCity city) {
    // Update map center based on city (simplified - could be enhanced with city-specific coordinates)
    setState(() {
      // For now, use Wellington coordinates as default
      _mapCenter = LatLng(-41.2865, 174.7762);
      _mapZoom = 11.0;
    });
  }

  Future<void> _loadOccupancyTransitions() async {
    if (_selectedCity == null) return;

    setState(() {
      _isLoadingTransitions = true;
      _transitionsError = null;
    });

    try {
      final dateString = _selectedDate.toIso8601String().substring(0, 10); // YYYY-MM-DD format
      final transitions = await _transitService.getOccupancyTransitions(
        _selectedCity!.id, 
        tripDate: dateString,
      );
      
      setState(() {
        _transitions = transitions;
        _isLoadingTransitions = false;
      });

      // Update map bounds to show all transitions if any exist
      if (transitions.isNotEmpty) {
        _fitMapToTransitions(transitions);
      }
    } catch (e) {
      setState(() {
        _transitionsError = e.toString();
        _isLoadingTransitions = false;
      });
    }
  }

  void _fitMapToTransitions(List<OccupancyTransition> transitions) {
    if (transitions.isEmpty) return;

    double minLat = transitions.first.latitude;
    double maxLat = transitions.first.latitude;
    double minLng = transitions.first.longitude;
    double maxLng = transitions.first.longitude;

    for (final transition in transitions) {
      minLat = min(minLat, transition.latitude);
      maxLat = max(maxLat, transition.latitude);
      minLng = min(minLng, transition.longitude);
      maxLng = max(maxLng, transition.longitude);
    }

    setState(() {
      _mapCenter = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      // Calculate zoom level based on bounds - simplified calculation
      double latDiff = maxLat - minLat;
      double lngDiff = maxLng - minLng;
      double maxDiff = max(latDiff, lngDiff);
      
      if (maxDiff < 0.01) {
        _mapZoom = 15.0;
      } else if (maxDiff < 0.05) {
        _mapZoom = 13.0;
      } else if (maxDiff < 0.1) {
        _mapZoom = 12.0;
      } else {
        _mapZoom = 11.0;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadOccupancyTransitions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Occupancy Transitions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: const [
          ServerSelector(),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
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
            onTap: () {
              Navigator.pushReplacementNamed(context, '/view-single-trip');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Occupancy Transitions'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading cities...'),
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
              'Error loading cities',
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

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: _mapZoom,
            minZoom: 8.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.venues.app',
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
            MarkerLayer(
              markers: _buildOccupancyMarkers(),
            ),
          ],
        ),
        _buildCitySelector(),
      ],
    );
  }

  List<Marker> _buildOccupancyMarkers() {
    return _transitions.map((transition) {
      Color markerColor;
      IconData markerIcon;
      
      if (transition.increment > 0) {
        // Boarding - green
        markerColor = Colors.green;
        markerIcon = Icons.add_circle;
      } else {
        // Alighting - red  
        markerColor = Colors.red;
        markerIcon = Icons.remove_circle;
      }
      
      return Marker(
        point: LatLng(transition.latitude, transition.longitude),
        width: 16,
        height: 16,
        child: Tooltip(
          message: 'Trip: ${transition.tripId}\\n'
                  'Change: ${transition.increment > 0 ? '+' : ''}${transition.increment}\\n'
                  'Time: ${DateTime.fromMillisecondsSinceEpoch(transition.timestamp * 1000)}',
          child: Icon(
            markerIcon,
            color: markerColor,
            size: 12,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCitySelector() {
    return Positioned(
      left: _selectorLeft,
      top: _selectorTop,
      child: Card(
        child: Container(
          width: _selectorWidth,
          height: _selectorHeight,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // City selector
              Row(
                children: [
                  const Icon(Icons.location_city),
                  const SizedBox(width: 8),
                  const Text('City:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
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
                            _transitions.clear();
                          });
                          _updateMapForCity(newCity);
                          _loadOccupancyTransitions();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Date selector
              Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8),
                  const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _selectedDate.toIso8601String().substring(0, 10),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.date_range),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Status row
              Row(
                children: [
                  if (_isLoadingTransitions)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading transitions...'),
                      ],
                    )
                  else if (_transitionsError != null)
                    Expanded(
                      child: Text(
                        'Error: $_transitionsError',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      'Found ${_transitions.length} transitions',
                      style: TextStyle(
                        color: _transitions.isEmpty ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isLoadingTransitions ? null : _loadOccupancyTransitions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}