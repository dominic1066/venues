class TransitCity {
  final int id;
  final String name;
  final String staticLink;

  const TransitCity({
    required this.id,
    required this.name,
    required this.staticLink,
  });

  factory TransitCity.fromJson(Map<String, dynamic> json) {
    return TransitCity(
      id: json['Id'] as int,
      name: json['CityName'] as String,
      staticLink: json['GTFSStaticLink'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CityName': name,
      'GTFSStaticLink': staticLink,
    };
  }

  @override
  String toString() {
    return 'TransitCity(id: $id, name: $name, staticLink: $staticLink)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransitCity && other.id == id && other.name == name && other.staticLink == staticLink;
  }

  @override
  int get hashCode => Object.hash(id, name, staticLink);
}