class DistrictHourlySpeed {
  final String routeId;
  final double? inwardSpeed;
  final double? outwardSpeed;
  final int theHour;

  DistrictHourlySpeed({
    required this.routeId,
    this.inwardSpeed,
    this.outwardSpeed,
    required this.theHour,
  });


  factory DistrictHourlySpeed.fromJson(Map<String, dynamic> json) {
    return DistrictHourlySpeed(
      routeId: json['routeId'] as String,
      inwardSpeed: (json['inwardSpeed'] as num?)?.toDouble(),
      outwardSpeed: (json['outwardSpeed'] as num?)?.toDouble(),
      theHour: json['theHour'] as int,
    );
  }
  
}

class SpeedPair {
  final double? inwardSpeed;
  final double? outwardSpeed;
  final int theHour;

  SpeedPair({
    this.inwardSpeed,
    this.outwardSpeed,
    required this.theHour,
  });
}

class RouteHourlySpeedCollection{
  final String routeId;
  final List<SpeedPair> hourlySpeeds;

  RouteHourlySpeedCollection({
    required this.routeId,
    required this.hourlySpeeds,
  });
}