import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:quiz_gamifie/src/config/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class UserService {
  static final _logger = Logger();
  final SupabaseClient supabase = Supabase.instance.client;
  final storage = const FlutterSecureStorage();

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await supabase
          .from('users')
          .select();
      _logger.i('Récupération de ${response.length} utilisateurs');
      return response;
    } catch (e) {
      _logger.e('Erreur lors de la récupération des utilisateurs: $e');
      throw Exception('Échec de la récupération des utilisateurs: $e');
    }
  }

  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final userData = await supabase
          .from('users')
          .select('''
          id, firstname, lastname, pseudo, email, avatar, country, bio, xp, league, 
          duel_wins, status, is_active, role, password_reset_token, password_reset_expires_at, 
          remember_token, created_at, updated_at,
          user_responses(id, user_id, question_id, answer_id, created_at, updated_at),
          histories(id, user_id, type, description, value, created_at, updated_at),
          user_badges(id, user_id, badge_id, earned_at)
        ''')
          .eq('id', userId)
          .single();

      final friendships = await supabase
          .from('friends')
          .select('''
            id, user_id, friend_id, status, created_at, updated_at,
            user:users!user_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at),
            friend:users!friend_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at)
          ''')
          .or('user_id.eq.$userId,friend_id.eq.$userId');

      userData['friends'] = friendships;

      return userData;
    } catch (e) {
      _logger.e('Erreur lors de la récupération de l\'utilisateur $userId: $e');
      throw Exception('Utilisateur non trouvé: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await supabase
          .from('users')
          .select('id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at')
          .order('xp', ascending: false);
      _logger.i('Classement récupéré: ${response.length} utilisateurs');
      return response;
    } catch (e) {
      _logger.e('Erreur lors de la récupération du classement: $e');
      throw Exception('Échec de la récupération du classement: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String firstname,
    String? lastname,
    required String pseudo,
    required String email,
    XFile? avatar,
    String? bio,
    String? country,
  }) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      if (firstname.isEmpty || pseudo.isEmpty || email.isEmpty) {
        throw Exception('Prénom, pseudo et email sont requis');
      }
      if (email.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Format d\'email invalide');
      }

      if (avatar != null) {
        String? mimeType;
        try {
          mimeType = avatar.mimeType ?? lookupMimeType(avatar.path);
        } catch (e) {
          _logger.e('Erreur lors de la détection du MIME type: $e');
        }

        const allowedFormats = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        if (mimeType == null || !allowedFormats.contains(mimeType)) {
          final extension = avatar.path.split('.').last.toLowerCase();
          const extensionToMime = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'gif': 'image/gif',
            'webp': 'image/webp',
          };
          mimeType = extensionToMime[extension];
          if (mimeType == null || !allowedFormats.contains(mimeType)) {
            throw Exception(
              'Format d\'image non pris en charge. Formats autorisés : JPEG, PNG, GIF, WEBP. '
                  'MIME type détecté : $mimeType, Extension : $extension',
            );
          }
        }
        _logger.i('MIME type détecté pour ${avatar.path}: $mimeType');
      }

      final pseudoCheck = await supabase.from('users').select('id').eq('pseudo', pseudo).neq('id', userId);
      if (pseudoCheck.isNotEmpty) throw Exception('Pseudo déjà pris');
      final emailCheck = await supabase.from('users').select('id').eq('email', email).neq('id', userId);
      if (emailCheck.isNotEmpty) throw Exception('Email déjà pris');

      String? avatarPath;
      if (avatar != null) {
        String? mimeType;
        try {
          mimeType = avatar.mimeType ?? lookupMimeType(avatar.path);
        } catch (e) {
          _logger.e('Erreur lors de la détection du MIME type: $e');
        }
        final currentUser = await supabase.from('users').select('avatar').eq('id', userId).single();
        if (currentUser['avatar'] != null) {
          await supabase.storage.from('profil').remove([currentUser['avatar']]);
          _logger.i('Ancien avatar supprimé: ${currentUser['avatar']}');
        }

        final file = File(avatar.path);
        final fileExtension = mimeType!.split('/').last; // mimeType est non null après validation
        final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        avatarPath = await supabase.storage.from('profil').upload('upload/profil/$fileName', file);
        _logger.i('Nouvel avatar téléchargé: $avatarPath');

        avatarPath = await supabase.storage.from('profil').createSignedUrl('upload/profil/$fileName', 60 * 60 * 24 * 365);
        _logger.i('URL signée générée: $avatarPath');
      }

      final updateData = {
        'firstname': firstname,
        'lastname': lastname,
        'pseudo': pseudo,
        'email': email,
        'bio': bio,
        'country': country,
        if (avatarPath != null) 'avatar': avatarPath,
      };

      final updatedUser = await supabase.from('users').update(updateData).eq('id', userId).select().single();
      _logger.i('Profil mis à jour pour l\'utilisateur: $userId');
      return updatedUser;
    } catch (e) {
      _logger.e('Erreur lors de la mise à jour du profil: $e');
      throw Exception('Échec de la mise à jour du profil: $e');
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final hashedPassword = AppConstants.hashPassword(newPassword);

      final currentUser = await supabase.from('users').select('password').eq('id', userId).single();
      if (!AppConstants.verifyPassword(currentPassword, currentUser['password'])) {
        throw Exception('Mot de passe actuel incorrect');
      }

      await supabase
          .from('users')
          .update({
        'password': hashedPassword,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', userId);
      _logger.i('Mot de passe mis à jour pour l\'utilisateur: $userId');
    } catch (e) {
      _logger.e('Erreur lors de la mise à jour du mot de passe: $e');
      throw Exception('Échec de la mise à jour du mot de passe: $e');
    }
  }

  Future<void> deleteProfile() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final currentUser = await supabase.from('users').select('avatar').eq('id', userId).single();
      if (currentUser['avatar'] != null) {
        await supabase.storage.from('profil').remove([currentUser['avatar']]);
        _logger.i('Avatar supprimé pour l\'utilisateur: $userId');
      }

      await supabase.from('users').delete().eq('id', userId);
      await storage.delete(key: 'token');
      _logger.i('Compte utilisateur supprimé: $userId');
    } catch (e) {
      _logger.e('Erreur lors de la suppression du profil: $e');
      throw Exception('Échec de la suppression du profil: $e');
    }
  }

  Future<Map<String, dynamic>> toggleProfileActive() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final currentUser = await supabase.from('users').select('is_active').eq('id', userId).single();
      final updatedUser = await supabase
          .from('users')
          .update({'is_active': !currentUser['is_active']})
          .eq('id', userId)
          .select()
          .single();
      _logger.i('Statut actif modifié pour l\'utilisateur: $userId');
      return updatedUser;
    } catch (e) {
      _logger.e('Erreur lors de la modification du statut actif: $e');
      throw Exception('Échec de la modification du statut actif: $e');
    }
  }

}