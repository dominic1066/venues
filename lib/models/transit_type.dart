class TransitType {
  final int id;
  final int transitType;
  final String description;

  const TransitType({
    required this.id,
    required this.transitType,
    required this.description,
  });

  factory TransitType.fromJson(Map<String, dynamic> json) {
    return TransitType(
      id: json['Id'] as int,
      transitType: json['TransitType'] as int,
      description: json['Description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'TransitType': transitType,
      'Description': description,
    };
  }

  @override
  String toString() {
    return 'TransitType(id: $id, transitType: $transitType, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransitType && other.id == id && other.transitType == transitType && other.description == description;
  }

  @override
  int get hashCode => Object.hash(id, transitType, description);
}