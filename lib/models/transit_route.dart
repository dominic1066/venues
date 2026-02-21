class TransitRoute {
  final String routeId;
  final int cityId;
  final String cityName;
  final String shortName;
  final String? longName;
  final int? routeType;
  final String typeDescription;
  final bool isMonitored;

  const TransitRoute({
    required this.routeId,
    required this.cityId,
    required this.cityName,
    required this.shortName,
    this.longName,
    this.routeType,
    required this.typeDescription,
    required this.isMonitored,
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    return TransitRoute(
      // id: json['Id'] as int,
      routeId: json['Route_Id'] as String,
      cityId: json['CityId'] as int,
      cityName: json['CityName'] as String,
      shortName: json['route_Short_Name'] as String,
      longName: json['route_Long_Name'] as String?,
      routeType: json['route_Type'] as int?,
      typeDescription: json['Description'] as String,
      isMonitored: json['Monitor'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'RouteId': routeId,
      'CityId': cityId,
      'CityName': cityName,
      'ShortName': shortName,
      if (longName != null) 'LongName': longName,
      if (routeType != null) 'Type': routeType,
      'TypeDescription': typeDescription,
      'Monitor': isMonitored,
    };
  }

  @override
  String toString() {
    return 'TransitRoute(routeId: $routeId, cityId: $cityId, cityName: $cityName, shortName: $shortName, longName: $longName, routeType: $routeType, typeDescription: $typeDescription)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransitRoute &&
        other.routeId == routeId &&
        other.cityId == cityId &&
        other.cityName == cityName &&
        other.shortName == shortName &&
        other.longName == longName &&
        other.routeType == routeType &&
        other.typeDescription == typeDescription;
  }

  @override
  int get hashCode => Object.hash(routeId, cityId, cityName, shortName, longName, routeType, typeDescription);
}