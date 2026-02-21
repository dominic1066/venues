class TripShapePoint {
  final double lat;
  final double lon;
  final int sequence;
  final double distanceTravelled;

  const TripShapePoint({
    required this.lat,
    required this.lon,
    required this.sequence,
    required this.distanceTravelled,
  });

  factory TripShapePoint.fromJson(Map<String, dynamic> json) {
    return TripShapePoint(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['long'] as num).toDouble(),
      sequence: json['sequence'] as int,
      distanceTravelled: (json['distance_travelled'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'sequence': sequence,
      'distanceTravelled': distanceTravelled,
    };
  }

  @override
  String toString() {
    return 'TripShapePoint(lat: $lat, lon: $lon, sequence: $sequence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripShapePoint &&
        other.lat == lat &&
        other.lon == lon &&
        other.sequence == sequence;
  }

  @override
  int get hashCode => Object.hash(lat, lon, sequence);
}

class TripShape {
  final int cityId;
  final String shapeId;
  final List<TripShapePoint> points;

  const TripShape({
    required this.cityId,
    required this.shapeId,
    required this.points,
  });

  /// Returns a unique key for this shape combining cityId and shapeId
  String key() => '$cityId-$shapeId';

  factory TripShape.fromJson(Map<String, dynamic> json, int cityId, String shapeId) {
    final pointsData = json['shape'] as List<dynamic>?;
    final points = pointsData
            ?.map((point) => TripShapePoint.fromJson(point as Map<String, dynamic>))
            .toList() ??
        [];

    return TripShape(
      cityId: cityId,
      shapeId: shapeId,
      points: points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cityId': cityId,
      'shapeId': shapeId,
      'shape': points.map((p) => p.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'TripShape(cityId: $cityId, shapeId: $shapeId, points: ${points.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripShape &&
        other.cityId == cityId &&
        other.shapeId == shapeId &&
        other.points.length == points.length;
  }

  @override
  int get hashCode => Object.hash(cityId, shapeId, points.length);
}
