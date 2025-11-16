class TransitRoute {
  final int id;
  final String routeId;
  final String cityName;
  final String shortName;
  final String? longName;
  final int? routeType;
  final String typeDescription;

  const TransitRoute({
    required this.id,
    required this.routeId,
    required this.cityName,
    required this.shortName,
    this.longName,
    this.routeType,
    required this.typeDescription,
  });

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    return TransitRoute(
      id: json['Id'] as int,
      routeId: json['RouteId'] as String,
      cityName: json['CityName'] as String,
      shortName: json['ShortName'] as String,
      longName: json['LongName'] as String?,
      routeType: json['Type'] as int?,
      typeDescription: json['Description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'RouteId': routeId,
      'CityName': cityName,
      'ShortName': shortName,
      if (longName != null) 'LongName': longName,
      if (routeType != null) 'Type': routeType,
      'TypeDescription': typeDescription,
    };
  }

  @override
  String toString() {
    return 'TransitRoute(id: $id, routeId: $routeId, cityName: $cityName, shortName: $shortName, longName: $longName, routeType: $routeType, typeDescription: $typeDescription)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransitRoute &&
        other.routeId == routeId &&
        other.cityName == cityName &&
        other.shortName == shortName &&
        other.longName == longName &&
        other.routeType == routeType &&
        other.typeDescription == typeDescription;
  }

  @override
  int get hashCode => Object.hash(id, routeId, cityName, shortName, longName, routeType, typeDescription);
}