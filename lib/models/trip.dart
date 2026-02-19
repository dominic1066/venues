class Trip {
  final String tripId;

  Trip({
    required this.tripId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: (json['tripid'] as String? ?? json['tripId'] as String).trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripId': tripId,
    };
  }

  @override
  String toString() {
    return 'Trip(tripId: $tripId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Trip && other.tripId == tripId;
  }

  @override
  int get hashCode => tripId.hashCode;
}