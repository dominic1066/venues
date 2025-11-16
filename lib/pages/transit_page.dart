import 'package:flutter/material.dart';
import '../services/transit_service.dart';
import '../models/models.dart';

class TransitPage extends StatefulWidget {
  const TransitPage({super.key});

  @override
  State<TransitPage> createState() => _TransitPageState();
}

class _TransitPageState extends State<TransitPage> {
  final TransitService _transitService = TransitService(enableDiagnostics: true);
  List<TransitType> _transitTypes = [];
  List<TransitRoute> _transitRoutes = [];
  List<TransitCity> _transitCities = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _monitorRoute(String routeId) async {
    try {
      final success = await _transitService.monitorRoute(routeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? 'Route $routeId is now being monitored'
                : 'Failed to monitor route $routeId'
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
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

  Future<void> _unmonitorRoute(String routeId) async {
    try {
      final success = await _transitService.unmonitorRoute(routeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? 'Route $routeId is no longer being monitored'
                : 'Failed to unmonitor route $routeId'
            ),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
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

  Widget _buildTransitTypesList() {
    return ListView.builder(
      itemCount: _transitTypes.length,
      itemBuilder: (context, index) {
        final type = _transitTypes[index];
        return ListTile(
          leading: const Icon(Icons.train),
          title: Text(type.transitType.toString()),
          subtitle: Text(type.description),
        );
      },
    );
  }

  Widget _buildTransitRoutesList() {
    return ListView.builder(
      itemCount: _transitRoutes.length,
      itemBuilder: (context, index) {
        final route = _transitRoutes[index];
        return ListTile(
          leading: const Icon(Icons.route),
          title: Text('${route.shortName} - ${route.longName ?? 'No description'}'),
          subtitle: Text('Route ID: ${route.routeId} • City: ${route.cityName}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'monitor') {
                _monitorRoute(route.routeId);
              } else if (value == 'unmonitor') {
                _unmonitorRoute(route.routeId);
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
        return ListTile(
          leading: const Icon(Icons.location_city),
          title: Text(city.name),
          subtitle: Text('City ID: ${city.id} • ${routesInCity.length} routes'),
          onTap: () {
            // Could navigate to city detail or show routes for this city
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${city.name} has ${routesInCity.length} routes'),
              ),
            );
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
              _buildSectionHeader('Routes (${_transitRoutes.length})'),
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
                _buildTransitRoutesList(),
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