import 'dart:convert';
import 'trip_observation.dart';

class LiveTrip {
  final String tripId;
  final int directionId;
  final String routeShortName;
  final String routeDesc;
  final int routeColour;
  final String routeId;
  final DateTime startDate;
  final String headsign;
  final String finalStopId;
  final double finalStopLatitude;
  final double finalStopLongitude;
  List<TripObservation> observations;


  LiveTrip({
    required this.tripId,
    required this.directionId,
    required this.routeShortName,
    required this.routeDesc,
    required this.routeColour,
    required this.routeId,
    required this.startDate,
    required this.headsign,
    required this.finalStopId,
    required this.finalStopLatitude,
    required this.finalStopLongitude,
    this.observations = const [],
  });

  factory LiveTrip.fromJson(Map<String, dynamic> json) {
    // Parse route_color from hex string to int
    int parseRouteColor(dynamic colorValue) {
      if (colorValue == null) return 0;
      if (colorValue is int) return colorValue;
      if (colorValue is String) {
        // Remove any '#' prefix and parse as hex
        final hexString = colorValue.replaceFirst('#', '');
        return int.tryParse(hexString, radix: 16) ?? 0;
      }
      return 0;
    }

    return LiveTrip(
      tripId: json['trip_id'] as String? ?? '',
      directionId: json['direction_id'] as int? ?? 0,
      routeShortName: json['route_short_name'] as String? ?? '',
      routeDesc: json['route_desc'] as String? ?? '',
      routeColour: parseRouteColor(json['route_color']),
      routeId: json['route_id'] as String? ?? '',
      startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
      headsign: json['trip_headsign'] as String? ?? '',
      finalStopId: json['final_stop_id'] as String? ?? '',
      finalStopLatitude: (json['final_stop_lat'] as num?)?.toDouble() ?? 0.0,
      finalStopLongitude: (json['final_stop_lon'] as num?)?.toDouble() ?? 0.0,
      observations: () {
        final actualObsString = json['actual_obs'] as String?;
        if (actualObsString != null && actualObsString.isNotEmpty) {
          try {
            final actualObsList = jsonDecode(actualObsString) as List<dynamic>;
            return actualObsList
                .map((obs) => TripObservation.fromJson(obs as Map<String, dynamic>))
                .toList();
          } catch (e) {
            return <TripObservation>[];
          }
        }
        return <TripObservation>[];
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
    };
  }

  @override
  String toString() {
    return 'LiveTrip(tripId: $tripId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LiveTrip && other.tripId == tripId;
  }

  @override
  int get hashCode => tripId.hashCode;
}
