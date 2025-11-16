class RouteSubmission {
  final String routeId;
  final int cityId;
  final String shortName;
  final String? longName;
  final int? routeType;
  final String? agencyId;

  const RouteSubmission({
    required this.routeId,
    required this.cityId,
    required this.shortName,
    this.longName,
    this.routeType,
    this.agencyId,
  });

  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
      'cityId': cityId,
      'shortName': shortName,
      if (longName != null) 'longName': longName,
      if (routeType != null) 'routeType': routeType,
      if (agencyId != null) 'agencyId': agencyId,
    };
  }

  @override
  String toString() {
    return 'RouteSubmission(routeId: $routeId, cityId: $cityId, shortName: $shortName, longName: $longName, routeType: $routeType, agencyId: $agencyId)';
  }
}