import 'package:supabase_flutter/supabase_flutter.dart';

class Friend {
  final int id;
  final String userId;
  final String friendId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? user;
  final User? friend;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.friend,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      userId: json['user_id'],
      friendId: json['friend_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: json['user'] != null ? User.fromJson(json['user'] as Map<String, dynamic>) : null,
      friend: json['friend'] != null ? User.fromJson(json['friend'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user': user?.toJson(),
      'friend': friend?.toJson(),
    };
  }
}