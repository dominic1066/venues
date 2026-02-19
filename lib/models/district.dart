import 'dart:convert';

class Area {
  final int cityId;
  final int districtId;
  final int districtAreaId;
  final double latitude;
  final double longitude;
  final double radius;

  const Area({
    required this.cityId,
    required this.districtId,
    required this.districtAreaId,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      cityId: json['CityId'] as int,
      districtId: json['DistrictId'] as int,
      districtAreaId: json['DistrictAreaId'] as int,
      latitude: (json['Latitude'] as num).toDouble(),
      longitude: (json['Longitude'] as num).toDouble(),
      radius: (json['Radius'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'CityId': cityId,
      'DistrictId': districtId,
      'DistrictAreaId': districtAreaId,
      'Latitude': latitude,
      'Longitude': longitude,
      'Radius': radius,
    };
  }

  @override
  String toString() {
    return 'Area(cityId: $cityId, districtId: $districtId, districtAreaId: $districtAreaId, latitude: $latitude, longitude: $longitude, radius: $radius)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Area &&
        other.cityId == cityId &&
        other.districtId == districtId &&
        other.districtAreaId == districtAreaId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radius == radius;
  }

  @override
  int get hashCode {
    return Object.hash(cityId, districtId, districtAreaId, latitude, longitude, radius);
  }
}

class District {
  final int cityId;
  final int districtId;
  final String name;
  final List<Area> areas;

  const District({
    required this.cityId,
    required this.districtId,
    required this.name,
    required this.areas,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    // Parse areas from JSON string
    List<Area> parsedAreas = [];
    final areasString = json['areas'] as String?;
    
    if (areasString != null && areasString.isNotEmpty) {
      try {
        final areasJson = jsonDecode(areasString) as List<dynamic>;
        parsedAreas = areasJson
            .map((area) => Area.fromJson(area as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // If parsing fails, continue with empty areas list
        parsedAreas = [];
      }
    }

    return District(
      cityId: json['CityId'] as int,
      districtId: json['DistrictId'] as int,
      name: json['Name'] as String,
      areas: parsedAreas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'CityId': cityId,
      'DistrictId': districtId,
      'Name': name,
      'areas': jsonEncode(areas.map((area) => area.toJson()).toList()),
    };
  }

  @override
  String toString() {
    return 'District(cityId: $cityId, districtId: $districtId, name: $name, areas: ${areas.length} areas)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is District &&
        other.cityId == cityId &&
        other.districtId == districtId &&
        other.name == name &&
        other.areas.length == areas.length &&
        other.areas.every((area) => areas.contains(area));
  }

  @override
  int get hashCode {
    return Object.hash(cityId, districtId, name, Object.hashAll(areas));
  }
}