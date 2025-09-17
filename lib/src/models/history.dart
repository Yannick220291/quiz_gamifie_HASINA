class History {
  final int id;
  final String userId;
  final String type;
  final String description;
  final int? value;
  final DateTime createdAt;
  final DateTime updatedAt;

  History({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  factory History.fromJson(Map<String, dynamic> json) {
    return History(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      description: json['description'],
      value: json['value'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'description': description,
      'value': value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}