import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:quiz_gamifie/src/models/category.dart';
import 'package:quiz_gamifie/src/models/quiz.dart';
import 'package:quiz_gamifie/src/models/question.dart';
import 'package:quiz_gamifie/src/models/answer.dart';
import 'package:quiz_gamifie/src/services/badge_service.dart';
import 'package:quiz_gamifie/src/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../config/constants.dart';

class QuizService {
  static final _logger = Logger();
  final supabase = supa.Supabase.instance.client;
  final storage = const FlutterSecureStorage();
  final UserService _userService = UserService();
  final BadgeService _badgeService = BadgeService();

  Future<List<Quiz>> getAllQuizzes({required int categoryId}) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      if (userId == null) {
        throw Exception('Utilisateur non authentifié.');
      }

      final quizResponse = await supabase
          .from('quizzes')
          .select('''
            *, 
            questions:questions(id, quiz_id)
          ''')
          .eq('category_id', categoryId);

      final quizzes = <Quiz>[];
      final questionIds = <int>[];

      for (var json in quizResponse) {
        final quiz = Quiz.fromJson(json);
        final questions = (json['questions'] as List<dynamic>?)?.map((q) => q['id'] as int).toList() ?? [];
        if (questions.isEmpty) {
          quizzes.add(quiz);
        } else {
          questionIds.addAll(questions);
          quizzes.add(quiz);
        }
      }

      final userResponses = questionIds.isEmpty
          ? []
          : await supabase
          .from('user_responses')
          .select('id, user_id, question_id')
          .eq('user_id', userId)
          .inFilter('question_id', questionIds);

      final unfinishedQuizzes = <Quiz>[];
      for (var quiz in quizzes) {
        final questions = (quizResponse.firstWhere((q) => q['id'] == quiz.id)['questions'] as List<dynamic>?) ?? [];
        final questionCount = questions.length;
        final responseCount = userResponses.where((r) => questions.any((q) => q['id'] == r['question_id'])).length;

        if (questionCount == 0 || responseCount < questionCount) {
          unfinishedQuizzes.add(quiz);
        }
      }

      return unfinishedQuizzes;
    } on supa.PostgrestException catch (e) {
      _logger.e('Erreur de base de données Supabase : ${e.message}');
      throw Exception('Erreur de base de données : ${e.message}');
    } catch (e) {
      _logger.e('Erreur inattendue : $e');
      rethrow;
    }
  }

  Future<List<Question>> getQuestionsForQuiz(int quizId) async {
    try {
      final response = await supabase.from('questions').select('*').eq('quiz_id', quizId);

      final questions = (response as List<dynamic>).map((json) => Question.fromJson(json)).toList();

      return questions;
    } on supa.PostgrestException catch (e) {
      _logger.e('Erreur de base de données Supabase : ${e.message}');
      throw Exception('Erreur de base de données : ${e.message}');
    } catch (e) {
      _logger.e('Erreur inattendue : $e');
      rethrow;
    }
  }

  Future<Map<int, List<Answer>>> getAnswersForQuiz(int quizId) async {
    try {
      final questionIds = await supabase
          .from('questions')
          .select('id')
          .eq('quiz_id', quizId)
          .then((response) => (response as List<dynamic>).map((q) => q['id']).toList());

      if (questionIds.isEmpty) {
        return {};
      }

      final response = await supabase.from('answers').select('*, question_id').inFilter('question_id', questionIds);

      final answersByQuestion = <int, List<Answer>>{};
      for (var json in response) {
        final questionId = json['question_id'] as int;
        answersByQuestion.putIfAbsent(questionId, () => []).add(Answer.fromJson(json));
      }
      return answersByQuestion;
    } on supa.PostgrestException catch (e) {
      _logger.e('Erreur de base de données Supabase : ${e.message}');
      throw Exception('Erreur de base de données : ${e.message}');
    } catch (e) {
      _logger.e('Erreur inattendue : $e');
      rethrow;
    }
  }

  Future<List<Answer>> getAnswersForQuestion(int questionId) async {
    try {
      final response = await supabase.from('answers').select('*').eq('question_id', questionId);

      final answers = (response as List<dynamic>).map((json) => Answer.fromJson(json)).toList();

      return answers;
    } on supa.PostgrestException catch (e) {
      _logger.e('Erreur de base de données Supabase : ${e.message}');
      throw Exception('Erreur de base de données : ${e.message}');
    } catch (e) {
      _logger.e('Erreur inattendue : $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitQuiz(int quizId, List<Map<String, dynamic>> responses, String quizLevel) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      if (userId == null) {
        throw Exception('Utilisateur non authentifié.');
      }

      int score = _calculateScore(responses, quizLevel);

      final responseData = responses.map((r) => {
        'user_id': userId,
        'question_id': r['question_id'],
        'answer_id': r['answer_id'],
      }).toList();
      await supabase.from('user_responses').insert(responseData);

      final userResponse = await supabase.from('users').select('xp').eq('id', userId).single();
      final currentXp = userResponse['xp'] ?? 0;
      await supabase.from('users').update({'xp': currentXp + score}).eq('id', userId);

      final user = await _userService.getUserById(userId);
      await Future.wait([
        _updateLeague(user, score),
        _badgeService.checkBadges(user, score),
      ]);

      return {'score': score, 'xp': currentXp + score};
    } on supa.PostgrestException catch (e) {
      _logger.e('Erreur de base de données Supabase : ${e.message}');
      throw Exception('Erreur de base de données : ${e.message}');
    } on http.ClientException catch (e) {
      _logger.e('Erreur réseau : ${e.message}');
      throw Exception('Erreur réseau. Vérifiez votre connexion internet.');
    } catch (e) {
      _logger.e('Erreur inattendue : $e');
      rethrow;
    }
  }

  int _calculateScore(List<Map<String, dynamic>> responses, String quizLevel) {
    final points = switch (quizLevel.toLowerCase()) {
      'facile' => 10,
      'moyen' => 20,
      'difficile' => 30,
      _ => 10,
    };
    return responses.where((r) => r['is_correct'] == true).length * points;
  }

  Future<void> _updateLeague(Map<String, dynamic> user, int score) async {
    final newXp = (user['xp'] ?? 0) + score;
    for (var entry in AppConstants.leagues.entries) {
      if (newXp >= entry.value['min_xp'] && (entry.value['max_xp'] == null || newXp <= entry.value['max_xp'])) {
        await supabase.from('users').update({'league': entry.key}).eq('id', user['id']);
        break;
      }
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final response = await supabase.from('categories').select('*');
      return (response as List<dynamic>).map((c) => Category.fromJson(c)).toList();
    } catch (e) {
      _logger.e('Erreur lors de la récupération des catégories : $e');
      rethrow;
    }
  }
}