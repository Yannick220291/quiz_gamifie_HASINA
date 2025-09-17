import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  final _storage = const FlutterSecureStorage();
  static final _logger = Logger();
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTokenAndNavigate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    final token = await _storage.read(key: 'token');

    if (token != null && _isValidJwtToken(token)) {
      final userId = JwtDecoder.decode(token)['sub'] as String?;

      if (userId != null && userId.isNotEmpty) {
        if (state == AppLifecycleState.resumed) {
          await _updateUserStatus(userId, 'online');
        } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
          await _updateUserStatus(userId, 'offline');
        }
      }
    }
  }

  Future<void> _updateUserStatus(String userId, String status) async {
    try {
      await _supabase
          .from('users')
          .update({
        'status': status,
      })
          .eq('id', userId);
      _logger.i('Statut de l\'utilisateur mis à jour : $status');
    } catch (e) {
      _logger.e('Erreur lors de la mise à jour du statut : $e');
    }
  }

  Future<void> _checkTokenAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!await _hasInternetConnection()) {
      _showErrorDialog('Pas de connexion Internet. Veuillez vérifier votre connexion et réessayer.');
      return;
    }

    try {
      final token = await _storage.read(key: 'token');

      if (token == null || !_isValidJwtToken(token)) {
        _navigateToLogin();
        return;
      }

      final decodedToken = JwtDecoder.decode(token);
      final userId = decodedToken['sub'] as String?;

      if (userId != null && userId.isNotEmpty) {
        await _updateUserStatus(userId, 'online');
        _navigateToHome();
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('Erreur lors de la vérification du token: $e');
      _navigateToLogin();
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      await _supabase.from('users').select().limit(1);
      return true;
    } catch (e) {
      _logger.e('Erreur de connexion à Supabase : $e');
      return false;
    }
  }

  bool _isValidJwtToken(String token) {
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

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quitter', style: TextStyle(color: Color(0xFF7A5AF8))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkTokenAndNavigate();
            },
            child: const Text('Réessayer', style: TextStyle(color: Color(0xFF7A5AF8))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, size: 50, color: Colors.red);
              },
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B48FF)),
            ),
          ],
        ),
      ),
    );
  }
}