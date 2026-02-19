import 'dart:math';
import 'package:flutter/foundation.dart';

import 'trip_observation.dart';
import 'trip_shape.dart';

const double closeEnough = 50.0;
const double asGoodAsZero = 5.0;

double distanceBetweenPoints(double lat1, double lon1, double lat2, double lon2) {
  // Haversine formula
  const double R = 6371.0; // Radius of earth in kilometers. Use 3956 for miles
  final double dlat = _radians(lat2 - lat1);
  final double dlon = _radians(lon2 - lon1);
  final double a = pow(sin(dlat / 2), 2) + 
                   cos(_radians(lat1)) * cos(_radians(lat2)) * pow(sin(dlon / 2), 2);
  final double c = 2 * asin(sqrt(a));
  final double distance = R * c * 1000; // convert to metres
  return distance;
}

double _radians(double degrees) {
  return degrees * pi / 180.0;
}

class TripData {
  final int cityId;
  final String tripId;
  final List<TripObservation> observations;
  final int directionId;
  final String routeShortName;
  final String routeDesc;
  final int routeColour;
  final lastShapePointIndex = -1;
  double averageSpeedKmh = -1.0;
  bool finished = false;
  bool inBusinessDistrict = false;
  final String headsign;

  TripData({
    required this.cityId,
    required this.tripId,
    required this.observations,
    required this.directionId,
    required this.routeShortName,
    required this.routeDesc,
    required this.routeColour,
    required this.headsign,
  });

  /// Returns a unique key for this trip combining cityId and tripId
  String key() => '$cityId-$tripId';

  factory TripData.fromJson(Map<String, dynamic> json, int cityId, String tripId, int directionId, String routeShortName, String routeDesc, int routeColour, String headsign) {
    List<dynamic>? shapeData = json['shape'] as List<dynamic>?;
    shapeData ??= json['observations'] as List<dynamic>?;
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
      headsign: headsign,
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

  double calculateAverageSpeedKmh(TripShape shape) {
    if (observations.length < 2) {
      return 0.0;
    }

    final firstObs = observations.first;
    final lastObs = observations.last;

    TripShapePoint? finalShapePoint = findLatestShapePoint(shape);
    if (finalShapePoint == null) {
      return -1.0;
    }
    double distanceMeters = finalShapePoint.distanceTravelled;
    int timeSeconds = lastObs.timestamp - firstObs.timestamp;
    if (timeSeconds <= 0) {
      return -1.0;
    }
    double hours = timeSeconds / 3600.0;
    double speedKmh = (distanceMeters / 1000.0) / hours;
    averageSpeedKmh = speedKmh;
    return speedKmh;
  }

  int occupancyStatus() {
    if (observations.isEmpty) {
      return -1;
    }
    return observations.last.occupancyStatus;
  }

  TripShapePoint ? findLatestShapePoint(TripShape shape) {
    if (observations.isEmpty || shape.points.isEmpty) {
      return null;
    }

    // where within the shape is the most recent observation?
    // if we have a lastShapePointIndex, start from there
    int startingShapeIndex = max(0, lastShapePointIndex);
    double minDistanceFound = double.infinity;
    int indexAtMinDistance = -1;

    for (int i = startingShapeIndex; i < shape.points.length; i++) {
      double distance = distanceBetweenPoints(
        observations.last.lat,
        observations.last.lon,
        shape.points[i].lat,
        shape.points[i].lon,
      );
      if (distance < minDistanceFound) {
        minDistanceFound = distance;
        indexAtMinDistance = i;
      }
      // if within "asGoodAsZero" metres, we have found it
      if (distance <= asGoodAsZero) {
        debugPrint('Found shape point at index $i within $asGoodAsZero (as good as zero) metres');
        return shape.points[i];
      }
      // if distance is growing and minDistanceFound is less than closeEnough, we can stop
      if (distance > (minDistanceFound * 3) && minDistanceFound < closeEnough) {
        debugPrint('Found shape point at index $indexAtMinDistance within $closeEnough (close enough) metres');
        return shape.points[indexAtMinDistance];
      }
    }
    if (minDistanceFound < closeEnough) {
      debugPrint('Found shape point at index $indexAtMinDistance within $closeEnough (close enough) metres at end of search');
      return shape.points[indexAtMinDistance];
    }
    debugPrint('No shape point found within acceptable distance. Min distance: $minDistanceFound metres');
    return null;
  }
}
