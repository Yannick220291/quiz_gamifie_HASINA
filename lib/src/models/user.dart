class User {
  final String id;
  final String firstname;
  final String? lastname;
  final String pseudo;
  final String email;
  final String? avatar;
  final String? country;
  final String? bio;
  final int xp;
  final String league;
  final int duelWins;
  final String status;
  final bool isActive;
  final String role;
  final String? passwordResetToken;
  final DateTime? passwordResetExpiresAt;
  final String? rememberToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.firstname,
    this.lastname,
    required this.pseudo,
    required this.email,
    this.avatar,
    this.country,
    this.bio,
    required this.xp,
    required this.league,
    required this.duelWins,
    required this.status,
    required this.isActive,
    required this.role,
    this.passwordResetToken,
    this.passwordResetExpiresAt,
    this.rememberToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) throw Exception('ID utilisateur manquant');
    if (json['firstname'] == null) throw Exception('Prénom manquant');
    if (json['pseudo'] == null) throw Exception('Pseudo manquant');
    if (json['email'] == null) throw Exception('Email manquant');
    if (json['league'] == null) throw Exception('Ligue manquante');
    if (json['status'] == null) throw Exception('Statut manquant');
    if (json['role'] == null) throw Exception('Rôle manquant');
    if (json['created_at'] == null) throw Exception('Date de création manquante');
    if (json['updated_at'] == null) throw Exception('Date de mise à jour manquante');

    return User(
      id: json['id'] as String,
      firstname: json['firstname'] as String,
      lastname: json['lastname'] as String? ?? '',
      pseudo: json['pseudo'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
      country: json['country'] as String?,
      bio: json['bio'] as String?,
      xp: json['xp'] as int? ?? 0,
      league: json['league'] as String,
      duelWins: json['duel_wins'] as int? ?? 0,
      status: json['status'] as String,
      isActive: json['is_active'] as bool? ?? true,
      role: json['role'] as String,
      passwordResetToken: json['password_reset_token'] as String?,
      passwordResetExpiresAt: json['password_reset_expires_at'] != null
          ? DateTime.parse(json['password_reset_expires_at'] as String)
          : null,
      rememberToken: json['remember_token'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstname': firstname,
      'lastname': lastname,
      'pseudo': pseudo,
      'email': email,
      'avatar': avatar,
      'country': country,
      'bio': bio,
      'xp': xp,
      'league': league,
      'duel_wins': duelWins,
      'status': status,
      'is_active': isActive,
      'role': role,
      'password_reset_token': passwordResetToken,
      'password_reset_expires_at': passwordResetExpiresAt?.toIso8601String(),
      'remember_token': rememberToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}