import 'package:venues/services/venues_service.dart';

Future<void> main() async {
  print('Starting minimal debug test...');
  
  final service = VenuesService();
  
  try {
    print('Making API call...');
    final venues = await service.getVenues();
    print('Got ${venues.length} venues');
    print('First venue: ${venues.first.name}');
  } catch (e) {
    print('Error: $e');
  } finally {
    service.dispose();
    print('Test completed');
  }
}