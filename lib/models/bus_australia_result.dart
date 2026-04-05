class BusAustraliaResult {
  final String? registration;
  final String? chassis;
  final String? seatingCodes;
  final String? operator;

  const BusAustraliaResult({
    this.registration,
    this.chassis,
    this.seatingCodes,
    this.operator,
  });

  factory BusAustraliaResult.fromJson(Map<String, dynamic> json) {
    return BusAustraliaResult(
      registration: json['registration'] as String?,
      chassis: json['chassis'] as String?,
      seatingCodes: json['seatingCodes'] as String?,
      operator: json['operator'] as String?,
    );
  }

  @override
  String toString() {
    return 'BusAustraliaResult(registration: $registration, chassis: $chassis, seatingCodes: $seatingCodes, operator: $operator)';
  }
}

class BusAustraliaSearchResponse {
  final String vehicleId;
  final List<BusAustraliaResult> results;

  const BusAustraliaSearchResponse({
    required this.vehicleId,
    required this.results,
  });

  factory BusAustraliaSearchResponse.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    return BusAustraliaSearchResponse(
      vehicleId: json['vehicleId'] as String? ?? '',
      results: resultsList
          .map((r) => BusAustraliaResult.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
