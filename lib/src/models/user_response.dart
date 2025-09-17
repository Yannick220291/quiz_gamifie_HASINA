class UserResponse {
  final int id;
  final String userId;
  final int questionId;
  final int answerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserResponse({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.answerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'],
      userId: json['user_id'],
      questionId: json['question_id'],
      answerId: json['answer_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'answer_id': answerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}