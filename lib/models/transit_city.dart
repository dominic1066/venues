import 'district.dart';

class TransitCity {
  final int id;
  final String name;
  final String staticLink;
  final double? latitude;
  final double? longitude;
  final int? mpdl;
  final int? shapeDistanceMultiplier;
  final double? midPointLatitude;
  final double? midPointLongitude;
  final double? midPointRadius;
  final List<District> districts;

  const TransitCity({
    required this.id,
    required this.name,
    required this.staticLink,
    this.latitude,
    this.longitude,
    this.mpdl = 0,
    this.shapeDistanceMultiplier = 1,
    this.midPointLatitude = 0.0,
    this.midPointLongitude = 0.0,
    this.midPointRadius = 0.0,
    this.districts = const [],
  });

  factory TransitCity.fromJson(Map<String, dynamic> json, {List<District> districts = const []}) {
    return TransitCity(
      id: json['Id'] as int,
      name: json['CityName'] as String,
      staticLink: json['GTFSStaticLink'] as String,
      latitude: (json['Latitude'] as num?)?.toDouble(),
      longitude: (json['Longitude'] as num?)?.toDouble(),
      mpdl: json['MPDL'] as int? ?? 0,
      shapeDistanceMultiplier: json['ShapeDistanceMultiplier'] as int? ?? 1,
      midPointLatitude: (json['MidPointLatitude'] as num?)?.toDouble() ?? 0.0,
      midPointLongitude: (json['MidPointLongitude'] as num?)?.toDouble() ?? 0.0,
      midPointRadius: (json['MidPointRadius'] as num?)?.toDouble() ?? 0.0,
      districts: districts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CityName': name,
      'GTFSStaticLink': staticLink,
      if (latitude != null) 'Latitude': latitude,
      if (longitude != null) 'Longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'TransitCity(id: $id, name: $name, staticLink: $staticLink, districts: ${districts.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransitCity && other.id == id && other.name == name && other.staticLink == staticLink;
  }

  @override
  int get hashCode => Object.hash(id, name, staticLink);
}