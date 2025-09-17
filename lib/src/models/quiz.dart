class Quiz {
  final int id;
  final String title;
  final int categoryId;
  final String? description;
  final String niveau;
  final DateTime createdAt;
  final DateTime updatedAt;

  Quiz({
    required this.id,
    required this.title,
    required this.categoryId,
    this.description,
    required this.niveau,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      title: json['title'],
      categoryId: json['category_id'],
      description: json['description'],
      niveau: json['niveau'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category_id': categoryId,
      'description': description,
      'niveau': niveau,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}