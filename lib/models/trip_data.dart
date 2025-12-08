import 'trip_observation.dart';

class TripData {
  final int cityId;
  final String tripId;
  final List<TripObservation> observations;
  final int directionId;
  final String routeShortName;
  final String routeDesc;
  final int routeColour;

  const TripData({
    required this.cityId,
    required this.tripId,
    required this.observations,
    required this.directionId,
    required this.routeShortName,
    required this.routeDesc,
    required this.routeColour,
  });

  /// Returns a unique key for this trip combining cityId and tripId
  String key() => '$cityId-$tripId';

  factory TripData.fromJson(Map<String, dynamic> json, int cityId, String tripId, int directionId, String routeShortName, String routeDesc, int routeColour) {
    final shapeData = json['shape'] as List<dynamic>?;
    final observations = shapeData
            ?.map((obs) => TripObservation.fromJson(obs as Map<String, dynamic>))
            .toList() ??
        [];

    return TripData(
      cityId: cityId,
      tripId: tripId,
      observations: observations,
      directionId: directionId,
      routeShortName: routeShortName,
      routeDesc: routeDesc,
      routeColour: routeColour,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cityId': cityId,
      'tripId': tripId,
      'shape': observations.map((o) => o.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'TripData(cityId: $cityId, tripId: $tripId, observations: ${observations.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripData &&
        other.cityId == cityId &&
        other.tripId == tripId &&
        other.observations.length == observations.length;
  }

  @override
  int get hashCode => Object.hash(cityId, tripId, observations.length);
}
