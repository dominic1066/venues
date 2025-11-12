class City {
  final String city;

  const City({
    required this.city,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      city: (json['city'] ?? json['City']) as String, // Handle both 'city' and 'City'
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
    };
  }

  @override
  String toString() {
    return 'City(city: $city)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is City && other.city == city;
  }

  @override
  int get hashCode {
    return city.hashCode;
  }
}