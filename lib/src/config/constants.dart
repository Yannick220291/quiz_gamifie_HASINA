import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';

class AppConstants {
  static final _logger = Logger();
  static const String appName = 'Quiz App';
  static const int otpCodeLength = 6;
  static const int passwordMinLength = 8;
  static const Map<String, Map<String, int?>> leagues = {
    'Bronze': {'min_xp': 0, 'max_xp': 1500},
    'Argent': {'min_xp': 1501, 'max_xp': 3000},
    'Or': {'min_xp': 3001, 'max_xp': 4500},
    'Platine': {'min_xp': 4501, 'max_xp': 6000},
    'Diamant': {'min_xp': 6001, 'max_xp': 7500},
    'Champion': {'min_xp': 7501, 'max_xp': 9000},
    'Maître Champion': {'min_xp': 9001, 'max_xp': null},
  };


  static Map<String, dynamic> getLeagueStyles(String league) {
    switch (league) {
      case 'Bronze':
        return {'border': Colors.amber[700], 'text': Colors.amber[700]};
      case 'Argent':
        return {'border': Colors.grey[400], 'text': Colors.grey[500]};
      case 'Or':
        return {'border': Colors.yellow[500], 'text': Colors.yellow[600]};
      case 'Platine':
        return {'border': Colors.cyan[500], 'text': Colors.cyan[600]};
      case 'Diamant':
        return {'border': Colors.purple[500], 'text': Colors.purple[600]};
      case 'Champion':
        return {'border': Colors.red[500], 'text': Colors.red[600]};
      case 'Maître Champion':
        return {'border': Colors.blue[500], 'text': Colors.blue[600]};
      default:
        return {'border': Colors.grey[500], 'text': Colors.grey[600]};
    }
  }
  static String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool verifyPassword(String password, String hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }

  static String generateJwtToken(String userId, String role) {
    final payload = {
      'sub': userId,
      'role': role,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
    };

    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final encodedHeader = base64Url.encode(utf8.encode(jsonEncode(header)));
    final encodedPayload = base64Url.encode(utf8.encode(jsonEncode(payload)));

    final secret = dotenv.env['JWT_SECRET'] ?? '';
    if (secret.isEmpty) {
      throw Exception('Clé JWT manquante');
    }

    final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode('$encodedHeader.$encodedPayload'));
    final encodedSignature = base64Url.encode(signature.bytes).replaceAll('=', '');

    return '$encodedHeader.$encodedPayload.$encodedSignature';
  }

  static bool isValidJwtToken(String token) {
    try {
      final isExpired = JwtDecoder.isExpired(token);
      if (isExpired) {
        _logger.w('Token JWT expiré');
        return false;
      }

      final decodedToken = JwtDecoder.decode(token);
      final secret = dotenv.env['JWT_SECRET'] ?? '';
      if (secret.isEmpty) {
        throw Exception('Clé JWT manquante');
      }

      final parts = token.split('.');
      if (parts.length != 3) {
        return false;
      }
      final signature = Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode('${parts[0]}.${parts[1]}'));
      final encodedSignature = base64Url.encode(signature.bytes).replaceAll('=', '');

      return encodedSignature == parts[2];
    } catch (e) {
      _logger.e('Erreur lors de la validation du token JWT : $e');
      return false;
    }
  }

}