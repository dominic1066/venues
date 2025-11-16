import 'package:flutter/material.dart';
import '../services/venues_service.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class VenuesPage extends StatefulWidget {
  const VenuesPage({super.key});

  @override
  State<VenuesPage> createState() => _VenuesPageState();
}

class _VenuesPageState extends State<VenuesPage> {
  final VenuesService _venuesService = VenuesService(enableDiagnostics: true);
  List<Venue> _venues = [];
  List<Venue> _filteredVenues = [];
  List<VenueGroup> _venueGroups = [];
  List<City> _cities = [];
  Set<String> _selectedCities = {};
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
        _filteredVenues = _venues; // Initially show all venues
        _selectedCities.clear(); // No city filter initially
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleCitySelection(String city) {
    setState(() {
      if (_selectedCities.contains(city)) {
        _selectedCities.remove(city);
      } else {
        _selectedCities.add(city);
      }
      _updateFilteredVenues();
    });
  }

  void _updateFilteredVenues() {
    if (_selectedCities.isEmpty) {
      // Show all venues if no cities are selected
      _filteredVenues = _venues;
    } else {
      // Filter venues by selected cities
      _filteredVenues = _venues.where((venue) => 
        venue.city != null && _selectedCities.contains(venue.city)
      ).toList();
    }
  }

  void _clearCityFilter() {
    setState(() {
      _selectedCities.clear();
      _updateFilteredVenues();
    });
  }

  Widget _buildVenuesList() {
    return ListView.builder(
      itemCount: _filteredVenues.length,
      itemBuilder: (context, index) {
        final venue = _filteredVenues[index];
        return ListTile(
          title: Text(venue.name),
          subtitle: Text('${venue.city != null ? '${venue.city}' : ''}, Last Obs: ${venue.lastObservation != null ? DateFormat('dd/MM/yyyy HH:mm').format(venue.lastObservation!.toLocal()) : 'No known observations'}'),
          trailing: Tooltip(
            message: _getObservationStatusTooltip(venue.lastObservation),
            child: CircleAvatar(
              radius: 8,
              backgroundColor: _getObservationStatusColor(venue.lastObservation),
            ),
          ),
        );
      },
    );
  }

  String _getObservationStatusTooltip(DateTime? lastObservation) {
    if (lastObservation == null) {
      return 'No observations recorded';
    }
    
    final now = DateTime.now().toUtc();
    final observationUtc = lastObservation.toUtc();
    final difference = now.difference(observationUtc);
    
    if (difference.inMinutes <= 30) {
      return 'Recent observation (within 30 minutes)';
    } else {
      return 'Older observation (${difference.inMinutes} minutes ago)';
    }
  }

  Color _getObservationStatusColor(DateTime? lastObservation) {
    if (lastObservation == null) {
      return Colors.grey; // No data
    }
    
    final now = DateTime.now().toUtc();
    final observationUtc = lastObservation.toUtc();
    final difference = now.difference(observationUtc);
    
    if (difference.inMinutes <= 30) {
      return Colors.green; // Recent data
    } else {
      return Colors.orange; // Older data
    }
  }

  Widget _buildCitiesList() {
    return ListView.builder(
      itemCount: _cities.length,
      itemBuilder: (context, index) {
        final city = _cities[index];
        final isSelected = _selectedCities.contains(city.city);
        return CheckboxListTile(
          title: Text(city.city),
          value: isSelected,
          onChanged: (bool? value) {
            _toggleCitySelection(city.city);
          },
        );
      },
    );
  }

  Widget _buildGroupsList() {
    return ListView.builder(
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

  Widget wideScreenLayout(){
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cities column
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Cities (${_cities.length})'),
              Expanded(child: _buildCitiesList()),
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
              _buildSectionHeader('Groups (${_venueGroups.length})'),
              Expanded(child: _buildGroupsList()),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCities.isNotEmpty
                          ? 'Venues in ${_selectedCities.join(', ')} (${_filteredVenues.length}/${_venues.length})'
                          : 'All Venues (${_filteredVenues.length})',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (_selectedCities.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearCityFilter,
                        tooltip: 'Show all venues',
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildVenuesList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget narrowScreenLayout(){
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
                Column(
                  children: [
                    if (_selectedCities.isNotEmpty)
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
                                  'Showing venues in ${_selectedCities.join(', ')}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearCityFilter,
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(child: _buildVenuesList()),
                  ],
                ),
                // Groups tab
                _buildGroupsList(),
                // Cities tab
                _buildCitiesList(),
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
        title: const Text('Venues Management'),
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
              selected: true,
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.train),
              title: const Text('Transit'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacementNamed(context, '/transit');
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
                    return isWideScreen ? wideScreenLayout() : narrowScreenLayout();
                  },
                ),
    );
  }
}