import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:venues/services/venues_service.dart';
import 'package:venues/models/models.dart';

/// Debugging-focused unit test
/// Set breakpoints and step through each test case
void main() {
  group('VenuesService Debug Tests', () {
    late VenuesService venuesService;
    late MockHttpClient mockClient;

    setUp(() {
      print('🔧 Setting up test...');
      mockClient = MockHttpClient();
      venuesService = VenuesService(client: mockClient);
    });

    tearDown(() {
      print('🧹 Cleaning up test...');
      venuesService.dispose();
    });

    test('Debug: Step through getVenues() call', () async {
      // 🔴 BREAKPOINT: Set breakpoint here and step through
      print('📝 Setting up mock response...');
      
      const responseBody = '''
      {
        "venues": [
          {
            "id": 1,
            "name": "Debug Test Venue",
            "city": "Test City",
            "latitude": 47.6062,
            "longitude": -122.3321
          },
          {
            "id": 2,
            "name": "Another Venue",
            "city": "Another City",
            "latitude": 47.6062,
            "longitude": -122.3321
          }
        ]
      }''';
      
      mockClient.responses['http://localhost:3000/venue/GetVenues'] = responseBody;
      
      // 🔴 BREAKPOINT: Mock setup complete, about to make API call
      print('🌐 Making API call...');
      final venues = await venuesService.getVenues();
      
      // 🔴 BREAKPOINT: API call completed, inspect results
      print('📊 Received data, validating...');
      expect(venues, isA<List<Venue>>());
      expect(venues.length, 2);
      
      final firstVenue = venues[0];
      // 🔴 BREAKPOINT: Inspect first venue object
      expect(firstVenue.id, 1);
      expect(firstVenue.name, 'Debug Test Venue');
      expect(firstVenue.city, 'Test City');
      
      final secondVenue = venues[1];
      // 🔴 BREAKPOINT: Inspect second venue object
      expect(secondVenue.id, 2);
      expect(secondVenue.name, 'Another Venue');
      expect(secondVenue.city, 'Another City');
      
      print('✅ Test completed successfully!');
    });

    test('Debug: Step through error handling', () async {
      // 🔴 BREAKPOINT: Testing error scenarios
      print('🚨 Setting up error scenario...');
      
      mockClient.statusCodes['http://localhost:3000/venue/GetVenues'] = 500;
      mockClient.responses['http://localhost:3000/venue/GetVenues'] = 'Database connection failed';
      
      // 🔴 BREAKPOINT: About to trigger error
      print('💥 Triggering API error...');
      
      try {
        await venuesService.getVenues();
        fail('Expected ApiException to be thrown');
      } catch (e) {
        // 🔴 BREAKPOINT: Exception caught, inspect error object
        print('🎯 Error caught: $e');
        expect(e, isA<ApiException>());
        
        final apiError = e as ApiException;
        // 🔴 BREAKPOINT: Inspect ApiException properties
        expect(apiError.statusCode, 500);
        expect(apiError.message, 'Database connection failed');
        expect(apiError.endpoint, '/venue/GetVenues');
      }
      
      print('✅ Error handling test completed!');
    });

    test('Debug: Step through JSON parsing', () async {
      // 🔴 BREAKPOINT: Testing JSON parsing step by step
      print('📋 Testing JSON parsing...');
      
      const responseBody = '''
      {
        "observations": [
          {
            "venueId": 123,
            "timestamp": "2025-11-10T10:30:00Z",
            "count": 42
          }
        ]
      }''';
      
      mockClient.responses['http://localhost:3000/observations/GetOccupancyByVenue?venueId=123'] = responseBody;
      
      // 🔴 BREAKPOINT: About to parse observation data
      print('🔍 Calling getOccupancyByVenue...');
      final observations = await venuesService.getOccupancyByVenue(123);
      
      // 🔴 BREAKPOINT: Parsing completed, inspect results
      expect(observations.length, 1);
      
      final observation = observations.first;
      // 🔴 BREAKPOINT: Inspect parsed observation object
      expect(observation.venueId, 123);
      expect(observation.count, 42);
      expect(observation.timestamp, DateTime.parse('2025-11-10T10:30:00Z'));
      
      print('✅ JSON parsing test completed!');
    });
  });
}

// Mock HTTP client for testing
class MockHttpClient extends http.BaseClient {
  final Map<String, String> responses;
  final Map<String, int> statusCodes;

  MockHttpClient({
    Map<String, String>? responses,
    Map<String, int>? statusCodes,
  }) : responses = responses ?? {},
       statusCodes = statusCodes ?? {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    
    // 🔴 BREAKPOINT: Set breakpoint here to inspect HTTP requests
    print('🌐 Mock HTTP Request: $url');
    
    final statusCode = statusCodes[url] ?? 200;
    final body = responses[url] ?? '{"error": "Not mocked"}';
    
    // 🔴 BREAKPOINT: Inspect response being returned
    final bodyPreview = body.length > 50 ? '${body.substring(0, 50)}...' : body;
    print('📤 Mock HTTP Response: $statusCode - $bodyPreview');
    
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      statusCode,
      headers: {'content-type': 'text/plain'},
    );
  }
}