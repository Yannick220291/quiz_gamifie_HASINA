class Challenge {
  final String id;
  final String player1Id;
  final String player2Id;
  final String status;
  final int? player1Score;
  final int? player2Score;
  final int player1Bet;
  final int player2Bet;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Challenge({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.status,
    this.player1Score,
    this.player2Score,
    required this.player1Bet,
    required this.player2Bet,
    this.winnerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'],
      player1Id: json['player1_id'],
      player2Id: json['player2_id'],
      status: json['status'],
      player1Score: json['player1_score'],
      player2Score: json['player2_score'],
      player1Bet: json['player1_bet'],
      player2Bet: json['player2_bet'],
      winnerId: json['winner_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player1_id': player1Id,
      'player2_id': player2Id,
      'status': status,
      'player1_score': player1Score,
      'player2_score': player2Score,
      'player1_bet': player1Bet,
      'player2_bet': player2Bet,
      'winner_id': winnerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}