class MonitorRouteRequest {
  final String routeId;

  const MonitorRouteRequest({
    required this.routeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'routeId': routeId,
    };
  }

  @override
  String toString() {
    return 'MonitorRouteRequest(routeId: $routeId)';
  }
}