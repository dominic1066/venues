class OccupancyTransition {
  final int cityId;
  final String tripId;
  final DateTime tripDate;
  final int increment;
  final double latitude;
  final double longitude;
  final int timestamp;

  const OccupancyTransition({
    required this.cityId,
    required this.tripId,
    required this.tripDate,
    required this.increment,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory OccupancyTransition.fromJson(Map<String, dynamic> json) {
    return OccupancyTransition(
      cityId: json['CityId'] as int,
      tripId: json['TripId'] as String,
      tripDate: DateTime.parse(json['TripDate'] as String),
      increment: json['Increment'] as int,
      latitude: (json['Latitude'] as num).toDouble(),
      longitude: (json['Longitude'] as num).toDouble(),
      timestamp: json['Timestamp'] as int,
    );
  }

  @override
  String toString() {
    return 'OccupancyTransition(cityId: $cityId, tripId: $tripId, tripDate: $tripDate, increment: $increment, latitude: $latitude, longitude: $longitude, timestamp: $timestamp)';
  }
}