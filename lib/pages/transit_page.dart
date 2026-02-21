import 'package:flutter/material.dart';
import '../services/transit_service.dart';
import '../models/models.dart';
import '../config/api_config.dart';
import '../widgets/server_selector.dart';

class TransitPage extends StatefulWidget {
  const TransitPage({super.key});

  @override
  State<TransitPage> createState() => _TransitPageState();
}

class _TransitPageState extends State<TransitPage> {
  late TransitService _transitService;
  List<TransitType> _transitTypes = [];
  List<TransitRoute> _transitRoutes = [];
  List<TransitRoute> _filteredRoutes = [];
  List<TransitCity> _transitCities = [];
  final Set<String> _selectedCities = {};
  final Set<int> _selectedTransitTypes = {};
  // Set<int> _monitoredRouteIds = {}; // Track which routes are being monitored
  bool _isLoading = false;
  String? _errorMessage;
  bool _isinitialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isinitialised) {
      _transitService = TransitService(
        server: ApiConfig.of(context).server,
        enableDiagnostics: true,
      );
      _isinitialised = true;
      _loadData();
    }
  }

  @override
  void dispose() {
    _transitService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all transit data in parallel
      final futures = await Future.wait([
        _transitService.getTransitTypes(),
        _transitService.getTransitRoutes(),
        _transitService.getTransitCities(),
      ]);

      setState(() {
        _transitTypes = futures[0] as List<TransitType>;
        _transitRoutes = futures[1] as List<TransitRoute>;
        _transitCities = futures[2] as List<TransitCity>;
        _filteredRoutes = _transitRoutes; // Initially show all routes
        _selectedCities.clear(); // No city filter initially
        _selectedTransitTypes.clear(); // No type filter initially
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _monitorRoute(int cityId, String routeId) async {
    try {
      final success = await _transitService.monitorRoute(cityId, routeId);
      if (mounted) {
        if (success) {
          // Reload data to get updated monitoring status
          await _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Route $routeId is now being monitored'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to monitor route $routeId'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unmonitorRoute(int cityId, String routeId) async {
    try {
      final success = await _transitService.unmonitorRoute(cityId, routeId);
      if (mounted) {
        if (success) {
          // Reload data to get updated monitoring status
          await _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Route $routeId is no longer being monitored'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unmonitor route $routeId'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleCitySelection(String cityName) {
    setState(() {
      if (_selectedCities.contains(cityName)) {
        _selectedCities.remove(cityName);
      } else {
        _selectedCities.add(cityName);
      }
      _updateFilteredRoutes();
    });
  }

  void _toggleTransitTypeSelection(int transitTypeId) {
    setState(() {
      if (_selectedTransitTypes.contains(transitTypeId)) {
        _selectedTransitTypes.remove(transitTypeId);
      } else {
        _selectedTransitTypes.add(transitTypeId);
      }
      _updateFilteredRoutes();
    });
  }

  void _updateFilteredRoutes() {
    _filteredRoutes = _transitRoutes.where((route) {
      // Filter by city if any cities are selected
      bool cityMatch = _selectedCities.isEmpty || _selectedCities.contains(route.cityName);
      
      // Filter by transit type if any types are selected
      bool typeMatch = _selectedTransitTypes.isEmpty || 
                      (route.routeType != null && _selectedTransitTypes.contains(route.routeType!));
      
      return cityMatch && typeMatch;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedCities.clear();
      _selectedTransitTypes.clear();
      _updateFilteredRoutes();
    });
  }

  Widget _buildTransitTypesList() {
    return ListView.builder(
      itemCount: _transitTypes.length,
      itemBuilder: (context, index) {
        final type = _transitTypes[index];
        final transitTypeStr = type.transitType.toString();
        final isSelected = _selectedTransitTypes.contains(type.transitType);
        return CheckboxListTile(
          value: isSelected,
          title: Text(transitTypeStr),
          subtitle: Text(type.description),
          secondary: const Icon(Icons.train),
          onChanged: (bool? value) {
            _toggleTransitTypeSelection(type.transitType);
          },
        );
      },
    );
  }

  Widget _buildTransitRoutesList() {
    return ListView.builder(
      itemCount: _filteredRoutes.length,
      itemBuilder: (context, index) {
        final route = _filteredRoutes[index];
        final isMonitored = route.isMonitored;
        
        return ListTile(
          leading: Icon(
            isMonitored ? Icons.visibility : Icons.visibility_off,
            color: isMonitored ? Colors.green : Colors.grey,
          ),
          title: Text('${route.shortName} - ${route.longName ?? 'No description'}'),
          subtitle: Text('Route ID: ${route.routeId} • City: ${route.cityName}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'monitor') {
                _monitorRoute(route.cityId, route.routeId);
              } else if (value == 'unmonitor') {
                _unmonitorRoute(route.cityId, route.routeId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'monitor',
                child: Row(
                  children: [
                    Icon(Icons.visibility),
                    SizedBox(width: 8),
                    Text('Monitor'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unmonitor',
                child: Row(
                  children: [
                    Icon(Icons.visibility_off),
                    SizedBox(width: 8),
                    Text('Unmonitor'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransitCitiesList() {
    return ListView.builder(
      itemCount: _transitCities.length,
      itemBuilder: (context, index) {
        final city = _transitCities[index];
        final routesInCity = _transitRoutes.where((route) => route.cityName == city.name).toList();
        final isSelected = _selectedCities.contains(city.name);
        return CheckboxListTile(
          value: isSelected,
          title: Text(city.name),
          subtitle: Text('City ID: ${city.id} • ${routesInCity.length} routes'),
          secondary: const Icon(Icons.location_city),
          onChanged: (bool? value) {
            _toggleCitySelection(city.name);
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  Widget _wideScreenLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transit Types column
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Transit Types (${_transitTypes.length})'),
              Expanded(child: _buildTransitTypesList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Transit Cities column
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Cities (${_transitCities.length})'),
              Expanded(child: _buildTransitCitiesList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Transit Routes column
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCities.isNotEmpty || _selectedTransitTypes.isNotEmpty
                          ? 'Filtered Routes (${_filteredRoutes.length}/${_transitRoutes.length})'
                          : 'All Routes (${_filteredRoutes.length})',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (_selectedCities.isNotEmpty || _selectedTransitTypes.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearFilters,
                        tooltip: 'Clear all filters',
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildTransitRoutesList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrowScreenLayout() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Routes'),
              Tab(text: 'Cities'),
              Tab(text: 'Types'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Routes tab with filter indicator
                Column(
                  children: [
                    if (_selectedCities.isNotEmpty || _selectedTransitTypes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Showing ${_filteredRoutes.length} of ${_transitRoutes.length} routes',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearFilters,
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(child: _buildTransitRoutesList()),
                  ],
                ),
                _buildTransitCitiesList(),
                _buildTransitTypesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Transit Management'),
        actions: [
          const ServerSelector(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.deepPurple,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Venues & Transit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Management App',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Venues'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/venues');
              },
            ),
            ListTile(
              leading: const Icon(Icons.train),
              title: const Text('Transit'),
              selected: true,
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/map');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Transit Analysis'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/transit-analysis');
              },
            ),
            ListTile(
              leading: const Icon(Icons.route),
              title: const Text('View Single Trip'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/view-single-trip');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Occupancy Transitions'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/occupancy-transitions');
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_bus),
              title: const Text('Vehicles'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/vehicles');
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('Live Updates'),
              subtitle: const Text('MQTT Real-time'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/mqtt-transit');
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 600;
                    return isWideScreen ? _wideScreenLayout() : _narrowScreenLayout();
                  },
                ),
    );
  }
}