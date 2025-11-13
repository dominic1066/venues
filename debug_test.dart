import 'package:venues/services/venues_service.dart';

/// Debug-friendly test file
/// Set breakpoints on the lines marked with // 🔴 BREAKPOINT
Future<void> main() async {
  print('🐛 Debugging VenuesService');
  
  // 🔴 BREAKPOINT: Set a breakpoint here to start debugging
  final venuesService = VenuesService();
  
  try {
    print('Step 1: Creating service instance...');
    // 🔴 BREAKPOINT: Service created, inspect venuesService object
    
    print('Step 2: Making first API call...');
    // 🔴 BREAKPOINT: About to make getVenues() call
    final venues = await venuesService.getVenues();
    
    // 🔴 BREAKPOINT: API call completed, inspect venues list
    print('Step 3: Received ${venues.length} venues');
    
    if (venues.isNotEmpty) {
      final firstVenue = venues.first;
      // 🔴 BREAKPOINT: Inspect first venue object
      print('First venue: ${firstVenue.name} (ID: ${firstVenue.id})');
      
      print('Step 4: Getting occupancy data...');
      // 🔴 BREAKPOINT: About to get occupancy data
      final observations = await venuesService.getOccupancyByVenue(firstVenue.id);
      
      // 🔴 BREAKPOINT: Inspect observations list
      print('Found ${observations.length} observations');
      
      if (observations.isNotEmpty) {
        final firstObs = observations.first;
        // 🔴 BREAKPOINT: Inspect observation object
        print('Latest observation: ${firstObs.count} people at ${firstObs.timestamp}');
      }
    }
    
    print('Step 5: Testing error handling...');
    try {
      // 🔴 BREAKPOINT: About to test error case
      await venuesService.getOccupancyByVenue(99999); // Invalid ID
    } catch (e) {
      // 🔴 BREAKPOINT: Caught error, inspect exception
      print('Expected error caught: $e');
    }
    
    // 🔴 BREAKPOINT: All tests completed
    print('✅ Debugging session completed successfully!');
    
  } catch (e) {
    // 🔴 BREAKPOINT: Unexpected error occurred
    print('❌ Error occurred: $e');
    print('Error type: ${e.runtimeType}');
  } finally {
    // 🔴 BREAKPOINT: Cleanup
    venuesService.dispose();
    print('🏁 Service disposed');
  }
}