class RouteDistrictStats {
  final String? routeId; // Optional - only present when routeId is specified in request
  final int? districtId; // Optional - may be missing in some responses
  final int hour;
  final int delivered;
  final double? averageSpeed; // Optional - only present when routeId is specified
  final int? passengersDelivered; 
  RouteDistrictStats({
    this.routeId,
    this.districtId,
    required this.hour,
    required this.delivered,
    this.averageSpeed,
    this.passengersDelivered, // Optional - only present when routeId is specified
  });

  factory RouteDistrictStats.fromJson(Map<String, dynamic> json) {
    return RouteDistrictStats(
      routeId: json['routeId'] as String?,
      districtId: json['districtId'] as int?,
      hour: json['hour'] as int,
      delivered: json['delivered'] as int,
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      passengersDelivered: json['passengersDelivered'] as int?, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (routeId != null) 'routeId': routeId,
      if (districtId != null) 'districtId': districtId,
      'hour': hour,
      'delivered': delivered,
      if (averageSpeed != null) 'averageSpeed': averageSpeed,
      if (passengersDelivered != null) 'passengersDelivered': passengersDelivered,
    };
  }

  @override
  String toString() {
    return 'RouteDistrictStats(routeId: $routeId, districtId: $districtId, hour: $hour, delivered: $delivered, averageSpeed: $averageSpeed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteDistrictStats &&
        other.routeId == routeId &&
        other.districtId == districtId &&
        other.hour == hour &&
        other.delivered == delivered &&
        other.averageSpeed == averageSpeed &&
        other.passengersDelivered == passengersDelivered;
  }

  @override
  int get hashCode => routeId.hashCode ^ districtId.hashCode ^ hour.hashCode ^ delivered.hashCode ^ averageSpeed.hashCode ^ passengersDelivered.hashCode;
}