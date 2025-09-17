class Question {
  final int id;
  final int quizId;
  final String text;
  final int? timeLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.quizId,
    required this.text,
    this.timeLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      quizId: json['quiz_id'],
      text: json['text'],
      timeLimit: json['time_limit'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'text': text,
      'time_limit': timeLimit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}