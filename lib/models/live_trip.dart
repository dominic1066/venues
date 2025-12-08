class LiveTrip {
  final String tripId;
  final int directionId;
  final String routeShortName;
  final String routeDesc;
  final int routeColour;

  const LiveTrip({
    required this.tripId,
    required this.directionId,
    required this.routeShortName,
    required this.routeDesc,
    required this.routeColour,
  });

  factory LiveTrip.fromJson(Map<String, dynamic> json) {
    // Parse route_color from hex string to int
    int parseRouteColor(dynamic colorValue) {
      if (colorValue == null) return 0;
      if (colorValue is int) return colorValue;
      if (colorValue is String) {
        // Remove any '#' prefix and parse as hex
        final hexString = colorValue.replaceFirst('#', '');
        return int.tryParse(hexString, radix: 16) ?? 0;
      }
      return 0;
    }

    return LiveTrip(
      tripId: json['trip_id'] as String,
      directionId: json['direction_id'] as int,
      routeShortName: json['route_short_name'] as String,
      routeDesc: json['route_desc'] as String,
      routeColour: parseRouteColor(json['route_color']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
    };
  }

  @override
  String toString() {
    return 'LiveTrip(tripId: $tripId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveTrip && other.tripId == tripId;
  }

  @override
  int get hashCode => tripId.hashCode;
}
