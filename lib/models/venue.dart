class Venue {
  final int id;
  final String name;
  final String? city;
  final double? latitude;
  final double? longitude;
  final DateTime? lastObservation;
  final int? observationCount;

  const Venue({
    required this.id,
    required this.name,
    this.city,
    this.latitude,
    this.longitude,
    this.lastObservation,
    this.observationCount,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: (json['id'] ?? json['Id']) as int, // Handle both 'id' and 'Id'
      name: json['name'] as String,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastObservation: json['last_observation'] != null ? DateTime.parse(json['last_observation']) : null,
      observationCount: json['observation_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lastObservation != null) 'last_observation': lastObservation!.toIso8601String(),
      if (observationCount != null) 'observation_count': observationCount,
    };
  }

  @override
  String toString() {
    return 'Venue(id: $id, name: $name, city: $city, latitude: $latitude, longitude: $longitude, lastObservation: $lastObservation, observationCount: $observationCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Venue &&
        other.id == id &&
        other.name == name &&
        other.city == city &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.lastObservation == lastObservation &&
        other.observationCount == observationCount;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, city, latitude, longitude, lastObservation, observationCount);
  }
}