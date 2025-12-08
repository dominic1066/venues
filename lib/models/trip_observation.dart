class TripObservation {
  final double lat;
  final double lon;
  final int timestamp;
  final double bearing;

  const TripObservation({
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.bearing,
  });

  factory TripObservation.fromJson(Map<String, dynamic> json) {
    return TripObservation(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['long'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      bearing: (json['bearing'] as num).toDouble(),
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
