import 'package:venues/services/venues_service.dart';

/// Quick Real API Test Script
/// 
/// This script tests the VenuesService against the real API.
/// Make sure your ObservationsNode API is running at localhost:3000
/// 
/// Run with: dart run test_real_api.dart
Future<void> main() async {
  print('🌐 Testing VenuesService against Real API');
  print('==========================================\n');
  
  final venuesService = VenuesService();
  
  try {
    // Test 1: Basic connectivity
    print('🔌 Test 1: Checking API connectivity...');
    final venues = await venuesService.getVenues().timeout(Duration(seconds: 10));
    print('✅ Connected! Found ${venues.length} venues\n');
    
    // Test 2: Show sample venue data
    if (venues.isNotEmpty) {
      print('📍 Sample venue data:');
      final venue = venues.first;
      print('   ID: ${venue.id}');
      print('   Name: ${venue.name}');
      print('   City: ${venue.city ?? 'N/A'}');
      print('   Coordinates: ${venue.latitude ?? 'N/A'}, ${venue.longitude ?? 'N/A'}\n');
    }
    
    // Test 3: Get cities
    print('🏙️  Test 3: Getting cities...');
    final cities = await venuesService.getCities();
    print('✅ Found ${cities.length} cities');
    if (cities.isNotEmpty) {
      print('   Cities: ${cities.map((c) => c.city).take(3).join(', ')}${cities.length > 3 ? '...' : ''}\n');
    }
    
    // Test 4: Get venue groups
    print('🏢 Test 4: Getting venue groups...');
    final groups = await venuesService.getVenueGroups();
    print('✅ Found ${groups.length} venue groups');
    if (groups.isNotEmpty) {
      print('   Example: "${groups.first.name}" (ID: ${groups.first.id})\n');
    }
    
    // Test 5: Get occupancy data
    if (venues.isNotEmpty) {
      print('📊 Test 5: Getting occupancy data for first venue...');
      final observations = await venuesService.getOccupancyByVenue(venues.first.id);
      print('✅ Found ${observations.length} observations');
      if (observations.isNotEmpty) {
        final latest = observations.first;
        print('   Latest: ${latest.count} people at ${latest.timestamp}\n');
      }
    }
    
    // Test 6: Test error handling
    print('🚨 Test 6: Testing error handling with invalid venue ID...');
    try {
      await venuesService.getOccupancyByVenue(99999);
      print('⚠️  No error thrown (API might accept any ID)');
    } catch (e) {
      print('✅ Error correctly caught: $e');
    }
    
    print('\n🎉 All real API tests completed successfully!');
    
  } catch (e) {
    print('❌ Failed to connect to API: $e\n');
    
    print('💡 Troubleshooting:');
    print('1. Is your ObservationsNode API server running?');
    print('2. Is it accessible at http://localhost:3000?');
    print('3. Try this command: curl http://localhost:3000/venue/GetVenues');
    print('4. Check the API server logs for errors\n');
    
    print('🧪 To test with mock data instead:');
    print('   flutter test test/debug_venues_service_test.dart');
  } finally {
    venuesService.dispose();
    print('\n🏁 Test session ended');
  }
}