import 'package:flutter/material.dart';
import 'package:quiz_gamifie/src/config/constants.dart';
import 'package:quiz_gamifie/src/services/auth_service.dart';
import 'package:quiz_gamifie/src/services/user_service.dart';
import 'package:quiz_gamifie/src/screens/profile_other_user_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'dart:async';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _leaderboard = [];
  final supa.SupabaseClient supabase = supa.Supabase.instance.client;
  bool _isLoading = true;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  Map<String, List<Map<String, dynamic>>> _leagueUsers = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    _animationController!.forward();
    _initializeData();
    _streamSubscription = supabase.from('users').stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await _authService.getCurrentUser();
      final leaderboardData = await _userService.getLeaderboard();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _leaderboard = leaderboardData;
        _leagueUsers = _groupByLeague(leaderboardData);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des données: $e')),
        );
      }
    }
  }

  Future<void> _fetchData() async {
    try {
      final leaderboardData = await _userService.getLeaderboard();
      if (!mounted) return;
      setState(() {
        _leaderboard = leaderboardData;
        _leagueUsers = _groupByLeague(leaderboardData);
      });
    } catch (e) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour du classement: $e')),
        );
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByLeague(List<Map<String, dynamic>> users) {
    final leagueUsers = <String, List<Map<String, dynamic>>>{};
    for (var league in AppConstants.leagues.keys) {
      leagueUsers[league] = users.where((user) {
        final xp = user['xp'] ?? 0;
        return _getLeague(xp) == league;
      }).toList();
      leagueUsers[league]!.sort((a, b) => (b['xp'] ?? 0).compareTo(a['xp'] ?? 0));
    }
    return leagueUsers;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8)))
              : RefreshIndicator(
            onRefresh: _fetchData,
            color: const Color(0xFF7A5AF8),
            child: Column(
              children: [
                const TabBar(
                  labelColor: Color(0xFF7A5AF8),
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Color(0xFF7A5AF8),
                  tabs: [
                    Tab(text: 'Global'),
                    Tab(text: 'Par Ligue'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        child: _fadeAnimation != null
                            ? FadeTransition(
                          opacity: _fadeAnimation!,
                          child: _leaderboard.isEmpty
                              ? const Center(
                            child: Text(
                              'Aucun utilisateur dans le classement.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          )
                              : _buildLeaderboardContent(),
                        )
                            : _leaderboard.isEmpty
                            ? const Center(
                          child: Text(
                            'Aucun utilisateur dans le classement.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        )
                            : _buildLeaderboardContent(),
                      ),
                      _buildLeagueView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    final topThree = _leaderboard.length >= 3 ? _leaderboard.sublist(0, 3) : _leaderboard;
    final others = _leaderboard.length > 3 ? _leaderboard.sublist(3) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_currentUser != null) _buildProgressBar(_currentUser!['xp'] ?? 0),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.leaderboard, color: Color(0xFF7A5AF8), size: 28),
            const SizedBox(width: 8),
            Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (topThree.isNotEmpty) _buildPodium(topThree),
        const SizedBox(height: 20),
        if (others.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(others.length, (index) {
                final user = others[index];
                final rank = index + 4;
                final isCurrentUser = _currentUser != null && user['id'] == _currentUser!['id'];
                return _buildListItem(context, user, rank, isCurrentUser);
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topThree) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7A5AF8),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (topThree.length > 1) _buildPodiumItem(context, topThree[1], 2, 120, Colors.blue.shade300),
          if (topThree.isNotEmpty) _buildPodiumItem(context, topThree[0], 1, 160, Colors.pink.shade300),
          if (topThree.length > 2) _buildPodiumItem(context, topThree[2], 3, 100, Colors.yellow.shade300),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(BuildContext context, Map<String, dynamic> user, int rank, double height, Color circleColor) {
    final isCurrentUser = _currentUser != null && user['id'] == _currentUser!['id'];
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileOtherUserScreen(userId: user['id']),
          ),
        );
      },
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-0.1)
          ..rotateY(rank == 2 ? 0.1 : rank == 3 ? -0.1 : 0.0),
        alignment: Alignment.center,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAvatarColor(rank - 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF7A5AF8).withOpacity(0.1),
                    backgroundImage: user['avatar'] != null && user['avatar'].isNotEmpty
                        ? NetworkImage(user['avatar'])
                        : null,
                    child: user['avatar'] == null || user['avatar'].isEmpty
                        ? Text(
                      user['pseudo']?.isNotEmpty == true ? user['pseudo'][0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A5AF8),
                      ),
                    )
                        : null,
                  ),
                ),
                if (user['status'] == 'online')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user['pseudo'] ?? '${user['firstname']} ${user['lastname']}'.trim(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isCurrentUser ? Colors.yellowAccent : Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
            Text(
              '${user['xp'] ?? 0} xp',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Container(
              width: 80,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, Map<String, dynamic> user, int rank, bool isCurrentUser) {
    final league = _getLeague(user['xp'] ?? 0);
    final leagueStyle = AppConstants.getLeagueStyles(league);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileOtherUserScreen(userId: user['id']),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentUser ? const Color(0xFF7A5AF8) : null,
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                '$rank',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getAvatarColor(rank - 1),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF7A5AF8).withOpacity(0.1),
                      backgroundImage: user['avatar'] != null && user['avatar'].isNotEmpty
                          ? NetworkImage(user['avatar'])
                          : null,
                      child: user['avatar'] == null || user['avatar'].isEmpty
                          ? Text(
                        user['pseudo']?.isNotEmpty == true ? user['pseudo'][0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? Colors.white : const Color(0xFF7A5AF8),
                        ),
                      )
                          : null,
                    ),
                  ),
                  if (user['status'] == 'online')
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['pseudo'] ?? '${user['firstname']} ${user['lastname']}'.trim(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isCurrentUser ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: leagueStyle['border'] as Color,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        league,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: leagueStyle['text'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${user['xp'] ?? 0} xp',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueView() {
    return DefaultTabController(
      length: AppConstants.leagues.keys.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF7A5AF8),
            unselectedLabelColor: Colors.black54,
            indicatorColor: const Color(0xFF7A5AF8),
            tabs: AppConstants.leagues.keys
                .map((league) => Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppConstants.getLeagueStyles(league)['border'] as Color,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  league,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.getLeagueStyles(league)['text'] as Color,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              children: AppConstants.leagues.keys.map((league) {
                final users = _leagueUsers[league] ?? [];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    children: [
                      if (_currentUser != null && _getLeague(_currentUser!['xp'] ?? 0) == league)
                        const SizedBox(height: 20),
                      users.isEmpty
                          ? const Center(
                        child: Text(
                          'Aucun utilisateur dans cette ligue.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      )
                          : Column(
                        children: List.generate(users.length, (index) {
                          final user = users[index];
                          final rank = index + 1;
                          final isCurrentUser = _currentUser != null && user['id'] == _currentUser!['id'];
                          return _buildListItem(context, user, rank, isCurrentUser);
                        }),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int currentXp) {
    final currentLeague = _getLeague(currentXp);
    final currentLeagueStyle = AppConstants.getLeagueStyles(currentLeague);
    final nextLeague = _getNextLeague(currentLeague);
    final nextLeagueStyle = nextLeague != null ? AppConstants.getLeagueStyles(nextLeague) : null;
    final currentMinXp = AppConstants.leagues[currentLeague]!['min_xp'] as int;
    final currentMaxXp = AppConstants.leagues[currentLeague]!['max_xp'] as int?;
    final nextMinXp = nextLeague != null ? AppConstants.leagues[nextLeague]!['min_xp'] as int : null;

    double progress = 0.0;
    int xpUntilNext = 0;
    if (currentMaxXp != null && nextMinXp != null) {
      final range = currentMaxXp - currentMinXp;
      final progressInRange = currentXp - currentMinXp;
      progress = (progressInRange / range).clamp(0.0, 1.0);
      xpUntilNext = nextMinXp - currentXp;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (currentLeagueStyle['border'] as Color).withOpacity(0.1),
        border: Border.all(
          color: currentLeagueStyle['border'] as Color,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: currentLeagueStyle['text'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentLeague,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: currentLeagueStyle['text'] as Color,
                    ),
                  ),
                ],
              ),
              Text(
                '$currentXp/$nextMinXp XP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: currentLeagueStyle['text'] as Color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nextMinXp != null)
            Stack(
              children: [
                LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    nextLeagueStyle!['border'] as Color,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    currentLeagueStyle['border'] as Color,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          if (nextMinXp == null)
            const Text(
              'Niveau maximum atteint !',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          if (nextMinXp != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$xpUntilNext XP jusqu\'à $nextLeague',
                    style: TextStyle(
                      fontSize: 12,
                      color: nextLeagueStyle!['text'] as Color,
                    ),
                  ),
                  Text(
                    '${((1.0 - progress) * 100).toStringAsFixed(1)}% restant',
                    style: TextStyle(
                      fontSize: 12,
                      color: nextLeagueStyle!['text'] as Color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getLeague(int xp) {
    for (var league in AppConstants.leagues.keys) {
      final minXp = AppConstants.leagues[league]!['min_xp'] as int;
      final maxXp = AppConstants.leagues[league]!['max_xp'] as int?;
      if (xp >= minXp && (maxXp == null || xp <= maxXp)) {
        return league;
      }
    }
    return 'Bronze';
  }

  String? _getNextLeague(String currentLeague) {
    final leagueKeys = AppConstants.leagues.keys.toList();
    final currentIndex = leagueKeys.indexOf(currentLeague);
    if (currentIndex < leagueKeys.length - 1) {
      return leagueKeys[currentIndex + 1];
    }
    return null;
  }

  Color _getAvatarColor(int index) {
    final colors = [
      Colors.orange,
      Colors.green,
      Colors.pink,
      Colors.red,
    ];
    return colors[index % colors.length];
  }
}