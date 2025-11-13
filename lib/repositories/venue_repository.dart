import '../models/venue.dart';

class VenueRepository {
  // Private constructor for singleton pattern
  VenueRepository._();
  static final VenueRepository _instance = VenueRepository._();
  static VenueRepository get instance => _instance;

  // Mock data storage
  final List<Venue> _venues = [];

  // Get all venues
  Future<List<Venue>> getAllVenues() async {
    return List.from(_venues);
  }

  // Get venue by ID
  Future<Venue?> getVenueById(String id) async {
    try {
      return _venues.firstWhere((venue) => venue.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add new venue
  Future<void> addVenue(Venue venue) async {
    _venues.add(venue);
  }

  // Update venue
  Future<void> updateVenue(Venue venue) async {
    final index = _venues.indexWhere((v) => v.id == venue.id);
    if (index != -1) {
      _venues[index] = venue;
    }
  }

  // Delete venue
  Future<void> deleteVenue(String id) async {
    _venues.removeWhere((venue) => venue.id == id);
  }
}