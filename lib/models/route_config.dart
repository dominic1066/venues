class RouteConfig {
  final int? id;
  final int? cityId;
  final String routeId;
  final int legs;
  final int terminatingDistrict;
  final bool includeInErrorCalculation;
  final int direction;

  const RouteConfig({
    this.id,
    this.cityId,
    required this.routeId,
    required this.legs,
    required this.terminatingDistrict,
    required this.includeInErrorCalculation,
    required this.direction,
  });

  /// Parses the PascalCase response returned by GetRouteConfigs
  factory RouteConfig.fromJson(Map<String, dynamic> json) {
    return RouteConfig(
      id: json['Id'] as int?,
      cityId: json['cityId'] as int?,
      routeId: (json['RouteId'] ?? json['routeId']) as String? ?? '',
      legs: (json['Legs'] ?? json['legs']) as int? ?? 0,
      terminatingDistrict: (json['TerminatingDistrict'] ?? json['terminatingDistrict']) as int? ?? 0,
      includeInErrorCalculation:
          (json['IncludeInErrorCalculation'] ?? json['includeInErrorCalculation']) as bool? ?? false,
      direction: (json['Direction'] ?? json['direction']) as int? ?? 0,
    );
  }

  /// Produces camelCase JSON as required by SubmitRouteConfig
  Map<String, dynamic> toJson() {
    return {
      if (cityId != null) 'cityId': cityId,
      'routeId': routeId,
      'legs': legs,
      'terminatingDistrict': terminatingDistrict,
      'includeInErrorCalculation': includeInErrorCalculation,
      'direction': direction,
    };
  }

  @override
  String toString() {
    return 'RouteConfig(routeId: $routeId, legs: $legs, terminatingDistrict: $terminatingDistrict, includeInErrorCalculation: $includeInErrorCalculation, direction: $direction)';
  }
}
