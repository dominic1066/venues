class TripObservation {
  final double lat;
  final double lon;
  final int timestamp;
  final double bearing;
  final int occupancyStatus;
  final double averageOccupancyStatus;

  const TripObservation({
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.bearing,
    required this.occupancyStatus,
    required this.averageOccupancyStatus,
  });

  factory TripObservation.fromJson(Map<String, dynamic> json) {
    return TripObservation(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['long'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      bearing: (json['bearing'] as num).toDouble(),
      occupancyStatus: json['occupancy_status'] as int? ?? 0,
      averageOccupancyStatus: (json['average_occupancy_status'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp,
      'bearing': bearing,
    };
  }

  @override
  String toString() {
    return 'TripObservation(lat: $lat, lon: $lon, timestamp: $timestamp, bearing: $bearing)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripObservation &&
        other.lat == lat &&
        other.lon == lon &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(lat, lon, timestamp);
}
