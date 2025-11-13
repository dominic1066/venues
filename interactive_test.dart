import 'package:venues/services/venues_service.dart';

/// Interactive test file - run this in VS Code with F5 or Ctrl+F5
/// Make sure your API server is running at localhost:3000
Future<void> main() async {
  print('🔧 Interactive VenuesService Test');
  print('================================\n');
  
  // Create the service
  final venuesService = VenuesService();
  
  try {
    // Test 1: Simple venue fetch
    print('🎯 Test 1: Fetching all venues...');
    final venues = await venuesService.getVenues();
    print('Result: ${venues.length} venues found');
    
    if (venues.isNotEmpty) {
      print('First venue: ${venues.first.name} (ID: ${venues.first.id})');
      
      // Test 2: Get occupancy for first venue
      print('\n🎯 Test 2: Getting occupancy for first venue...');
      final observations = await venuesService.getOccupancyByVenue(venues.first.id);
      print('Result: ${observations.length} observations found');
    }
    
    // Test 3: Get cities
    print('\n🎯 Test 3: Fetching cities...');
    final cities = await venuesService.getCities();
    print('Result: ${cities.length} cities found');
    
    // Test 4: Get venue groups
    print('\n🎯 Test 4: Fetching venue groups...');
    final groups = await venuesService.getVenueGroups();
    print('Result: ${groups.length} venue groups found');
    
    print('\n✅ All tests completed successfully!');
    
  } catch (e) {
    print('\n❌ Test failed: $e');
    print('\nTroubleshooting:');
    print('1. Is your API server running at localhost:3000?');
    print('2. Does the API have test data?');
    print('3. Check the API logs for errors');
  } finally {
    venuesService.dispose();
    print('\n🏁 Test session ended');
  }
}