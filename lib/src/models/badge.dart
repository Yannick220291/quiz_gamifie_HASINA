class Badge {
  final int id;
  final String name;
  final String? description;
  final String? condition;
  final DateTime createdAt;
  final DateTime updatedAt;

  Badge({
    required this.id,
    required this.name,
    this.description,
    this.condition,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      condition: json['condition'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'condition': condition,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}