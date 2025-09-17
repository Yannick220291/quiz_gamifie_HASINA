class VerificationCode {
  final int id;
  final String email;
  final String code;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  VerificationCode({
    required this.id,
    required this.email,
    required this.code,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VerificationCode.fromJson(Map<String, dynamic> json) {
    return VerificationCode(
      id: json['id'],
      email: json['email'],
      code: json['code'],
      expiresAt: DateTime.parse(json['expires_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'code': code,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}