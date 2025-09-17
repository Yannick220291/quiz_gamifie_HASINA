import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quiz_gamifie/src/config/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:logger/logger.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class AuthService {
  static const _otpLength = 6;
  static const _otpExpirationMinutes = 5;
  static const _resetTokenExpirationMinutes = 15;
  static const _maxNameLength = 255;
  static final _logger = Logger();

  final supabase = supa.Supabase.instance.client;
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register({
    required String email,
    required String firstname,
    required String pseudo,
    required String password,
    String? lastname,
    String? country,
  }) async {
    try {
      if (firstname.isEmpty || firstname.length > _maxNameLength) {
        throw Exception('Le prénom est requis et doit contenir moins de $_maxNameLength caractères');
      }
      if (pseudo.isEmpty || pseudo.length > _maxNameLength) {
        throw Exception('Le pseudo est requis et doit contenir moins de $_maxNameLength caractères');
      }
      if (!_isValidEmail(email)) {
        throw Exception('Format d\'email invalide');
      }
      if (!_isValidPassword(password)) {
        throw Exception('Le mot de passe doit contenir au moins 8 caractères avec une majuscule, une minuscule, un chiffre et un caractère spécial');
      }

      final existingUser = await supabase
          .from('users')
          .select('pseudo, email')
          .or('pseudo.eq.$pseudo,email.eq.$email')
          .maybeSingle();

      if (existingUser != null) {
        throw Exception('Pseudo ou email déjà utilisé');
      }

      await supabase.from('verification_codes').delete().eq('email', email);

      final verificationCode = _generateOtp();

      await _sendEmail(
        email: email,
        subject: 'Vérification de l\'email',
        content: _buildVerificationEmailContent(verificationCode),
      );

      await supabase.from('verification_codes').insert({
        'email': email,
        'code': verificationCode,
        'expires_at': DateTime.now().add(const Duration(minutes: _otpExpirationMinutes)).toIso8601String(),
      });

      return {'message': 'Code de vérification envoyé à votre email'};
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
    required String firstname,
    required String pseudo,
    required String password,
    String? lastname,
    String? country,
  }) async {
    try {
      if (!_isValidOtp(code)) {
        throw Exception('Le code doit être un nombre à 6 chiffres');
      }
      if (!_isValidEmail(email)) {
        throw Exception('Format d\'email invalide');
      }

      final verification = await supabase
          .from('verification_codes')
          .select()
          .eq('email', email)
          .eq('code', code)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (verification == null) {
        throw Exception('Code invalide ou expiré. Veuillez réessayer.');
      }

      final hashedPassword = AppConstants.hashPassword(password);

      final userResponse = await supabase.from('users').insert({
        'firstname': firstname,
        'lastname': lastname ?? '',
        'pseudo': pseudo,
        'email': email,
        'password': hashedPassword,
        'country': country ?? '',
        'role': 'USER',
        'is_active': true,
        'mdp': password ?? '',
        'status': 'online',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final token = AppConstants.generateJwtToken(userResponse['id'], 'USER');

      await supabase.from('verification_codes').delete().eq('email', email);

      await storage.write(key: 'token', value: token);

      return {
        'token': token,
        'user_id': userResponse['id'],
        'role': 'USER',
      };
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (!_isValidEmail(email)) {
        throw Exception('Format d\'email invalide');
      }
      if (password.isEmpty) {
        throw Exception('Le mot de passe est requis');
      }

      final userData = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .single();

      if (!AppConstants.verifyPassword(password, userData['password'])) {
        throw Exception('Mot de passe incorrect');
      }

      final token = AppConstants.generateJwtToken(userData['id'], userData['role']);

      await supabase
          .from('users')
          .update({'status': 'online', 'updated_at': DateTime.now().toIso8601String()})
          .eq('email', email);

      await storage.write(key: 'token', value: token);

      return {
        'token': token,
        'user_id': userData['id'],
        'role': userData['role'],
      };
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<void> logout() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      if (userId != null) {
        await supabase
            .from('users')
            .update({'status': 'offline', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
      }

      await storage.delete(key: 'token');
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || !AppConstants.isValidJwtToken(token)) {
        throw Exception('Token invalide ou absent');
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'];

      final userData = await supa.Supabase.instance.client
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

      final friendships = await supa.Supabase.instance.client
          .from('friends')
          .select('''
            id, user_id, friend_id, status, created_at, updated_at,
            user:users!user_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at),
            friend:users!friend_id(id, pseudo, avatar, firstname, lastname, status, email, league, xp, duel_wins, is_active, role, created_at, updated_at)
          ''')
          .or('user_id.eq.$userId,friend_id.eq.$userId');

      userData['friends'] = friendships;

      return userData;
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      if (!_isValidEmail(email)) {
        throw Exception('Format d\'email invalide');
      }

      final user = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (user == null) {
        throw Exception('Email non trouvé');
      }

      final token = _generateOtp();
      final expiresAt = DateTime.now().add(const Duration(minutes: _resetTokenExpirationMinutes));

      await supabase
          .from('users')
          .update({
        'password_reset_token': token,
        'password_reset_expires_at': expiresAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', user['id']);

      await _sendEmail(
        email: email,
        subject: 'Demande de réinitialisation de mot de passe',
        content: _buildResetEmailContent(token),
      );

      return {'message': 'Lien de réinitialisation de mot de passe envoyé à votre email'};
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<Map<String, dynamic>> resetPassword({
    required String code,
    required String password,
    required String email,
  }) async {
    try {
      if (!_isValidPassword(password)) {
        throw Exception('Le mot de passe doit contenir au moins 8 caractères avec une majuscule, une minuscule, un chiffre et un caractère spécial');
      }
      if (!_isValidEmail(email)) {
        throw Exception('Format d\'email invalide');
      }

      final user = await supabase
          .from('users')
          .select()
          .eq('password_reset_token', code)
          .eq('email', email)
          .gt('password_reset_expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (user == null) {
        throw Exception('Token invalide ou expiré');
      }

      final hashedPassword = AppConstants.hashPassword(password);

      await supabase
          .from('users')
          .update({
        'password': hashedPassword,
        'password_reset_token': null,
        'password_reset_expires_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('email', email);

      return {'message': 'Mot de passe réinitialisé avec succès'};
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  Future<Map<String, dynamic>> verifyResetCode({
    required String code,
    required String email,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        throw Exception('Format d\'email invalide');
      }

      final user = await supabase
          .from('users')
          .select()
          .eq('password_reset_token', code)
          .eq('email', email)
          .gt('password_reset_expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (user == null) {
        throw Exception('Token invalide ou expiré');
      }

      return {'message': 'Mot de passe réinitialisé avec succès'};
    } on supa.AuthException catch (e) {
      _logger.e('Erreur d\'authentification Supabase : ${e.message}');
      throw Exception('Erreur d\'authentification : ${e.message}');
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

  void listenToUserStatus(String userId, Function(User) onStatusChanged) {
    final subscription = supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        final user = User.fromJson(data.first);
        onStatusChanged(user);
      }
    }, onError: (error) {
      _logger.e('Erreur de flux : $error');
    });
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  bool _isValidOtp(String otp) => RegExp(r'^\d{6}$').hasMatch(otp);

  bool _isValidPassword(String password) =>
      RegExp(r'^.{8,}$').hasMatch(password);

  String _generateOtp() => Random().nextInt(999999).toString().padLeft(_otpLength, '0');

  Future<void> _sendEmail({
    required String email,
    required String subject,
    required String content,
  }) async {
    try {
      final smtpHost = dotenv.env['MAIL_HOST'] ?? '';
      final smtpPort = int.tryParse(dotenv.env['MAIL_PORT'] ?? '587') ?? 587;
      final smtpUsername = dotenv.env['MAIL_USERNAME'] ?? '';
      final smtpPassword = dotenv.env['MAIL_PASSWORD'] ?? '';

      if (smtpHost.isEmpty || smtpUsername.isEmpty || smtpPassword.isEmpty) {
        _logger.e('Erreur : Variables d\'environnement SMTP manquantes');
        throw Exception('Configuration SMTP invalide : variables manquantes');
      }

      _logger.i('Configuration SMTP : host=$smtpHost, port=$smtpPort, username=$smtpUsername');

      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: smtpUsername,
        password: smtpPassword,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(smtpUsername)
        ..recipients.add(email)
        ..subject = subject
        ..html = content;

      final sendReport = await send(message, smtpServer);
      _logger.i('Email envoyé avec succès à $email : $sendReport');
    } catch (e) {
      _logger.e('Erreur lors de l\'envoi de l\'email : $e');
      throw Exception('Échec de l\'envoi de l\'email : $e');
    }
  }

  String _buildVerificationEmailContent(String code) => '''
    <div style='font-family: Arial, sans-serif; padding: 20px; background: #f9f9f9;'>
      <h2 style='color: #1a73e8;'>Vérification de compte</h2>
      <p>Merci de vous être inscrit ! Voici votre code de vérification :</p>
      <h3 style='background: #e8f0fe; padding: 10px; display: inline-block; border-radius: 5px; color: #1a73e8;'>$code</h3>
      <p>Ce code expirera dans <strong>$_otpExpirationMinutes minutes</strong>.</p>
      <p>Si vous n'avez pas initié cette demande, veuillez ignorer cet email.</p>
    </div>
  ''';

  String _buildResetEmailContent(String token) => '''
    <div style='font-family: Arial, sans-serif; padding: 20px; background: #f9f9f9;'>
      <h2 style='color: #1a73e8;'>Réinitialisation de mot de passe</h2>
      <p>Vous avez demandé une réinitialisation de mot de passe. Utilisez ce code pour continuer :</p>
      <h3 style='background: #e8f0fe; padding: 10px; display: inline-block; border-radius: 5px; color: #1a73e8;'>$token</h3>
      <p>Ce code expirera dans <strong>$_resetTokenExpirationMinutes minutes</strong>.</p>
      <p>Si vous n'avez pas initié cette demande, veuillez ignorer cet email.</p>
    </div>
  ''';
}