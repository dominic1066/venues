# Venues Flutter App

A Flutter application that provides a comprehensive wrapper for the ObservationsNode API, allowing you to interact with venue and observation data.

## API Wrapper

This project includes a complete API wrapper (`VenuesService`) that provides type-safe access to all endpoints defined in the ObservationsNode API running at `localhost:3000`.

### Features

- ✅ **Complete API Coverage**: Wraps all 7 API endpoints
- ✅ **Type Safety**: Strongly typed models for all data structures
- ✅ **Error Handling**: Comprehensive error handling with custom `ApiException`
- ✅ **HTTP Client**: Uses the standard `http` package
- ✅ **Testable**: Includes unit tests with mocked HTTP responses
- ✅ **Example App**: Working Flutter app demonstrating all API calls

### API Endpoints Covered

#### Venue Endpoints
- `GET /venue/GetVenuesToMonitor` - Get venues that should be monitored
- `GET /venue/GetVenues` - Get venues (optionally filtered by city)
- `GET /venue/GetCities` - Get list of available cities
- `GET /venue/GetVenueGroups` - Get venue groups
- `GET /venue/GetVenuesByGroup` - Get venues belonging to a specific group

#### Observation Endpoints
- `GET /observations/GetOccupancyByVenue` - Get occupancy data for a specific venue
- `GET /observations/GetOccupancyByVenueGroup` - Get occupancy data for a venue group

### Usage Examples

#### Basic Setup
```dart
import 'package:venues/services/venues_service.dart';
import 'package:venues/models/models.dart';

// Create service instance
final venuesService = VenuesService();

// Don't forget to dispose when done
venuesService.dispose();
```

#### Get All Venues
```dart
try {
  final venues = await venuesService.getVenues();
  print('Found ${venues.length} venues');
  for (final venue in venues) {
    print('${venue.name} (ID: ${venue.id})');
  }
} catch (e) {
  print('Error: $e');
}
```

#### Get Venues by City
```dart
try {
  final seattleVenues = await venuesService.getVenues(city: 'Seattle');
  print('Found ${seattleVenues.length} venues in Seattle');
} catch (e) {
  print('Error: $e');
}
```

#### Get Venue Groups and Their Venues
```dart
try {
  final groups = await venuesService.getVenueGroups();
  for (final group in groups) {
    final venues = await venuesService.getVenuesByGroup(group.id);
    print('Group "${group.name}" has ${venues.length} venues');
  }
} catch (e) {
  print('Error: $e');
}
```

#### Get Occupancy Data
```dart
try {
  final observations = await venuesService.getOccupancyByVenue(venueId);
  print('Found ${observations.length} observations');
  for (final obs in observations) {
    print('${obs.timestamp}: ${obs.count} people');
  }
} catch (e) {
  print('Error: $e');
}
```

### Models

The wrapper includes the following model classes:

- **`Venue`** - Represents a venue with id, name, city, and optional groupId
- **`VenueGroup`** - Represents a venue group with id and name
- **`City`** - Represents a city
- **`Observation`** - Represents occupancy data with venueId, timestamp, and count
- **`ApiException`** - Custom exception for API errors

### Error Handling

The service provides comprehensive error handling:

- **Network Errors**: Connection issues, timeouts
- **HTTP Errors**: 400 (Bad Request), 500 (Internal Server Error)
- **Parsing Errors**: Invalid JSON responses
- **API Errors**: Custom error messages from the server

All errors are wrapped in `ApiException` with detailed information:

```dart
try {
  final venues = await venuesService.getVenues();
} catch (e) {
  if (e is ApiException) {
    print('API Error: ${e.message}');
    print('Status Code: ${e.statusCode}');
    print('Endpoint: ${e.endpoint}');
  }
}
```

### Testing

The project includes comprehensive unit tests demonstrating:

- Successful API calls with mocked responses
- Error handling for various HTTP status codes
- JSON parsing validation
- Parameter validation

Run tests with:
```bash
flutter test
```

### Dependencies

- `http: ^1.1.0` - For HTTP client functionality
- `flutter_test` - For unit testing

## Getting Started

1. Ensure the ObservationsNode API is running at `localhost:3000`
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`
4. Run tests: `flutter test`

## Project Structure

```
lib/
├── models/
│   ├── venue.dart
│   ├── venue_group.dart
│   ├── observation.dart
│   ├── city.dart
│   ├── api_exception.dart
│   └── models.dart (barrel file)
├── services/
│   └── venues_service.dart
└── main.dart (example app)

test/
└── venues_service_test.dart
```
