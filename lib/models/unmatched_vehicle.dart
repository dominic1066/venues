class UnmatchedVehicle {
  final String vehicleId;

  UnmatchedVehicle({required this.vehicleId});

  factory UnmatchedVehicle.fromJson(Map<String, dynamic> json) {
    return UnmatchedVehicle(
      vehicleId: json['vehicle_id'] as String? ?? '',
    );
  }

  @override
  String toString() => 'UnmatchedVehicle(vehicleId: $vehicleId)';
}
