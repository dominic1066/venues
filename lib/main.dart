import 'package:flutter/material.dart';
import 'pages/venues_page.dart';
import 'pages/transit_page.dart';
import 'pages/map_page.dart';
import 'pages/mqtt_transit_page.dart';
import 'pages/transit_analysis_page.dart';
import 'pages/view_single_trip_page.dart';
import 'pages/occupancy_transitions_page.dart';
import 'pages/vehicles_page.dart';
import 'pages/route_configs_page.dart';
import 'services/transit_service.dart';
import 'config/api_config.dart';
import 'config/mqtt_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ApiConfigProvider(
      initialServer: ApiServer.localhost,
      child: MqttConfigProvider(
        config: MqttConfig.local(enableDiagnostics: true),
        child: MaterialApp(
          title: 'Venues & Transit Management',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          initialRoute: '/venues',
          routes: {
            '/venues': (context) => const VenuesPage(),
            '/transit': (context) => const TransitPage(),
            '/map': (context) => const MapPage(),
            '/mqtt-transit': (context) => const MqttTransitPage(),
            '/transit-analysis': (context) => const TransitAnalysisPage(),
            '/view-single-trip': (context) => const ViewSingleTripPage(),
            '/occupancy-transitions': (context) => const OccupancyTransitionsPage(),
            '/vehicles': (context) => const VehiclesPage(),
            '/route-configs': (context) => const RouteConfigsPage(),
          },
        ),
      ),
    );
  }
}

/// Provider for MQTT configuration
class MqttConfigProvider extends InheritedWidget {
  final MqttConfig config;

  const MqttConfigProvider({
    super.key,
    required this.config,
    required super.child,
  });

  static MqttConfig of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<MqttConfigProvider>();
    return provider?.config ?? MqttConfig.local();
  }

  @override
  bool updateShouldNotify(MqttConfigProvider oldWidget) {
    return config != oldWidget.config;
  }
}

  // void _updateFilteredVenues() {
  //   if (_selectedCities.isEmpty) {
  //     // Show all venues if no cities are selected
  //     _filteredVenues = _venues;
  //   } else {
  //     // Filter venues by selected cities
  //     _filteredVenues = _venues.where((venue) => 
  //       venue.city != null && _selectedCities.contains(venue.city)
  //     ).toList();
  //   }
  // }

  // void _clearCityFilter() {
  //   setState(() {
  //     _selectedCities.clear();
  //     _updateFilteredVenues();
  //   });
  // }

  // Widget _buildVenuesList() {
  //   return ListView.builder(
  //     itemCount: _filteredVenues.length,
  //     itemBuilder: (context, index) {
  //       final venue = _filteredVenues[index];
  //       return ListTile(
  //         title: Text(venue.name),
  //         subtitle: Text('${venue.city != null ? '${venue.city}' : ''}, Last Obs: ${venue.lastObservation != null ? DateFormat('dd/MM/yyyy HH:mm').format(venue.lastObservation!.toLocal()) : 'No known observations'}'),
  //         trailing: Tooltip(
  //           message: _getObservationStatusTooltip(venue.lastObservation),
  //           child: CircleAvatar(
  //             radius: 8,
  //             backgroundColor: _getObservationStatusColor(venue.lastObservation),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  // Widget _buildCitiesList() {
  //   return ListView.builder(
  //     itemCount: _cities.length,
  //     itemBuilder: (context, index) {
  //       final city = _cities[index];
  //       final isSelected = _selectedCities.contains(city.city);
  //       return CheckboxListTile(
  //         title: Text(city.city),
  //         value: isSelected,
  //         onChanged: (bool? value) {
  //           _toggleCitySelection(city.city);
  //         },
  //       );
  //     },
  //   );
  // }

  // Widget _buildGroupsList() {
  //   return ListView.builder(
  //     itemCount: _venueGroups.length,
  //     itemBuilder: (context, index) {
  //       final group = _venueGroups[index];
  //       return ListTile(
  //         title: Text(group.name),
  //         subtitle: Text('ID: ${group.id}'),
  //         onTap: () async {
  //           try {
  //             final venues = await _venuesService.getVenuesByGroup(group.id);
  //             if (mounted) {
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('Group "${group.name}" has ${venues.length} venues'),
  //                 ),
  //               );
  //             }
  //           } catch (e) {
  //             if (mounted) {
  //               ScaffoldMessenger.of(context).showSnackBar(
  //                 SnackBar(
  //                   content: Text('Error: $e'),
  //                   backgroundColor: Colors.red,
  //                 ),
  //               );
  //             }
  //           }
  //         },
  //       );
  //     },
  //   );
  // }

  // Widget _buildSectionHeader(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.all(16.0),
  //     child: Text(
  //       title,
  //       style: Theme.of(context).textTheme.headlineSmall,
  //     ),
  //   );
  // }

  // Color _getObservationStatusColor(DateTime? lastObservation) {
  //   if (lastObservation == null) {
  //     return Colors.red; // No observations
  //   }
    
  //   final now = DateTime.now().toUtc();
  //   final observationUtc = lastObservation.toUtc();
  //   final difference = now.difference(observationUtc);
    
  //   // Debug output
  //   debugPrint('Venue observation: ${observationUtc.toString()}, Now: ${now.toString()}, Minutes ago: ${difference.inMinutes}');
    
  //   if (difference.inMinutes <= 30) {
  //     return Colors.green; // Recent observation (within 30 minutes)
  //   } else {
  //     return Colors.amber; // Old observation (older than 30 minutes)
  //   }
  // }

  // String _getObservationStatusTooltip(DateTime? lastObservation) {
  //   if (lastObservation == null) {
  //     return 'No observations recorded';
  //   }
    
  //   final now = DateTime.now().toUtc();
  //   final observationUtc = lastObservation.toUtc();
  //   final difference = now.difference(observationUtc);
    
  //   if (difference.inMinutes <= 30) {
  //     return 'Recent observation (within 30 minutes)';
  //   } else {
  //     return 'Older observation (${difference.inMinutes} minutes ago)';
  //   }
  // }

  // Future<void> _loadOccupancyForVenue(int venueId) async {
  //   try {
  //     final observations = await _venuesService.getOccupancyByVenue(venueId);
  //     observations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  //     final lastTimestamp = observations.isNotEmpty ? DateFormat('yyyy-MM-dd HH:mm').format(observations.last.timestamp) : 'N/A';
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           // content: Text('Found ${observations.length} observations for venue $venueId'),
  //           content: Text('Last observation at $lastTimestamp'),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error loading occupancy: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       backgroundColor: Theme.of(context).colorScheme.inversePrimary,
  //       title: const Text('Venues API Demo'),
  //       actions: [
  //         IconButton(
  //           icon: const Icon(Icons.refresh),
  //           onPressed: _loadData,
  //         ),
  //       ],
  //     ),
  //     body: _isLoading
  //         ? const Center(child: CircularProgressIndicator())
  //         : _errorMessage != null
  //             ? Center(
  //                 child: Column(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(
  //                       Icons.error_outline,
  //                       size: 64,
  //                       color: Colors.red[300],
  //                     ),
  //                     const SizedBox(height: 16),
  //                     Text(
  //                       'Error: $_errorMessage',
  //                       style: TextStyle(color: Colors.red[700]),
  //                       textAlign: TextAlign.center,
  //                     ),
  //                     const SizedBox(height: 16),
  //                     ElevatedButton(
  //                       onPressed: _loadData,
  //                       child: const Text('Retry'),
  //                     ),
  //                   ],
  //                 ),
  //               )
  //             : LayoutBuilder(
  //                 builder: (context, constraints) {
  //                   final isWideScreen = constraints.maxWidth > 600;
                    
  //                   if (isWideScreen) {
  //                     return wideScreenLayout();
  //                     // Wide screen: show columns side by side
  //                   } else {
  //                     return narrowScreenLayout();
  //                   }
  //                 },
  //               ),
  //   );
  // }

  // Widget wideScreenLayout(){
  //   return Row(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       // Cities column
  //       Expanded(
  //         flex: 1,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             _buildSectionHeader('Cities (${_cities.length})'),
  //             Expanded(child: _buildCitiesList()),
  //           ],
  //         ),
  //       ),
  //       const VerticalDivider(width: 1),
  //       // Groups column
  //       Expanded(
  //         flex: 1,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             _buildSectionHeader('Groups (${_venueGroups.length})'),
  //             Expanded(child: _buildGroupsList()),
  //           ],
  //         ),
  //       ),
  //       const VerticalDivider(width: 1),
  //       // Venues column
  //       Expanded(
  //         flex: 2,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Padding(
  //               padding: const EdgeInsets.all(16.0),
  //               child: Row(
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       _selectedCities.isNotEmpty
  //                         ? 'Venues in ${_selectedCities.join(', ')} (${_filteredVenues.length}/${_venues.length})'
  //                         : 'All Venues (${_filteredVenues.length})',
  //                       style: Theme.of(context).textTheme.headlineSmall,
  //                     ),
  //                   ),
  //                   if (_selectedCities.isNotEmpty)
  //                     IconButton(
  //                       icon: const Icon(Icons.clear),
  //                       onPressed: _clearCityFilter,
  //                       tooltip: 'Show all venues',
  //                     ),
  //                 ],
  //               ),
  //             ),
  //             Expanded(child: _buildVenuesList()),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget narrowScreenLayout(){
  //   // Narrow screen: show tabs
  //   return DefaultTabController(
  //     length: 3,
  //     child: Column(
  //       children: [
  //         const TabBar(
  //           tabs: [
  //             Tab(text: 'Venues'),
  //             Tab(text: 'Groups'),
  //             Tab(text: 'Cities'),
  //           ],
  //         ),
  //         Expanded(
  //           child: TabBarView(
  //             children: [
  //               // Venues tab
  //               Column(
  //                 children: [
  //                   if (_selectedCities.isNotEmpty)
  //                     Padding(
  //                       padding: const EdgeInsets.all(8.0),
  //                       child: Container(
  //                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //                         decoration: BoxDecoration(
  //                           color: Theme.of(context).colorScheme.primaryContainer,
  //                           borderRadius: BorderRadius.circular(8),
  //                         ),
  //                         child: Row(
  //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                           children: [
  //                             Expanded(
  //                               child: Text(
  //                                 'Showing venues in ${_selectedCities.join(', ')}',
  //                                 style: TextStyle(
  //                                   color: Theme.of(context).colorScheme.onPrimaryContainer,
  //                                 ),
  //                               ),
  //                             ),
  //                             IconButton(
  //                               icon: const Icon(Icons.clear),
  //                               onPressed: _clearCityFilter,
  //                               iconSize: 20,
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ),
  //                   Expanded(child: _buildVenuesList()),
  //                 ],
  //               ),
  //               // Groups tab
  //               _buildGroupsList(),
  //               // Cities tab
  //               _buildCitiesList(),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
// }
