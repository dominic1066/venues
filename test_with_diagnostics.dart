import 'package:venues/services/venues_service.dart';

/// Test with Clean Diagnostics
/// 
/// This shows clean, well-formatted diagnostic output
/// that won't cause console spacing issues.
Future<void> main() async {
  print('🚀 Testing VenuesService with Clean Diagnostics');
  print('==============================================\n');
  
  // Enable diagnostics to see what's happening
  final venuesService = VenuesService(enableDiagnostics: true);
  
  try {
    print('📍 Loading venues...');
    final venues = await venuesService.getVenues();
    
    print('🏙️  Loading cities...');
    final cities = await venuesService.getCities();
    
    print('🏢 Loading venue groups...');
    final groups = await venuesService.getVenueGroups();
    
    if (venues.isNotEmpty) {
      print('📊 Loading occupancy data for first venue...');
      final observations = await venuesService.getOccupancyByVenue(venues.first.id);
    }
    
    print('🎉 All API calls completed successfully!');
    
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    venuesService.dispose();
    print('\n🏁 Test completed');
  }
}