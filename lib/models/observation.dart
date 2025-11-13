class Observation {
  final int? venueId;
  final DateTime timestamp;
  final int count;

  const Observation({
    this.venueId,
    required this.timestamp,
    required this.count,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      venueId: (json['venueId'] ?? json['VenueId']) as int?,
      timestamp: DateTime.parse((json['timestamp'] ?? json['Timestamp']) as String),
      count: (json['count'] ?? json['Occupancy']) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (venueId != null) 'venueId': venueId,
      'timestamp': timestamp.toIso8601String(),
      'count': count,
    };
  }

  @override
  String toString() {
    return 'Observation(venueId: $venueId, timestamp: $timestamp, count: $count)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Observation &&
        other.venueId == venueId &&
        other.timestamp == timestamp &&
        other.count == count;
  }

  @override
  int get hashCode {
    return Object.hash(venueId, timestamp, count);
  }
}