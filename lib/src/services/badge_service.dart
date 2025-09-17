import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BadgeService {
  static final _logger = Logger();
  final SupabaseClient supabase = Supabase.instance.client;
  final storage = const FlutterSecureStorage();

  Future<void> checkBadges(Map<String, dynamic> user, int score) async {
    if (user['id'] == null) {
      _logger.e('Erreur : Aucun ID utilisateur fourni');
      return;
    }

    try {
      final badgesResponse = await supabase.from('badges').select();
      final userBadgesResponse = await supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', user['id']);

      final allBadges = badgesResponse as List<dynamic>;
      final userBadgeIds = (userBadgesResponse as List<dynamic>).map((b) => b['badge_id'] as int).toSet();

      final updatedUser = Map<String, dynamic>.from(user)..['xp'] = (user['xp'] ?? 0) + score;

      final badgeInserts = <Map<String, dynamic>>[];
      final historyInserts = <Map<String, dynamic>>[];

      for (var badge in allBadges) {
        if (userBadgeIds.contains(badge['id'])) {
          _logger.i('Badge ${badge['name']} déjà attribué à l\'utilisateur ${user['id']}');
          continue;
        }

        if (evaluateBadgeCondition(badge['condition'], updatedUser)) {
          badgeInserts.add({
            'user_id': user['id'],
            'badge_id': badge['id'],
            'earned_at': DateTime.now().toIso8601String(),
          });
          historyInserts.add({
            'user_id': user['id'],
            'type': 'badge',
            'description': 'Badge ${badge['name']} obtenu',
            'value': 0,
          });
          _logger.i('Badge ${badge['name']} attribué à l\'utilisateur ${user['id']}');
        }
      }

      if (badgeInserts.isNotEmpty) {
        await supabase.from('user_badges').insert(badgeInserts);
        await supabase.from('histories').insert(historyInserts);
      }
    } catch (e) {
      _logger.e('Erreur lors de la vérification des badges pour l\'utilisateur ${user['id']} : $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllBadges() async {
    try {
      final response = await supabase.from('badges').select();
      _logger.i('Récupération de ${response.length} badges');
      return response;
    } catch (e) {
      _logger.e('Erreur lors de la récupération des badges : $e');
      throw Exception('Échec de la récupération des badges : $e');
    }
  }

  bool evaluateBadgeCondition(String condition, Map<String, dynamic> user) {
    try {
      final singleConditionRegExp = RegExp(r"\(user\['(\w+)'\]\s*\?\?\s*([^)]+)\)\s*([><=]+)\s*(\d+|'[^']+')");
      final combinedConditionRegExp = RegExp(r"\(user\['(\w+)'\]\s*\?\?\s*([^)]+)\)\s*([><=]+)\s*(\d+|'[^']+')\s*&&\s*\(user\['(\w+)'\]\s*\?\?\s*([^)]+)\)\s*([><=]+)\s*(\d+|'[^']+')");

      final combinedMatch = combinedConditionRegExp.firstMatch(condition);
      if (combinedMatch != null) {
        final key1 = combinedMatch.group(1)!;
        final default1 = combinedMatch.group(2)!;
        final operator1 = combinedMatch.group(3)!;
        final threshold1 = combinedMatch.group(4)!;
        final key2 = combinedMatch.group(5)!;
        final default2 = combinedMatch.group(6)!;
        final operator2 = combinedMatch.group(7)!;
        final threshold2 = combinedMatch.group(8)!;

        bool firstConditionMet = _evaluateSingleCondition(key1, default1, operator1, threshold1, user);
        bool secondConditionMet = _evaluateSingleCondition(key2, default2, operator2, threshold2, user);
        return firstConditionMet && secondConditionMet;
      }

      final singleMatch = singleConditionRegExp.firstMatch(condition);
      if (singleMatch != null) {
        final key = singleMatch.group(1)!;
        final defaultValue = singleMatch.group(2)!;
        final operator = singleMatch.group(3)!;
        final threshold = singleMatch.group(4)!;
        return _evaluateSingleCondition(key, defaultValue, operator, threshold, user);
      }

      _logger.w('Condition non reconnue : $condition');
      return false;
    } catch (e) {
      _logger.e('Erreur lors de l\'évaluation de la condition : $condition, erreur : $e');
      return false;
    }
  }

  bool _evaluateSingleCondition(String key, String defaultValue, String operator, String threshold, Map<String, dynamic> user) {
    dynamic userValue;
    dynamic thresholdValue;

    if (threshold.startsWith("'") && threshold.endsWith("'")) {
      userValue = user[key] as String? ?? defaultValue.replaceAll("'", "");
      thresholdValue = threshold.replaceAll("'", "");
    } else {
      userValue = user[key] as num? ?? num.parse(defaultValue);
      thresholdValue = num.parse(threshold);
    }

    switch (operator) {
      case '>=':
        return userValue >= thresholdValue;
      case '<=':
        return userValue <= thresholdValue;
      case '==':
        return userValue == thresholdValue;
      case '>':
        return userValue > thresholdValue;
      case '<':
        return userValue < thresholdValue;
      default:
        _logger.w('Opérateur non supporté : $operator');
        return false;
    }
  }
}