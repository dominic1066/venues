class Vehicle {
  final int cityId;
  final String vehicleId;
  final int passengersSeated;
  final int passengersStanding;
  final int passengersTotal;
  final String? make;
  final String? model;
  final String? registration;

  Vehicle({
    required this.cityId,
    required this.vehicleId,
    required this.passengersSeated,
    required this.passengersStanding,
    required this.passengersTotal,
    this.make,
    this.model,
    this.registration,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      cityId: json['cityId'] as int? ?? 0,
      vehicleId: json['vehicleId'] as String? ?? '',
      passengersSeated: json['passengersSeated'] as int? ?? 0,
      passengersStanding: json['passengersStanding'] as int? ?? 0,
      passengersTotal: json['passengersTotal'] as int? ?? 0,
      make: json['make'] as String?,
      model: json['model'] as String?,
      registration: json['registration'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cityId': cityId,
      'vehicleId': vehicleId,
      'passengersSeated': passengersSeated,
      'passengersStanding': passengersStanding,
      'passengersTotal': passengersTotal,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (registration != null) 'registration': registration,
    };
  }

  @override
  String toString() {
    return 'Vehicle(cityId: $cityId, vehicleId: $vehicleId, passengersTotal: $passengersTotal, make: $make, model: $model, registration: $registration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle &&
        other.cityId == cityId &&
        other.vehicleId == vehicleId &&
        other.passengersSeated == passengersSeated &&
        other.passengersStanding == passengersStanding &&
        other.passengersTotal == passengersTotal &&
        other.make == make &&
        other.model == model &&
        other.registration == registration;
  }

  @override
  int get hashCode => cityId.hashCode ^ vehicleId.hashCode;
}