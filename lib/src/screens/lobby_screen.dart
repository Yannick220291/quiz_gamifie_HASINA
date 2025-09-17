import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_gamifie/src/services/challenge_service.dart';
import 'package:quiz_gamifie/src/services/friend_service.dart';
import 'package:quiz_gamifie/src/services/user_service.dart';
import 'package:quiz_gamifie/src/screens/profile_other_user_screen.dart';
import 'package:quiz_gamifie/src/screens/duel_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/user.dart';
import '../models/friend.dart';
import 'dart:async';

enum LoadingState { loading, success, error }

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();
  final ChallengeService _challengeService = ChallengeService();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  List<Friend> _friends = [];
  List<Map<String, dynamic>> _pendingChallenges = [];
  List<Map<String, dynamic>> _activeChallenges = [];
  LoadingState _loadingState = LoadingState.loading;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _pendingChallengeId;
  bool _isNavigating = false;
  Timer? _debounce;
  supa.RealtimeChannel? _realtimeChallengeChannel;
  supa.RealtimeChannel? _realtimeFriendChannel;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _searchController.addListener(_filterUsers);
    _fetchData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    _animationController.dispose();
    _debounce?.cancel();
    _realtimeChallengeChannel?.unsubscribe();
    _realtimeFriendChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChallengeChannel = supa.Supabase.instance.client.channel('challenges')
      ..onPostgresChanges(
        event: supa.PostgresChangeEvent.all,
        schema: 'public',
        table: 'challenges',
        callback: (payload) {
          if (!mounted) return;
          final challenge = payload.newRecord ?? payload.oldRecord;
          if (challenge['id'] == _pendingChallengeId) {
            if (payload.eventType == supa.PostgresChangeEvent.update) {
              if (challenge['status'] == 'active' && !_isNavigating) {
                setState(() {
                  _isNavigating = true;
                });
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DuelScreen(challengeId: challenge['id']),
                  ),
                );
              } else if (challenge['status'] == 'canceled' || challenge['status'] == 'completed') {
                setState(() {
                  _pendingChallengeId = null;
                });
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Le défi a été refusé ou annulé'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            } else if (payload.eventType == supa.PostgresChangeEvent.delete) {
              setState(() {
                _pendingChallengeId = null;
              });
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Le défi a été supprimé'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          }
          _fetchData();
        },
      )
      ..subscribe();

    _realtimeFriendChannel = supa.Supabase.instance.client.channel('friends')
      ..onPostgresChanges(
        event: supa.PostgresChangeEvent.all,
        schema: 'public',
        table: 'friends',
        callback: (payload) {
          if (!mounted) return;
          final friendData = payload.newRecord ?? payload.oldRecord;
          if (friendData['user_id'] == _friendService.currentUserId ||
              friendData['friend_id'] == _friendService.currentUserId) {
            if (payload.eventType == supa.PostgresChangeEvent.insert) {
              final newFriend = Friend.fromJson(friendData);
              setState(() {
                if (newFriend.status == 'accepted') {
                  _friends.add(newFriend);
                }
              });
            } else if (payload.eventType == supa.PostgresChangeEvent.update) {
              setState(() {
                _friends.removeWhere((f) => f.id == friendData['id']);
                final updatedFriend = Friend.fromJson(friendData);
                if (updatedFriend.status == 'accepted') {
                  _friends.add(updatedFriend);
                }
              });
            } else if (payload.eventType == supa.PostgresChangeEvent.delete) {
              setState(() {
                _friends.removeWhere((f) => f.id == friendData['id']);
              });
            }
          }
        },
      )
      ..subscribe();
  }

  void _filterUsers() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredUsers = _allUsers
            .where((user) =>
        user.pseudo.toLowerCase().contains(query) ||
            user.firstname.toLowerCase().contains(query) ||
            (user.lastname != null && user.lastname!.toLowerCase().contains(query)))
            .toList();
      });
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _loadingState = LoadingState.loading;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getAllUsers();
      final friendsResponse = await _friendService.getFriends();
      final challengesResponse = await _challengeService.lobby();

      if (!mounted) return;
      setState(() {
        _allUsers = users.map((user) => User.fromJson(user)).toList();
        _filteredUsers = _allUsers;
        if (friendsResponse['statusCode'] == 200) {
          final friendships = (friendsResponse['data'] as List).map((f) => Friend.fromJson(f)).toList();
          _friends = friendships.where((f) => f.status == 'accepted').toList();
        }
        if (challengesResponse['statusCode'] == 200) {
          _pendingChallenges = List<Map<String, dynamic>>.from(challengesResponse['data']['pending']);
          _activeChallenges = List<Map<String, dynamic>>.from(challengesResponse['data']['active'] ?? []);
          if (_pendingChallenges.isNotEmpty && _pendingChallengeId == null && !Navigator.of(context).canPop()) {
            _showChallengeDialog(_pendingChallenges.first);
          }
        }
        _loadingState = LoadingState.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingState = LoadingState.error;
        _errorMessage = e.toString();
      });
    }
  }

  bool _hasPendingOrActiveChallenge(String userId) {
    return _pendingChallenges.any((challenge) =>
    challenge['player1']['id'] == userId || challenge['player2']['id'] == userId) ||
        _activeChallenges.any((challenge) =>
        challenge['player1']['id'] == userId || challenge['player2']['id'] == userId);
  }

  String _getChallengeStatus(String userId) {
    if (_pendingChallenges.any((challenge) =>
    challenge['player1']['id'] == userId || challenge['player2']['id'] == userId)) {
      return 'pending';
    } else if (_activeChallenges.any((challenge) =>
    challenge['player1']['id'] == userId || challenge['player2']['id'] == userId)) {
      return 'active';
    }
    return 'none';
  }

  void _showInviteDialog(BuildContext context, String userId, String userName, int maxBet) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white.withOpacity(0.95),
          title: Text(
            'Inviter $userName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          content: TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Mise (25 à $maxBet XP)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.numbers, color: Color(0xFF7A5AF8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_pendingChallengeId != null) {
                  _challengeService.cancel(_pendingChallengeId!);
                  if (mounted) {
                    setState(() {
                      _pendingChallengeId = null;
                    });
                  }
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final bet = int.tryParse(_numberController.text);
                if (bet != null && bet >= 25 && bet <= maxBet) {
                  final response = await _challengeService.invite(userId, bet);
                  if (response['statusCode'] == 201 && mounted) {
                    setState(() {
                      _pendingChallengeId = response['data']['id'];
                    });
                    _numberController.clear();
                    Navigator.of(context).pop();
                    _showWaitingDialog(context, userName, _pendingChallengeId!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invitation envoyée à $userName avec la mise $bet XP'),
                        backgroundColor: const Color(0xFF7A5AF8),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  } else {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['error'] ?? 'Erreur lors de l\'invitation'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Veuillez entrer une mise valide'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A5AF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Envoyer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showWaitingDialog(BuildContext context, String userName, String challengeId) {
    int timeLeft = 25;
    Timer? timer;
    bool isCanceled = false;



    void startTimer(BuildContext dialogContext, StateSetter setDialogState) {
      timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted || isCanceled) {
          t.cancel();
          return;
        }
        if (timeLeft <= 0) {
          t.cancel();
          if (mounted && dialogContext.mounted && _pendingChallengeId == challengeId) {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            _challengeService.cancel(challengeId).then((_) {
              if (mounted) {
                setState(() {
                  _pendingChallengeId = null;
                });
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: const Text('Le temps pour accepter le défi a expiré'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            });
          }
        } else {
          if (mounted) {
            setDialogState(() {
              timeLeft--;
            });
          }
        }
      });
      _realtimeChallengeChannel?.onPostgresChanges(
        event: supa.PostgresChangeEvent.update,
        schema: 'public',
        table: 'challenges',
        filter: supa.PostgresChangeFilter(
          type: supa.PostgresChangeFilterType.eq,
          column: 'id',
          value: challengeId,
        ),
        callback: (payload) {
          if (!mounted || isCanceled) return;
          final challenge = payload.newRecord;
          if (challenge['status'] == 'active') {
            isCanceled = true;
            timer?.cancel();
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          }
        },
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            if (!isCanceled) {
              startTimer(dialogContext, setDialogState);
            }
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.white.withOpacity(0.95),
                title: Text(
                  'Attente de $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF7A5AF8)),
                        SizedBox(width: 16),
                        Text(
                          'En attente de la réponse...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Temps restant : $timeLeft s',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      isCanceled = true;
                      timer?.cancel();
                      if (_pendingChallengeId == challengeId) {
                        await _challengeService.cancel(challengeId);
                        if (mounted) {
                          setState(() {
                            _pendingChallengeId = null;
                          });
                          if (Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }
                        }
                      }
                    },
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      timer?.cancel();
      isCanceled = true;
    });
  }

  void _showChallengeDialog(Map<String, dynamic> challenge) {
    int timeLeft = 25;
    Timer? timer;
    bool isCanceled = false;
    bool isLoading = false;

    void startTimer(BuildContext dialogContext, StateSetter setDialogState) {
      timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted || isCanceled) {
          t.cancel();
          return;
        }
        if (timeLeft <= 0) {
          t.cancel();
          if (mounted && dialogContext.mounted) {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            _challengeService.decline(challenge['id']).then((_) {
              if (mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: const Text('Le temps pour accepter le défi a expiré'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            });
          }
        } else {
          if (mounted) {
            setDialogState(() {
              timeLeft--;
            });
          }
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            startTimer(dialogContext, setDialogState);
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.white.withOpacity(0.95),
                title: Text(
                  'Défi de ${challenge['player1']['pseudo']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mise : ${challenge['player2_bet']} XP',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Temps restant : $timeLeft s',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(color: Color(0xFF7A5AF8)),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                      isCanceled = true;
                      timer?.cancel();
                      await _challengeService.decline(challenge['id']);
                      if (mounted && dialogContext.mounted) {
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                      }
                    },
                    child: const Text(
                      'Refuser',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                      isCanceled = true;
                      timer?.cancel();
                      setDialogState(() {
                        isLoading = true;
                      });
                      HapticFeedback.lightImpact();
                      final response = await _challengeService.accept(challenge['id']);
                      if (response['statusCode'] == 200 && mounted && dialogContext.mounted) {
                        setState(() {
                          _isNavigating = true;
                        });
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DuelScreen(challengeId: challenge['id']),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isLoading = false;
                        });
                        if (dialogContext.mounted) {
                          if (Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(response['error'] ?? 'Erreur lors de l\'acceptation'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A5AF8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Accepter',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      timer?.cancel();
      isCanceled = true;
    });
  }

  Widget _buildUserTile({required User user}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: Future.wait([
        _userService.getUserById(user.id),
        _userService.getUserById(_friendService.currentUserId),
      ]).then((results) => {'target': results[0], 'current': results[1]}),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(title: Text('Chargement...'));
        }
        final userData = snapshot.data!['target'] as Map<String, dynamic>;
        final currentUserData = snapshot.data!['current'] as Map<String, dynamic>;
        final targetXp = userData['xp'] as int? ?? 0;
        final currentUserXp = currentUserData['xp'] as int? ?? 0;
        final maxBet = targetXp < currentUserXp ? targetXp : currentUserXp;
        final challengeStatus = _getChallengeStatus(user.id);
        final hasChallenge = _hasPendingOrActiveChallenge(user.id);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
            ),
            color: Colors.white.withOpacity(0.95),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF7A5AF8).withOpacity(0.1),
                    backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                        ? NetworkImage(user.avatar!)
                        : null,
                    child: user.avatar == null || user.avatar!.isEmpty
                        ? Text(
                      user.pseudo.isNotEmpty ? user.pseudo[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A5AF8),
                      ),
                    )
                        : null,
                  ),
                  if (user.status == 'online')
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                user.pseudo.isNotEmpty ? user.pseudo : 'Utilisateur inconnu',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              subtitle: Text(
                '${user.firstname} ${user.lastname ?? ''}'.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              trailing: ElevatedButton(
                onPressed: user.status == 'online' && !hasChallenge
                    ? () => _showInviteDialog(context, user.id, user.pseudo, maxBet)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasChallenge ? Colors.grey : const Color(0xFF7A5AF8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  hasChallenge
                      ? (challengeStatus == 'pending' ? 'En attente de duel' : 'En duel')
                      : 'Inviter',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileOtherUserScreen(userId: user.id),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeTile({required Map<String, dynamic> challenge}) {
    final opponent = challenge['player1'];
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
        ),
        color: Colors.white.withOpacity(0.95),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            'Défi de ${opponent['pseudo']}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          subtitle: Text(
            'Mise : ${challenge['player2_bet']} XP',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => _showChallengeDialog(challenge),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A5AF8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'Accepter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _challengeService.decline(challenge['id']);
                },
                child: const Text(
                  'Refuser',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFEDE7F6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: const [
                    Icon(Icons.group, color: Color(0xFF7A5AF8), size: 26),
                    SizedBox(width: 8),
                    Text(
                      'Lobby',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un ami en ligne...',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.green, size: 24),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              if (_pendingChallenges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: const Text(
                    'Défis en attente',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2E),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  color: const Color(0xFF7A5AF8),
                  backgroundColor: Colors.white,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _loadingState == LoadingState.loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8)))
                        : _loadingState == LoadingState.error
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Erreur : ${_errorMessage ?? 'Une erreur est survenue'}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1A2E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A5AF8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text(
                              'Réessayer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_pendingChallenges.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              itemCount: _pendingChallenges.length,
                              itemBuilder: (child, index) {
                                return _buildChallengeTile(challenge: _pendingChallenges[index]);
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: const Text(
                              'Amis en ligne',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A2E),
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            itemCount: _filteredUsers
                                .where((user) =>
                            user.status == 'online' &&
                                _friends.any((friend) =>
                                friend.userId == _friendService.currentUserId
                                    ? friend.friendId == user.id
                                    : friend.userId == user.id))
                                .length,
                            itemBuilder: (child, index) {
                              final onlineFriends = _filteredUsers
                                  .where((user) =>
                              user.status == 'online' &&
                                  _friends.any((friend) =>
                                  friend.userId == _friendService.currentUserId
                                      ? friend.friendId == user.id
                                      : friend.userId == user.id))
                                  .toList();
                              if (onlineFriends.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Aucun ami en ligne trouvé',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF1A2E),
                                    ),
                                  ),
                                );
                              }
                              return _buildUserTile(user: onlineFriends[index]);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
