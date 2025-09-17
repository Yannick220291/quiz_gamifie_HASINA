import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:quiz_gamifie/src/services/auth_service.dart';
import 'package:quiz_gamifie/src/services/challenge_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:logger/logger.dart';
import '../models/user.dart';

class DuelScreen extends StatefulWidget {
  final String challengeId;

  const DuelScreen({super.key, required this.challengeId});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  final ChallengeService _challengeService = ChallengeService();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger();
  Map<String, dynamic>? _challenge;
  User? _player1;
  User? _player2;
  Map<String, dynamic>? _currentQuestion;
  List<Map<String, dynamic>> _questions = [];
  int _remainingTime = 0;
  Timer? _timer;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _currentUserId;
  bool _isQuizCompleted = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  supa.RealtimeChannel? _realtimeChannel;
  int _currentQuestionIndex = 0;
  int _totalQuestions = 0;
  bool _hasAnswered = false;
  bool _opponentAnswered = false;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing DuelScreen for challenge ID: ${widget.challengeId}');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _initializeData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _logger.i('Disposing DuelScreen for challenge ID: ${widget.challengeId}');
    _timer?.cancel();
    _animationController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeData() async {
    _logger.i('Starting initialization for challenge ID: ${widget.challengeId}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserFuture = _authService.getCurrentUser();
      final questionsFuture = _challengeService.getChallengeQuestions(widget.challengeId);
      final challengeResponseFuture = _challengeService.activeChallenges();

      final results = await Future.wait([currentUserFuture, questionsFuture, challengeResponseFuture]);

      final currentUser = results[0] as Map<String, dynamic>?;
      if (currentUser == null || !currentUser.containsKey('id')) {
        throw Exception('No user logged in or invalid user data');
      }
      _currentUserId = currentUser['id'] as String;

      _questions = results[1] as List<Map<String, dynamic>>;
      _totalQuestions = _questions.length;

      final response = results[2] as Map<String, dynamic>;
      if (response['statusCode'] != 200) {
        throw Exception(response['error'] ?? 'Error fetching challenge');
      }

      final challenge = (response['data']['active'] as List<dynamic>).firstWhere(
            (c) => c['id'] == widget.challengeId,
        orElse: () => <String, dynamic>{},
      );

      if (challenge.isEmpty) {
        throw Exception('Challenge not found');
      }

      _player1 = User.fromJson(challenge['player1']);
      _player2 = challenge['player2'] != null ? User.fromJson(challenge['player2']) : null;
      _currentQuestion = challenge['current_question'];
      _isQuizCompleted = challenge['status'] == 'completed';

      final currentQuestionId = challenge['current_question_id'];
      _currentQuestionIndex = _questions.isNotEmpty
          ? _questions.indexWhere((q) => q['id'] == currentQuestionId) + 1
          : 0;

      if (_currentUserId != null && _currentQuestion != null) {
        final existingAnswer = await supa.Supabase.instance.client
            .from('challenge_answers')
            .select('answer_id, user_id')
            .eq('challenge_id', widget.challengeId)
            .eq('question_id', _currentQuestion!['id'])
            .maybeSingle();
        _hasAnswered = existingAnswer != null && existingAnswer['user_id'] == _currentUserId;
        _opponentAnswered = existingAnswer != null && existingAnswer['user_id'] != _currentUserId;
      }

      if (mounted) {
        setState(() {
          _challenge = challenge;
          _isLoading = false;
          _logger.i('Initialization completed: questions=$_totalQuestions, completed=$_isQuizCompleted');
        });
      }

      if (_currentQuestion != null && challenge['question_start_time'] != null && !_isQuizCompleted) {
        _startTimer(_currentQuestion!['time_limit'] ?? 30, challenge['question_start_time']);
      }
    } catch (e) {
      _logger.e('Initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtime() {
    _logger.i('Setting up real-time subscriptions for challenge ID: ${widget.challengeId}');
    _realtimeChannel = supa.Supabase.instance.client.channel('challenges')
      ..onPostgresChanges(
        event: supa.PostgresChangeEvent.update,
        schema: 'public',
        table: 'challenges',
        filter: supa.PostgresChangeFilter(
          type: supa.PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.challengeId,
        ),
        callback: (payload) async {
          _logger.i('Challenge update received: $payload');
          await _fetchChallenge();
        },
      )
      ..onPostgresChanges(
        event: supa.PostgresChangeEvent.delete,
        schema: 'public',
        table: 'challenges',
        filter: supa.PostgresChangeFilter(
          type: supa.PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.challengeId,
        ),
        callback: (payload) {
          _logger.i('Challenge deleted: $payload');
          if (mounted) {
            setState(() {
              _isQuizCompleted = true;
            });
            _showResultDialog(false, abandoned: true);
          }
        },
      )
      ..onPostgresChanges(
        event: supa.PostgresChangeEvent.insert,
        schema: 'public',
        table: 'challenge_answers',
        filter: supa.PostgresChangeFilter(
          type: supa.PostgresChangeFilterType.eq,
          column: 'challenge_id',
          value: widget.challengeId,
        ),
        callback: (payload) async {
          _logger.i('New answer received: $payload');
          if (mounted && payload.newRecord['user_id'] != _currentUserId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Adversaire a répondu, nouvelle question à venir...'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
            await Future.delayed(const Duration(seconds: 2));
          }
          await _fetchChallenge();
        },
      )
      ..subscribe((status, [error]) {
        _logger.i('Real-time subscription status: $status, error: $error');
      });
  }

  Future<void> _fetchChallenge() async {
    if (!mounted) return;

    _logger.i('Fetching challenge data for ID: ${widget.challengeId}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasAnswered = false;
      _opponentAnswered = false;
    });

    try {
      final response = await _challengeService.activeChallenges();
      if (response['statusCode'] != 200) {
        throw Exception(response['error'] ?? 'Error fetching challenge');
      }

      final challenge = (response['data']['active'] as List<dynamic>).firstWhere(
            (c) => c['id'] == widget.challengeId,
        orElse: () => <String, dynamic>{},
      );

      if (challenge.isEmpty) {
        throw Exception('Challenge not found');
      }

      _currentQuestionIndex = _questions.isNotEmpty
          ? _questions.indexWhere((q) => q['id'] == challenge['current_question_id']) + 1
          : 0;

      if (_currentUserId != null && challenge['current_question'] != null) {
        final existingAnswer = await supa.Supabase.instance.client
            .from('challenge_answers')
            .select('answer_id, user_id')
            .eq('challenge_id', widget.challengeId)
            .eq('question_id', challenge['current_question']['id'])
            .maybeSingle();
        _hasAnswered = existingAnswer != null && existingAnswer['user_id'] == _currentUserId;
        _opponentAnswered = existingAnswer != null && existingAnswer['user_id'] != _currentUserId;
      }

      if (mounted) {
        setState(() {
          _challenge = challenge;
          _player1 = User.fromJson(challenge['player1']);
          _player2 = challenge['player2'] != null ? User.fromJson(challenge['player2']) : null;
          _currentQuestion = challenge['current_question'];
          _isQuizCompleted = challenge['status'] == 'completed';
          _isLoading = false;
        });
      }

      if (_isQuizCompleted && mounted) {
        _showResultDialog(challenge['winner_id'] == _currentUserId);
      } else if (_currentQuestion != null && challenge['question_start_time'] != null) {
        _startTimer(_currentQuestion!['time_limit'] ?? 30, challenge['question_start_time']);
      } else {
        _timer?.cancel();
      }
    } catch (e) {
      _logger.e('Error fetching challenge: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startTimer(int timeLimit, String questionStartTime) {
    _logger.i('Starting timer: timeLimit=$timeLimit, startTime=$questionStartTime');
    _timer?.cancel();
    if (_isQuizCompleted) return;

    final startTime = DateTime.parse(questionStartTime);
    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    _remainingTime = timeLimit - elapsedSeconds;

    if (_remainingTime <= 0) {
      _remainingTime = 0;
      if (!_hasAnswered && !_opponentAnswered && _currentUserId != null && _currentQuestion != null) {
        _handleAnswer(null);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _remainingTime = _remainingTime;
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          timer.cancel();
          if (!_hasAnswered && !_opponentAnswered && _currentUserId != null && _currentQuestion != null) {
            _handleAnswer(null);
          }
        }
      });
    });
  }

  Future<void> _handleAnswer(int? answerId) async {
    if (_challenge == null || _currentQuestion == null || _currentUserId == null || _hasAnswered || _opponentAnswered || _isSubmitting) {
      _logger.w('Cannot handle answer: invalid state');
      return;
    }

    _logger.i('Submitting answer: answerId=$answerId, userId=$_currentUserId');
    setState(() {
      _isSubmitting = true;
    });

    try {
      HapticFeedback.lightImpact();
      _timer?.cancel();

      final response = await _challengeService.submitAnswer(
        widget.challengeId,
        _currentQuestion!['id'],
        answerId,
        _currentUserId!,
      );

      if (response['statusCode'] == 200) {
        if (mounted) {
          setState(() {
            _hasAnswered = true;
            _challenge = response['data'];
            _currentQuestion = response['data']['current_question'];
            _isQuizCompleted = response['data']['status'] == 'completed';
            _isSubmitting = false;
          });
        }

        if (_isQuizCompleted && mounted) {
          _showResultDialog(response['data']['winner_id'] == _currentUserId);
        } else if (_currentQuestion != null) {
          final existingAnswer = await supa.Supabase.instance.client
              .from('challenge_answers')
              .select('answer_id, user_id')
              .eq('challenge_id', widget.challengeId)
              .eq('question_id', _currentQuestion!['id'])
              .maybeSingle();
          if (mounted) {
            setState(() {
              _hasAnswered = existingAnswer != null && existingAnswer['user_id'] == _currentUserId;
              _opponentAnswered = existingAnswer != null && existingAnswer['user_id'] != _currentUserId;
            });
          }
        }
      } else {
        throw Exception(response['error'] ?? 'Submission error');
      }
    } catch (e) {
      _logger.e('Error submitting answer: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Erreur lors de la soumission : $e';
        });
      }
    }
  }

  void _showResultDialog(bool isWinner, {bool abandoned = false}) {
    if (!mounted) return;
    _logger.i('Showing result dialog: isWinner=$isWinner, abandoned=$abandoned');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassmorphicContainer(
          width: MediaQuery.of(context).size.width * 0.8,
          height: 300,
          borderRadius: 20,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            colors: [
              Color(0xFF4A4A6A).withOpacity(0.2),
              Color(0xFF4A4A6A).withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderGradient: const LinearGradient(colors: [Colors.white24, Colors.white10]),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                abandoned
                    ? 'Adversaire a abandonné !'
                    : isWinner
                    ? 'Victoire !'
                    : 'Défaite',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Votre score: ${_challenge!['player1_score'] ?? 0} XP',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              Text(
                'Score adversaire: ${_challenge!['player2_score'] ?? 0} XP',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A5AF8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Retour au menu',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAbandon() async {
    if (_isSubmitting) return;

    _logger.i('Abandoning challenge: ${widget.challengeId}');
    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _challengeService.abandon(widget.challengeId);
      if (response['statusCode'] == 200 && mounted) {
        setState(() {
          _isQuizCompleted = true;
          _isSubmitting = false;
        });
        _showResultDialog(false);
      } else {
        throw Exception(response['error'] ?? 'Abandon error');
      }
    } catch (e) {
      _logger.e('Error abandoning challenge: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Erreur lors de l\'abandon : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building UI: isLoading=$_isLoading, isQuizCompleted=$_isQuizCompleted');
    return WillPopScope(
      onWillPop: () async => _isQuizCompleted,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0x801A1A2E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8)))
                : _errorMessage != null
                ? Center(
              child: GlassmorphicContainer(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 200,
                borderRadius: 20,
                blur: 20,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [
                    Color(0xFF4A4A6A).withOpacity(0.2),
                    Color(0xFF4A4A6A).withOpacity(0.3),
                  ],
                ),
                borderGradient: const LinearGradient(colors: [Colors.white24, Colors.white10]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A5AF8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
                : _challenge == null || _challenge!.isEmpty
                ? Center(
              child: GlassmorphicContainer(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 200,
                borderRadius: 20,
                blur: 20,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [
                    Color(0xFF4A4A6A).withOpacity(0.2),
                    Color(0xFF4A4A6A).withOpacity(0.3),
                  ],
                ),
                borderGradient: const LinearGradient(colors: [Colors.white24, Colors.white10]),
                child: const Text(
                  'Défi non trouvé ou terminé',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              _player1?.pseudo ?? 'Joueur 1',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Score: ${_challenge!['player1_score'] ?? 0} XP',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                        _TimerWidget(
                          remainingTime: _remainingTime,
                          timeLimit: _currentQuestion?['time_limit'] ?? 30,
                        ),
                        Column(
                          children: [
                            Text(
                              _player2?.pseudo ?? 'En attente',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Score: ${_challenge!['player2_score'] ?? 0} XP',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_currentQuestion != null && !_isQuizCompleted) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Question $_currentQuestionIndex/$_totalQuestions',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_opponentAnswered)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Adversaire a répondu en premier ! Nouvelle question bientôt...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.yellow,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentQuestion!['text'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16.0),
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _currentQuestion!['answers']?.length ?? 0,
                                itemBuilder: (context, index) {
                                  final answer = _currentQuestion!['answers'][index];
                                  final isCorrect = answer['is_correct'];

                                  return FutureBuilder<Map<String, dynamic>?>(
                                    future: _hasAnswered || _opponentAnswered
                                        ? supa.Supabase.instance.client
                                        .from('challenge_answers')
                                        .select('answer_id, user_id')
                                        .eq('challenge_id', widget.challengeId)
                                        .eq('question_id', _currentQuestion!['id'])
                                        .maybeSingle()
                                        : Future.value(null),
                                    builder: (context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
                                      final answerData = snapshot.data;
                                      final isSelected = answerData != null && answerData['answer_id'] == answer['id'];
                                      final answeredByCurrentUser = answerData != null && answerData['user_id'] == _currentUserId;

                                      return Semantics(
                                        button: true,
                                        enabled: !_hasAnswered && !_opponentAnswered,
                                        label: _hasAnswered || _opponentAnswered
                                            ? (isCorrect ? 'Option correcte' : 'Option incorrecte')
                                            : 'Option ${index + 1}: ${answer['text']}',
                                        child: GestureDetector(
                                          onTap: _hasAnswered || _opponentAnswered ? null : () => _handleAnswer(answer['id']),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color: _hasAnswered || _opponentAnswered
                                                  ? (isCorrect
                                                  ? const Color(0xFF4CAF50)
                                                  : (isSelected
                                                  ? const Color(0xFFF44336)
                                                  : Colors.white))
                                                  : Colors.white,
                                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                                              border: Border.all(
                                                color: _hasAnswered || _opponentAnswered
                                                    ? (isCorrect
                                                    ? const Color(0xFF4CAF50)
                                                    : (isSelected
                                                    ? const Color(0xFFF44336)
                                                    : const Color(0xFF888888).withOpacity(0.5)))
                                                    : const Color(0xFF888888).withOpacity(0.5),
                                                width: 1,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 10,
                                                  offset: Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    answer['text'],
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                      color: (_hasAnswered || _opponentAnswered) && (isSelected || isCorrect)
                                                          ? Colors.white
                                                          : const Color(0xFF1A1A2E),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                if (_hasAnswered || _opponentAnswered)
                                                  Icon(
                                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                if (_opponentAnswered && !answeredByCurrentUser)
                                                  Text(
                                                    'Adversaire a répondu',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_challenge!['status'] == 'active')
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleAbandon,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Abandonner',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerWidget extends StatelessWidget {
  final int remainingTime;
  final int timeLimit;

  const _TimerWidget({required this.remainingTime, required this.timeLimit});

  @override
  Widget build(BuildContext context) {
    final color = remainingTime <= 5 ? Colors.red : const Color(0xFF7A5AF8);
    return GlassmorphicContainer(
      width: 80,
      height: 80,
      borderRadius: 40,
      blur: 15,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        colors: [Color(0xFF4A4A6A).withOpacity(0.1), Color(0xFF4A4A6A).withOpacity(0.2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: const LinearGradient(colors: [Colors.white30, Colors.white10]),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: remainingTime / timeLimit,
            backgroundColor: const Color(0xFF888888).withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 6,
          ),
          Text(
            "${remainingTime}s",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: remainingTime <= 5 ? Colors.red : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}