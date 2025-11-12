import 'package:flutter/material.dart';
import 'services/venues_service.dart';
import 'models/models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Venues Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VenuesPage(),
    );
  }
}

class VenuesPage extends StatefulWidget {
  const VenuesPage({super.key});

  @override
  State<VenuesPage> createState() => _VenuesPageState();
}

class _VenuesPageState extends State<VenuesPage> {
  final VenuesService _venuesService = VenuesService(enableDiagnostics: true);
  List<Venue> _venues = [];
  List<VenueGroup> _venueGroups = [];
  List<City> _cities = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _venuesService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all data in parallel
      final futures = await Future.wait([
        _venuesService.getVenues(),
        _venuesService.getVenueGroups(),
        _venuesService.getCities(),
      ]);

      setState(() {
        _venues = futures[0] as List<Venue>;
        _venueGroups = futures[1] as List<VenueGroup>;
        _cities = futures[2] as List<City>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOccupancyForVenue(int venueId) async {
    try {
      final observations = await _venuesService.getOccupancyByVenue(venueId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${observations.length} observations for venue $venueId'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading occupancy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Venues API Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
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
                    
                    if (isWideScreen) {
                      // Wide screen: show columns side by side
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cities column
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Cities (${_cities.length})',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _cities.length,
                                    itemBuilder: (context, index) {
                                      final city = _cities[index];
                                      return ListTile(
                                        title: Text(city.city),
                                        onTap: () async {
                                          try {
                                            final venues = await _venuesService.getVenues(city: city.city);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${city.city} has ${venues.length} venues'),
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
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          // Groups column
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Groups (${_venueGroups.length})',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _venueGroups.length,
                                    itemBuilder: (context, index) {
                                      final group = _venueGroups[index];
                                      return ListTile(
                                        title: Text(group.name),
                                        subtitle: Text('ID: ${group.id}'),
                                        onTap: () async {
                                          try {
                                            final venues = await _venuesService.getVenuesByGroup(group.id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Group "${group.name}" has ${venues.length} venues'),
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
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          // Venues column
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Venues (${_venues.length})',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _venues.length,
                                    itemBuilder: (context, index) {
                                      final venue = _venues[index];
                                      return ListTile(
                                        title: Text(venue.name),
                                        subtitle: Text('ID: ${venue.id}${venue.city != null ? ' • ${venue.city}' : ''}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.analytics),
                                          onPressed: () => _loadOccupancyForVenue(venue.id),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Narrow screen: show tabs
                      return DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'Venues'),
                                Tab(text: 'Groups'),
                                Tab(text: 'Cities'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  // Venues tab
                                  ListView.builder(
                                    itemCount: _venues.length,
                                    itemBuilder: (context, index) {
                                      final venue = _venues[index];
                                      return ListTile(
                                        title: Text(venue.name),
                                        subtitle: Text('ID: ${venue.id}${venue.city != null ? ' • ${venue.city}' : ''}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.analytics),
                                          onPressed: () => _loadOccupancyForVenue(venue.id),
                                        ),
                                      );
                                    },
                                  ),
                                  // Groups tab
                                  ListView.builder(
                                    itemCount: _venueGroups.length,
                                    itemBuilder: (context, index) {
                                      final group = _venueGroups[index];
                                      return ListTile(
                                        title: Text(group.name),
                                        subtitle: Text('ID: ${group.id}'),
                                        onTap: () async {
                                          try {
                                            final venues = await _venuesService.getVenuesByGroup(group.id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Group "${group.name}" has ${venues.length} venues'),
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
                                        },
                                      );
                                    },
                                  ),
                                  // Cities tab
                                  ListView.builder(
                                    itemCount: _cities.length,
                                    itemBuilder: (context, index) {
                                      final city = _cities[index];
                                      return ListTile(
                                        title: Text(city.city),
                                        onTap: () async {
                                          try {
                                            final venues = await _venuesService.getVenues(city: city.city);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${city.city} has ${venues.length} venues'),
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
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
    );
  }
}
