import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:venues/services/venues_service.dart';
import 'package:venues/models/models.dart';

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
    final statusCode = statusCodes[url] ?? 200;
    final body = responses[url] ?? '{"error": "Not mocked"}';

    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      statusCode,
      headers: {'content-type': 'text/plain'},
    );
  }
}

void main() {
  group('VenuesService', () {
    late VenuesService venuesService;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      venuesService = VenuesService(client: mockClient);
    });

    tearDown(() {
      venuesService.dispose();
    });

    test('getVenues returns list of venues', () async {
      // Arrange
      const responseBody = '{"venues":[{"id":1,"name":"Test Venue","city":"Test City"}]}';
      mockClient.responses['http://localhost:3000/venue/GetVenues'] = responseBody;

      // Act
      final venues = await venuesService.getVenues();

      // Assert
      expect(venues, isA<List<Venue>>());
      expect(venues.length, 1);
      expect(venues.first.id, 1);
      expect(venues.first.name, 'Test Venue');
      expect(venues.first.city, 'Test City');
    });

    test('getVenues with city filter', () async {
      // Arrange
      const responseBody = '{"venues":[{"id":1,"name":"Test Venue","city":"Seattle"}]}';
      mockClient.responses['http://localhost:3000/venue/GetVenues?city=Seattle'] = responseBody;

      // Act
      final venues = await venuesService.getVenues(city: 'Seattle');

      // Assert
      expect(venues, isA<List<Venue>>());
      expect(venues.length, 1);
      expect(venues.first.city, 'Seattle');
    });

    test('getVenueGroups returns list of venue groups', () async {
      // Arrange
      const responseBody = '{"venueGroups":[{"id":1,"name":"Test Group"}]}';
      mockClient.responses['http://localhost:3000/venue/GetVenueGroups'] = responseBody;

      // Act
      final groups = await venuesService.getVenueGroups();

      // Assert
      expect(groups, isA<List<VenueGroup>>());
      expect(groups.length, 1);
      expect(groups.first.id, 1);
      expect(groups.first.name, 'Test Group');
    });

    test('getCities returns list of cities', () async {
      // Arrange
      const responseBody = '{"venues":[{"city":"Seattle"},{"city":"Portland"}]}';
      mockClient.responses['http://localhost:3000/venue/GetCities'] = responseBody;

      // Act
      final cities = await venuesService.getCities();

      // Assert
      expect(cities, isA<List<City>>());
      expect(cities.length, 2);
      expect(cities.first.city, 'Seattle');
      expect(cities.last.city, 'Portland');
    });

    test('getOccupancyByVenue returns list of observations', () async {
      // Arrange
      const responseBody = '{"observations":[{"timestamp":"2025-11-09T12:00:00Z","count":42}]}';
      mockClient.responses['http://localhost:3000/observations/GetOccupancyByVenue?venueId=1'] = responseBody;

      // Act
      final observations = await venuesService.getOccupancyByVenue(1);

      // Assert
      expect(observations, isA<List<Observation>>());
      expect(observations.length, 1);
      expect(observations.first.count, 42);
      expect(observations.first.timestamp, DateTime.parse('2025-11-09T12:00:00Z'));
    });

    test('handles API errors correctly', () async {
      // Arrange
      mockClient.statusCodes['http://localhost:3000/venue/GetVenues'] = 500;
      mockClient.responses['http://localhost:3000/venue/GetVenues'] = 'Database error: Connection failed';

      // Act & Assert
      expect(
        () => venuesService.getVenues(),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'status code',
          500,
        )),
      );
    });

    test('handles missing parameter errors', () async {
      // Arrange
      mockClient.statusCodes['http://localhost:3000/venue/GetVenuesByGroup?groupId=1'] = 400;
      mockClient.responses['http://localhost:3000/venue/GetVenuesByGroup?groupId=1'] = 'Missing groupId parameter';

      // Act & Assert
      expect(
        () => venuesService.getVenuesByGroup(1),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'status code',
          400,
        )),
      );
    });

    test('handles malformed JSON response', () async {
      // Arrange
      mockClient.responses['http://localhost:3000/venue/GetVenues'] = 'not valid json';

      // Act & Assert
      expect(
        () => venuesService.getVenues(),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Failed to parse JSON response'),
        )),
      );
    });
  });
}