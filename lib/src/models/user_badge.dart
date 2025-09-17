class UserBadge {
  final int id;
  final String userId;
  final int badgeId;
  final DateTime earnedAt;

  UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.earnedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'],
      userId: json['user_id'],
      badgeId: json['badge_id'],
      earnedAt: DateTime.parse(json['earned_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'badge_id': badgeId,
      'earned_at': earnedAt.toIso8601String(),
    };
  }
}