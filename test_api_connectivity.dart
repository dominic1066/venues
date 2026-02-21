import 'package:venues/services/venues_service.dart';
import 'package:venues/models/models.dart';

Future<void> main() async {
  print('🔧 VenuesService API Testing Guide\n');
  
  print('Before running these tests, make sure:');
  print('1. Your ObservationsNode API is running at localhost:3000');
  print('2. The API has some test data\n');
  
  final venuesService = VenuesService();
  
  // Test basic connectivity first
  print('📡 Testing API connectivity...');
  try {
    final venues = await venuesService.getVenues();
    print('✅ API is reachable! Found ${venues.length} venues\n');
    
    // If we get here, the API is working, so run more tests
    await runDetailedTests(venuesService);
    
  } catch (e) {
    print('❌ Cannot connect to API at localhost:3000');
    print('   Error: $e\n');
    
    print('💡 To test the API wrapper:');
    print('1. Start your ObservationsNode API server');
    print('2. Run this script again');
    print('3. Or use the unit tests: flutter test');
    print('4. Or run the Flutter app: flutter run\n');
  } finally {
    venuesService.dispose();
  }
}

Future<void> runDetailedTests(VenuesService service) async {
  print('🚀 Running detailed API tests...\n');
  
  // Test all endpoints systematically
  final tests = [
    () async {
      print('📍 Testing getVenues()...');
      final venues = await service.getVenues();
      print('   → Found ${venues.length} venues');
      return venues;
    },
    
    () async {
      print('📍 Testing getVenuesToMonitor()...');
      final venues = await service.getVenuesToMonitor();
      print('   → Found ${venues.length} venues to monitor');
      return venues;
    },
    
    () async {
      print('📍 Testing getCities()...');
      final cities = await service.getCities();
      print('   → Found ${cities.length} cities');
      if (cities.isNotEmpty) {
        print('     Cities: ${cities.map((c) => c.city).take(3).join(', ')}${cities.length > 3 ? '...' : ''}');
      }
      return cities;
    },
    
    () async {
      print('📍 Testing getVenueGroups()...');
      final groups = await service.getVenueGroups();
      print('   → Found ${groups.length} venue groups');
      if (groups.isNotEmpty) {
        print('     Example: "${groups.first.name}" (ID: ${groups.first.id})');
      }
      return groups;
    },
  ];
  
  // Run basic tests
  List<Venue>? venues;
  List<City>? cities;
  List<VenueGroup>? groups;
  
  for (int i = 0; i < tests.length; i++) {
    try {
      final result = await tests[i]();
      if (i == 0) {
        venues = result as List<Venue>;
      } else if (i == 2) {
        cities = result as List<City>;
      } else if (i == 3) {
        groups = result as List<VenueGroup>;
      }
      print('   ✅ Success\n');
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }
  
  // Test parameterized endpoints
  if (cities != null && cities.isNotEmpty) {
    try {
      print('📍 Testing getVenues(city: "${cities.first.city}")...');
      final cityVenues = await service.getVenues(city: cities.first.city);
      print('   → Found ${cityVenues.length} venues in ${cities.first.city}');
      print('   ✅ Success\n');
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }
  
  if (groups != null && groups.isNotEmpty) {
    try {
      print('📍 Testing getVenuesByGroup(${groups.first.id})...');
      final groupVenues = await service.getVenuesByGroup(groups.first.id);
      print('   → Found ${groupVenues.length} venues in group "${groups.first.name}"');
      print('   ✅ Success\n');
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }
  
  if (venues != null && venues.isNotEmpty) {
    try {
      print('📍 Testing getOccupancyByVenue(${venues.first.id})...');
      final observations = await service.getOccupancyByVenue(venues.first.id);
      print('   → Found ${observations.length} observations for "${venues.first.name}"');
      if (observations.isNotEmpty) {
        final latest = observations.first;
        print('     Latest: ${latest.count} people at ${latest.timestamp}');
      }
      print('   ✅ Success\n');
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }
  
  if (groups != null && groups.isNotEmpty) {
    try {
      print('📍 Testing getOccupancyByVenueGroup(${groups.first.id})...');
      final observations = await service.getOccupancyByVenueGroup(groups.first.id);
      print('   → Found ${observations.length} observations for group "${groups.first.name}"');
      print('   ✅ Success\n');
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }
  
  print('🏁 All tests completed!');
}