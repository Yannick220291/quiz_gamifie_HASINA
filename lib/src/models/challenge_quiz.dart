class ChallengeQuiz {
  final String challengeId;
  final int quizId;

  ChallengeQuiz({
    required this.challengeId,
    required this.quizId,
  });

  factory ChallengeQuiz.fromJson(Map<String, dynamic> json) {
    return ChallengeQuiz(
      challengeId: json['challenge_id'],
      quizId: json['quiz_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      'quiz_id': quizId,
    };
  }
}