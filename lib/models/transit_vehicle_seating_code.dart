class TransitVehicleSeatingCode {
  final String seatingCode;
  final int passengersSeated;
  final int passengersStanding;

  const TransitVehicleSeatingCode({
    required this.seatingCode,
    required this.passengersSeated,
    required this.passengersStanding,
  });

  factory TransitVehicleSeatingCode.fromJson(Map<String, dynamic> json) {
    return TransitVehicleSeatingCode(
      seatingCode: json['seatingCode'] as String? ?? '',
      passengersSeated: json['passengersSeated'] as int? ?? 0,
      passengersStanding: json['passengersStanding'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seatingCode': seatingCode,
      'passengersSeated': passengersSeated,
      'passengersStanding': passengersStanding,
    };
  }

  int get passengersTotal => passengersSeated + passengersStanding;

  @override
  String toString() {
    return 'TransitVehicleSeatingCode(seatingCode: $seatingCode, seated: $passengersSeated, standing: $passengersStanding)';
  }
}
