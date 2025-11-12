class VenueGrouping {
  final String id;
  final String name;
  final List<String> venueIds;

  VenueGrouping({
    required this.id,
    required this.name,
    required this.venueIds,
  });

  VenueGrouping copyWith({
    String? id,
    String? name,
    List<String>? venueIds,
  }) {
    return VenueGrouping(
      id: id ?? this.id,
      name: name ?? this.name,
      venueIds: venueIds ?? this.venueIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'venueIds': venueIds,
    };
  }

  factory VenueGrouping.fromJson(Map<String, dynamic> json) {
    return VenueGrouping(
      id: json['id'] as String,
      name: json['name'] as String,
      venueIds: List<String>.from(json['venueIds'] as List),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VenueGrouping &&
        other.id == id &&
        other.name == name &&
        other.venueIds.length == venueIds.length &&
        other.venueIds.every((element) => venueIds.contains(element));
  }

  @override
  int get hashCode => Object.hash(id, name, venueIds);

  @override
  String toString() {
    return 'VenueGrouping(id: $id, name: $name, venueIds: $venueIds)';
  }
}