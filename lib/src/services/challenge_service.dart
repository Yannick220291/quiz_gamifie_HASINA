import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:quiz_gamifie/src/services/badge_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../config/constants.dart';
import '../services/user_service.dart';

class ChallengeService {
  static final _logger = Logger();
  final supabase = supa.Supabase.instance.client;
  final storage = const FlutterSecureStorage();
  final UserService _userService = UserService();
  final BadgeService _badgeService = BadgeService();

  Future<Map<String, dynamic>> invite(String opponentId, int bet) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final opponent = await _userService.getUserById(opponentId);
      if (opponent['status'] != 'online') {
        throw Exception('L’adversaire doit être en ligne pour recevoir un défi');
      }

      final user = await _userService.getUserById(userId);
      if (user['xp'] < bet) {
        throw Exception('Vous devez avoir au moins $bet XP pour créer un défi');
      }

      final maxBet = [user['xp'], opponent['xp']].reduce((a, b) => a < b ? a : b);
      if (bet > maxBet || bet < 25) {
        throw Exception('La mise doit être entre 25 et $maxBet XP');
      }

      final quizSelect = await supabase
          .from('quizzes')
          .select('id, questions(id)')
          .order('id', ascending: false)
          .limit(5);

      if (quizSelect.length < 5) {
        throw Exception('Pas assez de quizzes disponibles');
      }

      final questionIds = quizSelect
          .expand((quiz) => quiz['questions'] as List)
          .map((q) => q['id'])
          .toList();

      if (questionIds.isEmpty) {
        throw Exception('Pas de questions disponibles');
      }

      questionIds.shuffle();

      final challenge = await supabase.from('challenges').insert({
        'player1_id': userId,
        'player2_id': opponentId,
        'player1_bet': bet,
        'player2_bet': bet,
        'status': 'pending',
        'player1_score': 0,
        'player2_score': 0,
        'current_question_id': questionIds[0],
        'question_start_time': DateTime.now().toIso8601String(),
      }).select().single();

      await supabase.from('challenge_quizs').insert(
          quizSelect.map((quiz) => {'challenge_id': challenge['id'], 'quiz_id': quiz['id']}).toList());

      await supabase.from('challenge_questions').insert(
          questionIds.asMap().entries.map((entry) => {
            'challenge_id': challenge['id'],
            'question_id': entry.value,
            'orders': entry.key,
          }).toList());

      await supabase.from('histories').insert({
        'user_id': userId,
        'type': 'challenge',
        'description': 'Défi envoyé à #${opponent['pseudo']}',
        'value': bet,
      });

      _logger.i('Défi créé', error: {
        'challenge_id': challenge['id'],
        'player1_id': userId,
        'player2_id': opponentId,
        'current_question_id': questionIds[0],
      });

      return {
        'statusCode': 201,
        'data': challenge,
      };
    } catch (e) {
      _logger.e('Erreur lors de l\'invitation : $e');
      return {
        'error': 'Échec de l\'invitation : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> accept(String challengeId) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final challenge = await supabase
          .from('challenges')
          .select('*, player1:player1_id(*), player2:player2_id(*)')
          .eq('id', challengeId)
          .eq('player2_id', userId)
          .eq('status', 'pending')
          .single();

      final user = await _userService.getUserById(userId);
      if (user['xp'] < challenge['player2_bet']) {
        throw Exception('XP insuffisant pour accepter le défi');
      }

      final player1 = await _userService.getUserById(challenge['player1_id']);

      await supabase.from('users').update({
        'xp': player1['xp'] - challenge['player1_bet'],
      }).eq('id', player1['id']);

      await supabase.from('users').update({
        'xp': user['xp'] - challenge['player2_bet'],
      }).eq('id', user['id']);

      final updatedChallenge = await supabase.from('challenges').update({
        'status': 'active',
        'question_start_time': DateTime.now().toIso8601String(),
      }).eq('id', challengeId).select().single();

      await supabase.from('histories').insert([
        {
          'user_id': userId,
          'type': 'challenge',
          'description': 'Défi #${user['pseudo']} accepté',
          'value': -challenge['player2_bet'],
        },
        {
          'user_id': player1['id'],
          'type': 'xp',
          'description': 'Mise de ${challenge['player1_bet']} XP pour défi #${user['pseudo']}',
          'value': -challenge['player1_bet'],
        }
      ]);

      _logger.i('Défi accepté', error: {
        'challenge_id': challengeId,
        'player1_id': player1['id'],
        'player2_id': userId,
      });

      return {
        'statusCode': 200,
        'data': updatedChallenge,
      };
    } catch (e) {
      _logger.e('Erreur lors de l\'acceptation du défi : $e');
      return {
        'error': 'Échec de l\'acceptation : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> decline(String challengeId) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final challenge = await supabase
          .from('challenges')
          .select('*')
          .eq('id', challengeId)
          .eq('player2_id', userId)
          .eq('status', 'pending')
          .single();

      await supabase.from('challenges').delete().eq('id', challengeId);

      await supabase.from('histories').insert({
        'user_id': userId,
        'type': 'challenge',
        'description': 'Défi #$challengeId refusé',
        'value': 0,
      });

      _logger.i('Défi refusé', error: {'challenge_id': challengeId, 'user_id': userId});

      return {
        'statusCode': 200,
        'data': {'message': 'Défi refusé'},
      };
    } catch (e) {
      _logger.e('Erreur lors du refus du défi : $e');
      return {
        'error': 'Échec du refus : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> cancel(String challengeId) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final challenge = await supabase
          .from('challenges')
          .select('*')
          .eq('id', challengeId)
          .eq('player1_id', userId)
          .eq('status', 'pending')
          .single();

      await supabase.from('challenges').delete().eq('id', challengeId);

      await supabase.from('histories').insert({
        'user_id': userId,
        'type': 'challenge',
        'description': 'Défi #$challengeId annulé',
        'value': 0,
      });

      _logger.i('Défi annulé', error: {'challenge_id': challengeId, 'user_id': userId});

      return {
        'statusCode': 200,
        'data': {'message': 'Défi annulé'},
      };
    } catch (e) {
      _logger.e('Erreur lors de l\'annulation du défi : $e');
      return {
        'error': 'Échec de l\'annulation : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> lobby() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final pending = await supabase
          .from('challenges')
          .select('*, player1:player1_id(*), player2:player2_id(*), challenge_quizs(quiz_id)')
          .eq('player2_id', userId)
          .eq('status', 'pending');

      _logger.i('Lobby chargé', error: {
        'user_id': userId,
        'pending_challenges': pending.map((c) => c['id']).toList(),
      });

      return {
        'statusCode': 200,
        'data': {'pending': pending},
      };
    } catch (e) {
      _logger.e('Erreur lors du chargement du lobby : $e');
      return {
        'error': 'Échec du chargement du lobby : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> activeChallenges() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final active = await supabase
          .from('challenges')
          .select(
          '*, player1:player1_id(*), player2:player2_id(*), challenge_quizs(quiz_id), current_question:current_question_id(id, text, time_limit, answers(id, text, is_correct)), question_start_time')
          .eq('status', 'active')
          .or('player1_id.eq.$userId,player2_id.eq.$userId');

      _logger.i('Défis actifs récupérés', error: {
        'user_id': userId,
        'active_count': active.length,
        'challenge_ids': active.map((c) => c['id']).toList(),
      });

      return {
        'statusCode': 200,
        'data': {'active': active},
      };
    } catch (e) {
      _logger.e('Erreur lors de la récupération des défis actifs : $e');
      return {
        'error': 'Échec de la récupération des défis actifs : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> submitAnswer(String challengeId, int? questionId, int? answerId, String userId) async {
    try {
      final challenge = await supabase
          .from('challenges')
          .select('*, current_question:current_question_id(id), question_start_time')
          .eq('id', challengeId)
          .eq('status', 'active')
          .single();

      if (challenge['player1_id'] != userId && challenge['player2_id'] != userId) {
        throw Exception('Utilisateur non autorisé pour ce défi');
      }

      if (questionId != null && challenge['current_question']['id'] != questionId) {
        throw Exception('La question ne correspond pas à la question actuelle');
      }

      final existingAnswer = questionId != null
          ? await supabase
          .from('challenge_answers')
          .select('*')
          .eq('challenge_id', challengeId)
          .eq('question_id', questionId)
          .eq('user_id', userId)
          .maybeSingle()
          : null;

      if (existingAnswer != null) {
        _logger.i('Question déjà répondue', error: {
          'challenge_id': challengeId,
          'user_id': userId,
          'question_id': questionId,
        });
        return {
          'statusCode': 200,
          'data': challenge,
        };
      }

      bool isCorrect = false;
      if (answerId != null && questionId != null) {
        final answer = await supabase
            .from('answers')
            .select('*')
            .eq('id', answerId)
            .eq('question_id', questionId)
            .single();
        isCorrect = answer['is_correct'];
      }

      await supabase.from('challenge_answers').insert({
        'challenge_id': challengeId,
        'question_id': questionId,
        'user_id': userId,
        'answer_id': answerId,
        'is_correct': isCorrect,
        'timeout': answerId == null,
        'answered_at': DateTime.now().toIso8601String(),
      });

      final scoreField = userId == challenge['player1_id'] ? 'player1_score' : 'player2_score';
      if (isCorrect) {
        await supabase.from('challenges').update({
          scoreField: (challenge[scoreField] ?? 0) + 10,
        }).eq('id', challengeId);
      }

      final questions = await supabase
          .from('challenge_questions')
          .select('question_id')
          .eq('challenge_id', challengeId)
          .order('orders', ascending: true);

      final currentQuestionIndex = questionId != null ? questions.indexWhere((q) => q['question_id'] == questionId) : -1;
      final nextQuestionId = currentQuestionIndex + 1 < questions.length ? questions[currentQuestionIndex + 1]['question_id'] : null;

        if (nextQuestionId != null) {
          await supabase.from('challenges').update({
            'current_question_id': nextQuestionId,
            'question_start_time': DateTime.now().toIso8601String(),
          }).eq('id', challengeId);
        } else {
          await _finalizeChallenge(challengeId);
        }

      final updatedChallenge = await supabase
          .from('challenges')
          .select('*, current_question:current_question_id(id, text, time_limit, answers(id, text, is_correct)), question_start_time')
          .eq('id', challengeId)
          .single();

      _logger.i('Réponse soumise', error: {
        'challenge_id': challengeId,
        'user_id': userId,
        'question_id': questionId,
        'answer_id': answerId,
        'is_correct': isCorrect,
        'timeout': answerId == null,
      });

      return {
        'statusCode': 200,
        'data': updatedChallenge,
      };
    } catch (e) {
      _logger.e('Erreur lors de la soumission de la réponse : $e');
      return {
        'error': 'Échec de la soumission : $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> abandon(String challengeId) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final challenge = await supabase
          .from('challenges')
          .select('*')
          .eq('id', challengeId)
          .eq('status', 'active')
          .single();

      if (challenge['player1_id'] != userId && challenge['player2_id'] != userId) {
        throw Exception('Utilisateur non autorisé pour ce défi');
      }

      final winnerId = userId == challenge['player1_id'] ? challenge['player2_id'] : challenge['player1_id'];
      await _finalizeChallenge(challengeId, winnerId, true);

      _logger.i('Défi abandonné', error: {
        'challenge_id': challengeId,
        'user_id': userId,
      });

      return {
        'statusCode': 200,
        'data': {'message': 'Défi abandonné'},
      };
    } catch (e) {
      _logger.e('Erreur lors de l\'abandon du défi : $e');
      return {
        'error': 'Échec de l\'abandon : $e',
        'statusCode': 500,
      };
    }
  }

  Future<void> _finalizeChallenge(String challengeId, [String? winnerId, bool abandoned = false]) async {
    try {
      final challenge = await supabase.from('challenges').select('*').eq('id', challengeId).single();

      final effectiveWinnerId = winnerId ??
          (challenge['player1_score'] > challenge['player2_score']
              ? challenge['player1_id']
              : challenge['player2_id']);
      final loserId = effectiveWinnerId == challenge['player1_id'] ? challenge['player2_id'] : challenge['player1_id'];
      final totalXp = (challenge['player1_bet'] ?? 0) + (challenge['player2_bet'] ?? 0);

      final winner = await _userService.getUserById(effectiveWinnerId);
      final loser = await _userService.getUserById(loserId);

      final oldLeague = winner['league'];
      await supabase.from('users').update({
        'xp': winner['xp'] + totalXp,
        'duel_wins': winner['duel_wins'] + 1,
      }).eq('id', effectiveWinnerId);

      final updatedWinner = await _userService.getUserById(effectiveWinnerId);
      await _updateLeague(updatedWinner);
      await _badgeService.checkBadges(updatedWinner, totalXp);

      await supabase.from('challenges').update({
        'status': 'completed',
        'winner_id': effectiveWinnerId,
      }).eq('id', challengeId);

      await supabase.from('histories').insert([
        {
          'user_id': effectiveWinnerId,
          'type': 'challenge',
          'description': abandoned ? 'Défi #$challengeId gagné par abandon' : 'Défi #$challengeId gagné',
          'value': totalXp,
        },
        {
          'user_id': loserId,
          'type': 'challenge',
          'description': abandoned ? 'Défi #$challengeId abandonné' : 'Défi #$challengeId perdu',
          'value': 0,
        }
      ]);

      _logger.i('Défi finalisé', error: {
        'challenge_id': challengeId,
        'winner_id': effectiveWinnerId,
        'loser_id': loserId,
        'total_xp': totalXp,
        'abandoned': abandoned,
      });
    } catch (e) {
      _logger.e('Erreur lors de la finalisation du défi : $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getChallengeQuestions(String challengeId) async {
    try {
      final questions = await supabase
          .from('challenge_questions')
          .select('question:question_id(id, text, time_limit, answers(id, text, is_correct))')
          .eq('challenge_id', challengeId)
          .order('orders', ascending: true);

      return questions.map((q) {
        final answers = List<Map<String, dynamic>>.from(q['question']['answers']);
        answers.shuffle();
        return {
          'id': q['question']['id'],
          'text': q['question']['text'],
          'time_limit': q['question']['time_limit'] ?? 30,
          'answers': answers,
        };
      }).toList();
    } catch (e) {
      _logger.e('Erreur lors de la récupération des questions : $e');
      rethrow;
    }
  }



  Future<void> _updateLeague(Map<String, dynamic> user) async {
    for (var entry in AppConstants.leagues.entries) {
      if (user['xp'] >= entry.value['min_xp'] &&
          (entry.value['max_xp'] == null || user['xp'] <= entry.value['max_xp'])) {
        await supabase.from('users').update({
          'league': entry.key,
        }).eq('id', user['id']);
        break;
      }
    }
  }

}