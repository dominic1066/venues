class MonitorRouteRequest {
  final int cityId;
  final String routeId;
  
  const MonitorRouteRequest({
    required this.cityId,
    required this.routeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'cityId': cityId,
      'routeId': routeId,
    };
  }

  @override
  String toString() {
    return 'MonitorRouteRequest(CityId: $cityId, RouteId: $routeId)';
  }
}