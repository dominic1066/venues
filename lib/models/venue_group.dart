class VenueGroup {
  final int id;
  final String name;

  const VenueGroup({
    required this.id,
    required this.name,
  });

  factory VenueGroup.fromJson(Map<String, dynamic> json) {
    return VenueGroup(
      id: (json['id'] ?? json['Id']) as int, // Handle both 'id' and 'Id'
      name: (json['name'] ?? json['Name']) as String, // Handle both 'name' and 'Name'
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'VenueGroup(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VenueGroup &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode {
    return Object.hash(id, name);
  }
}