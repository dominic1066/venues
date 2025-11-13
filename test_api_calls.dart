import 'package:venues/services/venues_service.dart';

Future<void> main() async {
  print('🚀 Testing VenuesService API calls...\n');
  
  final venuesService = VenuesService();
  
  try {
    // Test 1: Get all venues
    print('📍 Test 1: Getting all venues...');
    try {
      final venues = await venuesService.getVenues();
      print('✅ Success: Found ${venues.length} venues');
      if (venues.isNotEmpty) {
        print('   Example: ${venues.first.name} (ID: ${venues.first.id})');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    print('');

    // Test 2: Get venues to monitor
    print('📍 Test 2: Getting venues to monitor...');
    try {
      final monitorVenues = await venuesService.getVenuesToMonitor();
      print('✅ Success: Found ${monitorVenues.length} venues to monitor');
    } catch (e) {
      print('❌ Error: $e');
    }
    print('');

    // Test 3: Get cities
    print('📍 Test 3: Getting cities...');
    try {
      final cities = await venuesService.getCities();
      print('✅ Success: Found ${cities.length} cities');
      if (cities.isNotEmpty) {
        print('   Cities: ${cities.map((c) => c.city).join(', ')}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    print('');

    // Test 4: Get venue groups
    print('📍 Test 4: Getting venue groups...');
    try {
      final groups = await venuesService.getVenueGroups();
      print('✅ Success: Found ${groups.length} venue groups');
      if (groups.isNotEmpty) {
        print('   Example: ${groups.first.name} (ID: ${groups.first.id})');
        
        // Test 5: Get venues by group
        print('\n📍 Test 5: Getting venues for group ${groups.first.id}...');
        try {
          final groupVenues = await venuesService.getVenuesByGroup(groups.first.id);
          print('✅ Success: Found ${groupVenues.length} venues in group');
        } catch (e) {
          print('❌ Error: $e');
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    print('');

    // Test 6: Get venues by city (if we have cities)
    print('📍 Test 6: Getting venues by city...');
    try {
      final cities = await venuesService.getCities();
      if (cities.isNotEmpty) {
        final cityVenues = await venuesService.getVenues(city: cities.first.city);
        print('✅ Success: Found ${cityVenues.length} venues in ${cities.first.city}');
      } else {
        print('⚠️  Skipped: No cities available');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    print('');

    // Test 7: Get occupancy data
    print('📍 Test 7: Getting occupancy data...');
    try {
      final venues = await venuesService.getVenues();
      if (venues.isNotEmpty) {
        final observations = await venuesService.getOccupancyByVenue(venues.first.id);
        print('✅ Success: Found ${observations.length} observations for venue ${venues.first.id}');
        if (observations.isNotEmpty) {
          print('   Latest: ${observations.first.count} people at ${observations.first.timestamp}');
        }
      } else {
        print('⚠️  Skipped: No venues available');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    print('');

    // Test 8: Get occupancy by venue group
    print('📍 Test 8: Getting occupancy by venue group...');
    try {
      final groups = await venuesService.getVenueGroups();
      if (groups.isNotEmpty) {
        final observations = await venuesService.getOccupancyByVenueGroup(groups.first.id);
        print('✅ Success: Found ${observations.length} observations for group ${groups.first.id}');
      } else {
        print('⚠️  Skipped: No venue groups available');
      }
    } catch (e) {
      print('❌ Error: $e');
    }

  } finally {
    venuesService.dispose();
    print('\n🏁 Testing completed!');
  }
}