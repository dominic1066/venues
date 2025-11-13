class Venue {
  final int id;
  final String name;
  final String? city;
  final double? latitude;
  final double? longitude;

  const Venue({
    required this.id,
    required this.name,
    this.city,
    this.latitude,
    this.longitude,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: (json['id'] ?? json['Id']) as int, // Handle both 'id' and 'Id'
      name: json['name'] as String,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'Venue(id: $id, name: $name, city: $city, latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Venue &&
        other.id == id &&
        other.name == name &&
        other.city == city &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, city, latitude, longitude);
  }
}