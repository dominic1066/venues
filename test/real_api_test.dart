import 'package:flutter_test/flutter_test.dart';
import 'package:venues/services/venues_service.dart';
import 'package:venues/models/models.dart';

/// Real API Integration Tests
/// 
/// IMPORTANT: Before running these tests:
/// 1. Make sure your ObservationsNode API is running at localhost:3000
/// 2. Ensure your API has test data populated
/// 3. These tests will make actual HTTP requests
/// 
/// To run ONLY these tests:
/// flutter test test/real_api_test.dart
void main() {
  group('VenuesService Real API Tests', () {
    late VenuesService venuesService;

    // Skip all tests if API is not available
    bool skipTests = false;

    setUpAll(() async {
      print('🔌 Checking API availability...');
      venuesService = VenuesService();
      
      try {
        // Quick connectivity test
        await venuesService.getVenues().timeout(Duration(seconds: 5));
        print('✅ API is available at localhost:3000');
      } catch (e) {
        print('❌ API not available: $e');
        print('⚠️  Skipping real API tests...');
        skipTests = true;
      }
    });

    tearDownAll(() {
      venuesService.dispose();
    });

    test('Real API: Get all venues', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getVenues() against real API...');
      
      // 🔴 BREAKPOINT: Set breakpoint here to debug real API call
      final venues = await venuesService.getVenues();
      
      // Basic validation
      expect(venues, isA<List<Venue>>());
      print('✅ Received ${venues.length} venues from real API');
      
      if (venues.isNotEmpty) {
        final firstVenue = venues.first;
        // 🔴 BREAKPOINT: Inspect real venue data
        expect(firstVenue.id, isA<int>());
        expect(firstVenue.name, isA<String>());
        expect(firstVenue.name.isNotEmpty, isTrue);
        
        print('   First venue: ${firstVenue.name} (ID: ${firstVenue.id})');
        if (firstVenue.city != null) {
          print('   City: ${firstVenue.city}');
        }
        if (firstVenue.latitude != null && firstVenue.longitude != null) {
          print('   Location: ${firstVenue.latitude}, ${firstVenue.longitude}');
        }
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get venues to monitor', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getVenuesToMonitor() against real API...');
      
      // 🔴 BREAKPOINT: Set breakpoint here
      final monitorVenues = await venuesService.getVenuesToMonitor();
      
      expect(monitorVenues, isA<List<Venue>>());
      print('✅ Received ${monitorVenues.length} venues to monitor');
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get cities', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getCities() against real API...');
      
      // 🔴 BREAKPOINT: Set breakpoint here
      final cities = await venuesService.getCities();
      
      expect(cities, isA<List<City>>());
      print('✅ Received ${cities.length} cities');
      
      if (cities.isNotEmpty) {
        print('   Cities: ${cities.map((c) => c.city).take(5).join(', ')}${cities.length > 5 ? '...' : ''}');
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get venue groups', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getVenueGroups() against real API...');
      
      // 🔴 BREAKPOINT: Set breakpoint here
      final groups = await venuesService.getVenueGroups();
      
      expect(groups, isA<List<VenueGroup>>());
      print('✅ Received ${groups.length} venue groups');
      
      if (groups.isNotEmpty) {
        final firstGroup = groups.first;
        print('   First group: ${firstGroup.name} (ID: ${firstGroup.id})');
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get venues by city (if cities exist)', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getVenues(city: ...) against real API...');
      
      // First get available cities
      final cities = await venuesService.getCities();
      
      if (cities.isNotEmpty) {
        final testCity = cities.first.city;
        print('   Testing with city: $testCity');
        
        // 🔴 BREAKPOINT: Set breakpoint here to debug filtered query
        final cityVenues = await venuesService.getVenues(city: testCity);
        
        expect(cityVenues, isA<List<Venue>>());
        print('✅ Found ${cityVenues.length} venues in $testCity');
        
        // Verify all returned venues are in the requested city
        for (final venue in cityVenues) {
          if (venue.city != null) {
            expect(venue.city, equals(testCity));
          }
        }
      } else {
        print('⚠️  No cities available, skipping city filter test');
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get venues by group (if groups exist)', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getVenuesByGroup() against real API...');
      
      // First get available groups
      final groups = await venuesService.getVenueGroups();
      
      if (groups.isNotEmpty) {
        final testGroup = groups.first;
        print('   Testing with group: ${testGroup.name} (ID: ${testGroup.id})');
        
        // 🔴 BREAKPOINT: Set breakpoint here
        final groupVenues = await venuesService.getVenuesByGroup(testGroup.id);
        
        expect(groupVenues, isA<List<Venue>>());
        print('✅ Found ${groupVenues.length} venues in group "${testGroup.name}"');
      } else {
        print('⚠️  No venue groups available, skipping group test');
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get occupancy data (if venues exist)', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getOccupancyByVenue() against real API...');
      
      // First get available venues
      final venues = await venuesService.getVenues();
      
      if (venues.isNotEmpty) {
        final testVenue = venues.first;
        print('   Testing occupancy for: ${testVenue.name} (ID: ${testVenue.id})');
        
        // 🔴 BREAKPOINT: Set breakpoint here
        final observations = await venuesService.getOccupancyByVenue(testVenue.id);
        
        expect(observations, isA<List<Observation>>());
        print('✅ Found ${observations.length} observations for venue ${testVenue.id}');
        
        if (observations.isNotEmpty) {
          final latest = observations.first;
          print('   Latest observation: ${latest.count} people at ${latest.timestamp}');
          
          // Validate observation data
          expect(latest.count, isA<int>());
          expect(latest.timestamp, isA<DateTime>());
        }
      } else {
        print('⚠️  No venues available, skipping occupancy test');
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Get occupancy by venue group (if groups exist)', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing getOccupancyByVenueGroup() against real API...');
      
      // First get available groups
      final groups = await venuesService.getVenueGroups();
      
      if (groups.isNotEmpty) {
        final testGroup = groups.first;
        print('   Testing group occupancy for: ${testGroup.name} (ID: ${testGroup.id})');
        
        // 🔴 BREAKPOINT: Set breakpoint here
        final observations = await venuesService.getOccupancyByVenueGroup(testGroup.id);
        
        expect(observations, isA<List<Observation>>());
        print('✅ Found ${observations.length} observations for group ${testGroup.id}');
        
        if (observations.isNotEmpty) {
          final latest = observations.first;
          print('   Sample observation: ${latest.count} people at venue ${latest.venueId} at ${latest.timestamp}');
        }
      } else {
        print('⚠️  No venue groups available, skipping group occupancy test');
      }
    }, timeout: Timeout(Duration(seconds: 30)));

    test('Real API: Error handling with invalid venue ID', () async {
      if (skipTests) {
        markTestSkipped('API not available');
        return;
      }

      print('🎯 Testing error handling with invalid venue ID...');
      
      try {
        // 🔴 BREAKPOINT: Set breakpoint here to debug error handling
        await venuesService.getOccupancyByVenue(99999); // Invalid ID
        fail('Expected an exception to be thrown for invalid venue ID');
      } catch (e) {
        // 🔴 BREAKPOINT: Inspect real API error
        print('✅ Correctly caught error: $e');
        expect(e, isA<ApiException>());
        
        if (e is ApiException) {
          print('   Error details: Status ${e.statusCode}, Message: ${e.message}');
        }
      }
    }, timeout: Timeout(Duration(seconds: 30)));
  });
}