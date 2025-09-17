import 'package:flutter/material.dart';
import 'package:quiz_gamifie/src/config/constants.dart';
import 'package:quiz_gamifie/src/services/user_service.dart';
import 'package:quiz_gamifie/src/services/badge_service.dart';

class ProfileOtherUserScreen extends StatefulWidget {
  final String userId;
  const ProfileOtherUserScreen({super.key, required this.userId});

  @override
  State<ProfileOtherUserScreen> createState() => _ProfileOtherUserScreen();
}

class _ProfileOtherUserScreen extends State<ProfileOtherUserScreen> with TickerProviderStateMixin {
  late Future<Map<String, dynamic>> _userDataFuture;
  late Future<List<Map<String, dynamic>>> _badgesFuture;
  final BadgeService _badgeService = BadgeService();
  late AnimationController _pulseAnimationController;
  late AnimationController _shineAnimationController;
  late AnimationController _rotateAnimationController;
  late AnimationController _flameAnimationController;
  late AnimationController _vibrateAnimationController;
  late AnimationController _fastPulseAnimationController;
  late AnimationController _softPulseAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shineAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _flameAnimation;
  late Animation<Offset> _vibrateAnimation;
  late Animation<double> _fastPulseAnimation;
  late Animation<double> _softPulseAnimation;

  @override
  void initState() {
    super.initState();
    _userDataFuture = UserService().getUserById(widget.userId);
    _badgesFuture = _badgeService.getAllBadges();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _shineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _rotateAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _flameAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _vibrateAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);

    _fastPulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _softPulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );

    _shineAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _shineAnimationController, curve: Curves.easeInOutSine),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 360.0).animate(
      CurvedAnimation(parent: _rotateAnimationController, curve: Curves.linear),
    );

    _flameAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _flameAnimationController, curve: Curves.easeInOutBack),
    );

    _vibrateAnimation = Tween<Offset>(
      begin: const Offset(-0.02, 0.0),
      end: const Offset(0.02, 0.0),
    ).animate(
      CurvedAnimation(parent: _vibrateAnimationController, curve: Curves.easeInOut),
    );

    _fastPulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _fastPulseAnimationController, curve: Curves.easeInOut),
    );

    _softPulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _softPulseAnimationController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _shineAnimationController.dispose();
    _rotateAnimationController.dispose();
    _flameAnimationController.dispose();
    _vibrateAnimationController.dispose();
    _fastPulseAnimationController.dispose();
    _softPulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF7A5AF8),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([_userDataFuture, _badgesFuture]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8)));
            } else if (snapshot.hasError) {
              String errorMessage = 'Erreur inconnue';
              if (snapshot.error.toString().contains('user')) {
                errorMessage = 'Erreur lors du chargement des données utilisateur';
              } else if (snapshot.error.toString().contains('badges')) {
                errorMessage = 'Erreur lors du chargement des badges';
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _userDataFuture = UserService().getUserById(widget.userId);
                          _badgesFuture = _badgeService.getAllBadges();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A5AF8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Réessayer',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasData) {
              final userData = snapshot.data![0] as Map<String, dynamic>;
              final allBadges = snapshot.data![1] as List<Map<String, dynamic>>;
              final friends = (userData['friends'] ?? [])
                  .where((friend) => friend['status'] == 'accepted')
                  .toList() as List<dynamic>;
              final userResponses = (userData['user_responses'] ?? []) as List<dynamic>;
              final histories = (userData['histories'] ?? []) as List<dynamic>;
              final userBadges = (userData['user_badges'] ?? []) as List<dynamic>;
              final league = userData['league'] ?? 'Bronze';
              final leagueStyle = AppConstants.getLeagueStyles(league);

              final sortedBadges = List<Map<String, dynamic>>.from(allBadges);
              sortedBadges.sort((a, b) {
                bool isEarnedA = userBadges.any((userBadge) =>
                userBadge['badge_id'] != null &&
                    a['id'] != null &&
                    userBadge['badge_id'] == a['id']) ||
                    _badgeService.evaluateBadgeCondition(a['condition'] ?? '', userData);
                bool isEarnedB = userBadges.any((userBadge) =>
                userBadge['badge_id'] != null &&
                    b['id'] != null &&
                    userBadge['badge_id'] == b['id']) ||
                    _badgeService.evaluateBadgeCondition(b['condition'] ?? '', userData);
                return isEarnedA == isEarnedB ? 0 : isEarnedA ? -1 : 1;
              });

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _userDataFuture = UserService().getUserById(widget.userId);
                    _badgesFuture = _badgeService.getAllBadges();
                  });
                },
                color: const Color(0xFF7A5AF8),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFF7A5AF8).withOpacity(0.1),
                                  backgroundImage: userData['avatar'] != null
                                      ? NetworkImage(userData['avatar'] as String)
                                      : null,
                                  child: userData['avatar'] == null
                                      ? Text(
                                    userData['pseudo']?.isNotEmpty == true
                                        ? (userData['pseudo'] as String)[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7A5AF8),
                                    ),
                                  )
                                      : null,
                                ),
                                if (userData['status'] == 'online')
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
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
                            const SizedBox(height: 12),
                            Text(
                              '${userData['firstname'] ?? 'Inconnu'} ${userData['lastname'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '@${userData['pseudo'] ?? 'Inconnu'}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: leagueStyle['text'] as Color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informations',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                leading: const Icon(Icons.person, color: Color(0xFF7A5AF8)),
                                title: Text(
                                  userData['pseudo'] ?? 'Inconnu',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Pseudo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.email, color: Color(0xFF7A5AF8)),
                                title: Text(
                                  userData['email'] ?? 'Inconnu',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              if (userData['country'] != null)
                                ListTile(
                                  leading: const Icon(Icons.flag, color: Color(0xFF7A5AF8)),
                                  title: Text(
                                    userData['country'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Pays',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              if (userData['bio'] != null)
                                ListTile(
                                  leading: const Icon(Icons.info, color: Color(0xFF7A5AF8)),
                                  title: Text(
                                    userData['bio'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Bio',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ListTile(
                                leading: const Icon(Icons.star, color: Color(0xFF7A5AF8)),
                                title: Text(
                                  userData['xp']?.toString() ?? '0',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'XP',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.emoji_events, color: Color(0xFF7A5AF8)),
                                title: Text(
                                  userData['duel_wins']?.toString() ?? '0',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Victoires en duel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: Icon(
                                  userData['status'] == 'online' ? Icons.circle : Icons.circle_outlined,
                                  color: userData['status'] == 'online' ? Colors.green : Colors.grey,
                                ),
                                title: Text(
                                  userData['status'] == 'online' ? 'En ligne' : 'Hors ligne',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Statut',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.check_circle, color: Color(0xFF7A5AF8)),
                                title: Text(
                                  userData['is_active'] == true ? 'Oui' : 'Non',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Actif',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.calendar_today, color: Color(0xFF7A5AF8)),
                                title: Text(
                                  userData['created_at'] != null
                                      ? DateTime.parse(userData['created_at']).toLocal().toString().split('.')[0]
                                      : 'Inconnu',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Inscrit le',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amis',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              friends.isNotEmpty
                                  ? ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: friends.length,
                                itemBuilder: (context, index) {
                                  final friendData = friends[index];
                                  final friend = friendData['friend_id'] == userData['id']
                                      ? friendData['user']
                                      : friendData['friend'];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF7A5AF8).withOpacity(0.1),
                                      backgroundImage: friend['avatar'] != null
                                          ? NetworkImage(friend['avatar'] as String)
                                          : null,
                                      child: friend['avatar'] == null
                                          ? Text(
                                        friend['pseudo']?.isNotEmpty == true
                                            ? (friend['pseudo'] as String)[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7A5AF8),
                                        ),
                                      )
                                          : null,
                                    ),
                                    title: Text(
                                      friend['pseudo'] ?? 'Inconnu',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      friend['status'] == 'online' ? 'En ligne' : 'Hors ligne',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  );
                                },
                              )
                                  : Text(
                                'Aucun ami accepté pour le moment.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Badges',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              sortedBadges.isNotEmpty
                                  ? LayoutBuilder(
                                builder: (context, constraints) {
                                  return SizedBox(
                                    height: constraints.maxHeight < 450 ? constraints.maxHeight : 450,
                                    child: GridView.builder(
                                      scrollDirection: Axis.horizontal,
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        childAspectRatio: 0.8,
                                      ),
                                      itemCount: sortedBadges.length,
                                      itemBuilder: (context, index) {
                                        final badge = sortedBadges[index];
                                        final isEarned = userBadges.any((userBadge) =>
                                        userBadge['badge_id'] != null &&
                                            badge['id'] != null &&
                                            userBadge['badge_id'] == badge['id']) ||
                                            _badgeService.evaluateBadgeCondition(
                                                badge['condition'] ?? '', userData);
                                        final animationType = badge['animation'] ?? 'pulse';
                                        final badgeColor = Color(int.parse(
                                            (badge['color'] ?? '#7A5AF8').replaceFirst('#', '0xFF')));

                                        IconData badgeIconData = Icons.star;
                                        if (badge['name']?.contains('Flamme') == true ||
                                            badge['name']?.contains('Éclair') == true) {
                                          badgeIconData = Icons.local_fire_department;
                                        } else if (badge['name']?.contains('Étoile') == true ||
                                            badge['name']?.contains('Lueur') == true ||
                                            badge['name']?.contains('Éclat') == true) {
                                          badgeIconData = Icons.star_border;
                                        } else if (badge['name']?.contains('Champion') == true ||
                                            badge['name']?.contains('Maître') == true ||
                                            badge['name']?.contains('Roi') == true ||
                                            badge['name']?.contains('Empereur') == true) {
                                          badgeIconData = Icons.emoji_events;
                                        }

                                        Widget badgeIcon;
                                        if (isEarned) {
                                          switch (animationType) {
                                            case 'shine':
                                              badgeIcon = FadeTransition(
                                                opacity: _shineAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                            case 'rotate':
                                              badgeIcon = RotationTransition(
                                                turns: _rotateAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                            case 'flame':
                                              badgeIcon = ScaleTransition(
                                                scale: _flameAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                            case 'vibrate':
                                              badgeIcon = SlideTransition(
                                                position: _vibrateAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                            case 'fastPulse':
                                              badgeIcon = ScaleTransition(
                                                scale: _fastPulseAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                            case 'softPulse':
                                              badgeIcon = ScaleTransition(
                                                scale: _softPulseAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                            case 'pulse':
                                            default:
                                              badgeIcon = ScaleTransition(
                                                scale: _pulseAnimation,
                                                child: Icon(
                                                  badgeIconData,
                                                  color: badgeColor,
                                                  size: 32,
                                                ),
                                              );
                                              break;
                                          }
                                        } else {
                                          badgeIcon = Icon(
                                            badgeIconData,
                                            color: Colors.grey.withOpacity(0.5),
                                            size: 32,
                                          );
                                        }

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: badgeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isEarned
                                                  ? badgeColor
                                                  : Colors.grey.withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              if (isEarned)
                                                _buildBackgroundAnimation(animationType, badgeColor),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  badgeIcon,
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    badge['name'] ?? 'Inconnu',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: isEarned
                                                          ? badgeColor
                                                          : Colors.grey.withOpacity(0.5),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  Text(
                                                    badge['description'] ?? 'Aucune description',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isEarned
                                                          ? Colors.black87
                                                          : Colors.grey.withOpacity(0.5),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              )
                                  : Text(
                                'Aucun badge disponible.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Réponses',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              userResponses.isNotEmpty
                                  ? Column(
                                children: [
                                  Text(
                                    'Nombre total de réponses : ${userResponses.length}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: userResponses.length,
                                    itemBuilder: (context, index) {
                                      final response = userResponses[index];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.question_answer,
                                          color: Color(0xFF7A5AF8),
                                          size: 24,
                                        ),
                                        title: Text(
                                          'Réponse #${response['id'] ?? 'Inconnu'}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Question ID: ${response['question_id'] ?? 'Inconnu'}, Réponse ID: ${response['answer_id'] ?? 'Inconnu'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        trailing: Text(
                                          response['created_at'] != null
                                              ? DateTime.parse(response['created_at'])
                                              .toLocal()
                                              .toString()
                                              .split('.')[0]
                                              : 'Inconnu',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                                  : Text(
                                'Aucune réponse pour le moment.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Historique',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              histories.isNotEmpty
                                  ? SizedBox(
                                height: 300,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: histories.length,
                                  itemBuilder: (context, index) {
                                    final history = histories[index];
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.history,
                                        color: Color(0xFF7A5AF8),
                                        size: 24,
                                      ),
                                      title: Text(
                                        history['type'] ?? 'Inconnu',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        history['description'] ?? 'Aucune description',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: Text(
                                        history['value']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                                  : Text(
                                'Aucun historique disponible.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Center(
                child: Text(
                  'Aucune donnée utilisateur disponible',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBackgroundAnimation(String animationType, Color badgeColor) {
    switch (animationType) {
      case 'shine':
        return FadeTransition(
          opacity: _shineAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case 'rotate':
        return RotationTransition(
          turns: _rotateAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case 'flame':
        return ScaleTransition(
          scale: _flameAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case 'vibrate':
        return SlideTransition(
          position: _vibrateAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case 'fastPulse':
        return ScaleTransition(
          scale: _fastPulseAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case 'softPulse':
        return ScaleTransition(
          scale: _softPulseAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case 'pulse':
      default:
        return ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }
}