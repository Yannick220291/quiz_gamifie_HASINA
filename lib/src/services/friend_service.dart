
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../config/constants.dart';
import '../models/friend.dart';
import '../models/user.dart';

class FriendService {
  static final _logger = Logger();
  final supa.SupabaseClient supabase = supa.Supabase.instance.client;
  final storage = const FlutterSecureStorage();
  String? _currentUserId;

  String get currentUserId {
    if (_currentUserId == null) {
      _logger.e('User ID not initialized');
      throw Exception('User ID not initialized. Please authenticate.');
    }
    return _currentUserId!;
  }

  Future<bool> _initializeUserId() async {
    try {
      final token = await storage.read(key: 'token');
      _logger.i('Token lu depuis le stockage sécurisé : $token');
      if (token == null || token.isEmpty) {
        _logger.e('Aucun token trouvé ou token vide');
        throw Exception('No token found');
      }
      if (!AppConstants.isValidJwtToken(token)) {
        _logger.e('Token JWT invalide');
        throw Exception('Invalid JWT token');
      }
      final decodedToken = JwtDecoder.decode(token);
      _logger.i('Token décodé : $decodedToken');
      _currentUserId = decodedToken['sub'] as String?;
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        _logger.e('ID utilisateur non trouvé ou vide dans le token');
        throw Exception('User ID not found in token');
      }
      _logger.i('User ID initialisé avec succès : $_currentUserId');
      return true;
    } catch (e) {
      _logger.e('Erreur lors de l\'initialisation de l\'ID utilisateur : $e');
      _currentUserId = null;
      return false;
    }
  }

  Future<Map<String, dynamic>> _executeWithAuth(Future<Map<String, dynamic>> Function() action) async {
    if (!await _initializeUserId() || _currentUserId == null) {
      _logger.e('Échec de l\'initialisation de l\'ID utilisateur');
      return {
        'error': 'User not authenticated',
        'statusCode': 401,
      };
    }
    try {
      return await action();
    } catch (e, stackTrace) {
      _logger.e('Erreur lors de l\'exécution de l\'action : $e', error: e, stackTrace: stackTrace);
      return {
        'error': 'Operation failed: $e',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> request(String friendId) async {
    return _executeWithAuth(() async {
      if (friendId == currentUserId) {
        _logger.w('Tentative d\'envoi d\'une demande d\'ami à soi-même');
        return {
          'error': 'Cannot send friend request to yourself',
          'statusCode': 400,
        };
      }

      final friendExists = await supabase
          .from('users')
          .select('id')
          .eq('id', friendId)
          .maybeSingle();
      if (friendExists == null) {
        _logger.w('Utilisateur avec l\'ID $friendId non trouvé');
        return {
          'error': 'User not found',
          'statusCode': 404,
        };
      }

      final existingRequest = await supabase
          .from('friends')
          .select()
          .eq('user_id', currentUserId)
          .eq('friend_id', friendId)
          .maybeSingle();
      if (existingRequest != null) {
        _logger.w('Demande d\'ami existante pour user_id: $currentUserId, friend_id: $friendId');
        return {
          'error': 'Friend request already exists',
          'statusCode': 400,
        };
      }

      final response = await supabase
          .from('friends')
          .insert({
        'user_id': currentUserId,
        'friend_id': friendId,
        'status': 'pending',
      })
          .select('''
            id, user_id, friend_id, status, created_at, updated_at,
            user:users!user_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at),
            friend:users!friend_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at)
          ''')
          .single();

      try {
        final friendship = Friend.fromJson({
          ...response,
          'user': response['user'],
          'friend': response['friend'],
        });
        _logger.i('Demande d\'ami créée avec succès : ${friendship.toJson()}');
        return {
          'data': friendship.toJson(),
          'statusCode': 201,
        };
      } catch (e) {
        _logger.e('Erreur lors de la création de l\'objet Friend : $e');
        return {
          'error': 'Failed to parse friend data: $e',
          'statusCode': 500,
        };
      }
    });
  }

  Future<Map<String, dynamic>> accept(String friendId) async {
    return _executeWithAuth(() async {
      final friendship = await supabase
          .from('friends')
          .select('''
            id, user_id, friend_id, status, created_at, updated_at,
            user:users!user_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at),
            friend:users!friend_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at)
          ''')
          .eq('friend_id', currentUserId)
          .eq('user_id', friendId)
          .eq('status', 'pending')
          .maybeSingle();

      if (friendship == null) {
        _logger.w('Demande d\'ami non trouvée pour user_id: $friendId, friend_id: $currentUserId');
        return {
          'error': 'Friend request not found',
          'statusCode': 404,
        };
      }

      try {
        final updatedFriendship = await supabase
            .from('friends')
            .update({'status': 'accepted'})
            .eq('id', friendship['id'])
            .select('''
              id, user_id, friend_id, status, created_at, updated_at,
              user:users!user_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at),
              friend:users!friend_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at)
            ''')
            .single();

        final loadedFriendship = Friend.fromJson({
          ...updatedFriendship,
          'user': updatedFriendship['user'],
          'friend': updatedFriendship['friend'],
        });
        _logger.i('Demande d\'ami acceptée : ${loadedFriendship.toJson()}');
        return {
          'data': loadedFriendship.toJson(),
          'statusCode': 200,
        };
      } catch (e) {
        _logger.e('Erreur lors de l\'acceptation de la demande d\'ami : $e');
        return {
          'error': 'Failed to accept friend request: $e',
          'statusCode': 500,
        };
      }
    });
  }

  Future<Map<String, dynamic>> reject(String friendId) async {
    return _executeWithAuth(() async {
      final friendship = await supabase
          .from('friends')
          .select()
          .eq('friend_id', currentUserId)
          .eq('user_id', friendId)
          .eq('status', 'pending')
          .maybeSingle();

      if (friendship == null) {
        _logger.w('Demande d\'ami non trouvée pour user_id: $friendId, friend_id: $currentUserId');
        return {
          'error': 'Friend request not found',
          'statusCode': 404,
        };
      }

      try {
        await supabase.from('friends').delete().eq('id', friendship['id']);
        _logger.i('Demande d\'ami rejetée pour user_id: $friendId, friend_id: $currentUserId');
        return {
          'data': {'message': 'Friend request rejected'},
          'statusCode': 200,
        };
      } catch (e) {
        _logger.e('Erreur lors du rejet de la demande d\'ami : $e');
        return {
          'error': 'Failed to reject friend request: $e',
          'statusCode': 500,
        };
      }
    });
  }

  Future<Map<String, dynamic>> cancel(String friendId) async {
    return _executeWithAuth(() async {
      final friendship = await supabase
          .from('friends')
          .select()
          .eq('user_id', currentUserId)
          .eq('friend_id', friendId)
          .eq('status', 'pending')
          .maybeSingle();

      if (friendship == null) {
        _logger.w('Demande d\'ami non trouvée pour user_id: $currentUserId, friend_id: $friendId');
        return {
          'error': 'Friend request not found',
          'statusCode': 404,
        };
      }

      try {
        await supabase.from('friends').delete().eq('id', friendship['id']);
        _logger.i('Demande d\'ami annulée pour user_id: $currentUserId, friend_id: $friendId');
        return {
          'data': {'message': 'Friend request cancelled'},
          'statusCode': 200,
        };
      } catch (e) {
        _logger.e('Erreur lors de l\'annulation de la demande d\'ami : $e');
        return {
          'error': 'Failed to cancel friend request: $e',
          'statusCode': 500,
        };
      }
    });
  }

  Future<Map<String, dynamic>> remove(String friendId) async {
    return _executeWithAuth(() async {
      final friendship = await supabase
          .from('friends')
          .select()
          .eq('status', 'accepted')
          .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId')
          .or('user_id.eq.$friendId,friend_id.eq.$friendId')
          .maybeSingle();

      if (friendship == null) {
        _logger.w('Amitié non trouvée pour user_id ou friend_id: $currentUserId, $friendId');
        return {
          'error': 'Friendship not found',
          'statusCode': 404,
        };
      }

      try {
        await supabase.from('friends').delete().eq('id', friendship['id']);
        _logger.i('Ami supprimé pour user_id ou friend_id: $currentUserId, $friendId');
        return {
          'data': {'message': 'Friend removed'},
          'statusCode': 200,
        };
      } catch (e) {
        _logger.e('Erreur lors de la suppression de l\'ami : $e');
        return {
          'error': 'Failed to remove friend: $e',
          'statusCode': 500,
        };
      }
    });
  }

  Future<Map<String, dynamic>> getFriends() async {
    return _executeWithAuth(() async {
      try {
        final friendships = await supabase
            .from('friends')
            .select('''
            id, user_id, friend_id, status, created_at, updated_at,
            user:users!user_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role,created_at , updated_at),
            friend:users!friend_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at)
          ''')
            .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId');

        _logger.i('Données brutes des amitiés : $friendships');
        final mappedFriendships = (friendships as List<dynamic>)
            .map((f) {
          final userData = f['user'] as Map<String, dynamic>?;
          final friendData = f['friend'] as Map<String, dynamic>?;
          _logger.i('userData : $userData');
          _logger.i('friendData : $friendData');

          if (userData == null || friendData == null) {
            _logger.w('Données utilisateur ou ami manquantes pour l\'amitié : $f');
            return null;
          }

          for (var data in [userData, friendData]) {
            if (data['id'] == null) {
              _logger.w('Champ id manquant pour l\'amitié : $f');
              return null;
            }
            if (data['firstname'] == null) {
              _logger.w('Champ firstname manquant pour l\'amitié : $f');
              return null;
            }
            if (data['pseudo'] == null) {
              _logger.w('Champ pseudo manquant pour l\'amitié : $f');
              return null;
            }
            if (data['email'] == null) {
              _logger.w('Champ email manquant pour l\'amitié : $f');
              return null;
            }
            if (data['league'] == null) {
              _logger.w('Champ league manquant pour l\'amitié : $f');
              return null;
            }
            if (data['status'] == null) {
              _logger.w('Champ status manquant pour l\'amitié : $f');
              return null;
            }
            if (data['role'] == null) {
              _logger.w('Champ role manquant pour l\'amitié : $f');
              return null;
            }
            if (data['created_at'] == null) {
              _logger.w('Champ created_at manquant pour l\'amitié : $f');
              return null;
            }
            if (data['updated_at'] == null) {
              _logger.w('Champ updated_at manquant pour l\'amitié : $f');
              return null;
            }
          }

          try {
            return Friend.fromJson({
              ...f as Map<String, dynamic>,
              'user': userData,
              'friend': friendData,
            }).toJson();
          } catch (e) {
            _logger.e('Erreur lors de la conversion de l\'amitié : $e');
            return null;
          }
        })
            .where((f) => f != null)
            .cast<Map<String, dynamic>>()
            .toList();

        _logger.i('Amis récupérés : ${mappedFriendships.length} amitiés');
        return {
          'data': mappedFriendships,
          'statusCode': 200,
        };
      } catch (e) {
        _logger.e('Erreur lors de la récupération des amis : $e');
        return {
          'error': 'Failed to fetch friends: $e',
          'statusCode': 500,
        };
      }
    });
  }
}