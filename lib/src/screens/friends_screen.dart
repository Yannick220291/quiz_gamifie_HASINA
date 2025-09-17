import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:quiz_gamifie/src/services/friend_service.dart';
import 'package:quiz_gamifie/src/services/user_service.dart';
import 'package:quiz_gamifie/src/screens/profile_other_user_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/friend.dart';
import '../models/user.dart';

enum LoadingState { initial, loading, success, error }

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with TickerProviderStateMixin {
  final _logger = Logger();
  final UserService _userService = UserService();
  final FriendService _friendService = FriendService();
  final supa.SupabaseClient supabase = supa.Supabase.instance.client;

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  List<Friend> _friends = [];
  List<Friend> _incomingRequests = [];
  List<Friend> _outgoingRequests = [];
  LoadingState _loadingState = LoadingState.initial;
  String? _errorMessage;
  Map<String, bool> _actionLoading = {};
  supa.RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    _animationController.dispose();
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = supabase.channel('friends').onPostgresChanges(
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
              } else if (newFriend.status == 'pending' &&
                  newFriend.friendId == _friendService.currentUserId) {
                _incomingRequests.add(newFriend);
              } else if (newFriend.status == 'pending' &&
                  newFriend.userId == _friendService.currentUserId) {
                _outgoingRequests.add(newFriend);
              }
            });
          } else if (payload.eventType == supa.PostgresChangeEvent.update) {
            setState(() {
              _friends.removeWhere((f) => f.id == friendData['id']);
              _incomingRequests.removeWhere((r) => r.id == friendData['id']);
              _outgoingRequests.removeWhere((r) => r.id == friendData['id']);
              final updatedFriend = Friend.fromJson(friendData);
              if (updatedFriend.status == 'accepted') {
                _friends.add(updatedFriend);
              } else if (updatedFriend.status == 'pending' &&
                  updatedFriend.friendId == _friendService.currentUserId) {
                _incomingRequests.add(updatedFriend);
              } else if (updatedFriend.status == 'pending' &&
                  updatedFriend.userId == _friendService.currentUserId) {
                _outgoingRequests.add(updatedFriend);
              }
            });
          } else if (payload.eventType == supa.PostgresChangeEvent.delete) {
            setState(() {
              _friends.removeWhere((f) => f.id == friendData['id']);
              _incomingRequests.removeWhere((r) => r.id == friendData['id']);
              _outgoingRequests.removeWhere((r) => r.id == friendData['id']);
            });
          }
        }
      },
    )..subscribe();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers
          .where((user) =>
      user.pseudo.toLowerCase().contains(query) ||
          user.firstname.toLowerCase().contains(query) ||
          (user.lastname != null && user.lastname!.toLowerCase().contains(query)))
          .toList();
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _loadingState = LoadingState.loading;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getAllUsers();
      final friendsResponse = await _friendService.getFriends();

      if (!mounted) return;
      setState(() {
        _allUsers = users.map((user) => User.fromJson(user)).toList();
        _filteredUsers = _allUsers;
        if (friendsResponse['statusCode'] == 200) {
          final friendships = (friendsResponse['data'] as List)
              .map((f) => Friend.fromJson(f))
              .toList();
          _friends = friendships.where((f) => f.status == 'accepted').toList();
          _incomingRequests = friendships
              .where((f) => f.status == 'pending' && f.friendId == _friendService.currentUserId)
              .toList();
          _outgoingRequests = friendships
              .where((f) => f.status == 'pending' && f.userId == _friendService.currentUserId)
              .toList();
        }
        _loadingState = LoadingState.success;
      });
    } catch (e) {
      _logger.e('Erreur lors du chargement des données: $e');
      setState(() {
        _loadingState = LoadingState.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFEDE7F6)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: const [
                  Icon(Icons.people, color: Color(0xFF7A5AF8), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Amis',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur...',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF7A5AF8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
                style: const TextStyle(color: Color(0xFF1A1A2E)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF7A5AF8),
                labelColor: const Color(0xFF7A5AF8),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Amis'),
                  Tab(text: 'Demandes'),
                  Tab(text: 'Suggestions'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                color: const Color(0xFF7A5AF8),
                backgroundColor: Colors.white,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadingState) {
      case LoadingState.loading:
        return const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8)));
      case LoadingState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Erreur: ${_errorMessage ?? 'Une erreur est survenue'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A5AF8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      case LoadingState.success:
      case LoadingState.initial:
        return TabBarView(
          controller: _tabController,
          children: [
            _buildFriendsList(),
            _buildRequestsList(),
            _buildSuggestionsList(),
          ],
        );
    }
  }

  Widget _buildFriendsList() {
    final friendsList = _searchController.text.isEmpty
        ? _friends
        : _friends.where((friendship) {
      final friend = _allUsers.firstWhere(
            (u) =>
        u.id ==
            (friendship.userId == _friendService.currentUserId
                ? friendship.friendId
                : friendship.userId),
        orElse: () => User(
          id: '',
          pseudo: 'Inconnu',
          firstname: 'Utilisateur',
          email: '',
          league: '',
          status: '',
          role: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          xp: 0,
          duelWins: 0,
          isActive: false,
        ),
      );
      return _filteredUsers.contains(friend);
    }).toList();

    if (friendsList.isEmpty) {
      return Center(
        child: Text(
          'Aucun ami trouvé',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: friendsList.length,
      itemBuilder: (context, index) {
        final friendship = friendsList[index];
        final friend = _allUsers.firstWhere(
              (u) =>
          u.id ==
              (friendship.userId == _friendService.currentUserId
                  ? friendship.friendId
                  : friendship.userId),
          orElse: () => User(
            id: '',
            pseudo: 'Inconnu',
            firstname: 'Utilisateur',
            email: '',
            league: '',
            status: '',
            role: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            xp: 0,
            duelWins: 0,
            isActive: false,
          ),
        );
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _buildUserTile(
            user: friend,
            trailing: _buildActionButton(
              icon: const Icon(Icons.person_remove, color: Colors.red),
              isLoading: _actionLoading[friend.id] ?? false,
              onPressed: () => _removeFriend(friend.id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    final incomingRequestsList = _searchController.text.isEmpty
        ? _incomingRequests
        : _incomingRequests.where((request) {
      final requester = _allUsers.firstWhere(
            (u) => u.id == request.userId,
        orElse: () => User(
          id: '',
          pseudo: 'Inconnu',
          firstname: 'Utilisateur',
          email: '',
          league: '',
          status: '',
          role: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          xp: 0,
          duelWins: 0,
          isActive: false,
        ),
      );
      return _filteredUsers.contains(requester);
    }).toList();

    final outgoingRequestsList = _searchController.text.isEmpty
        ? _outgoingRequests
        : _outgoingRequests.where((request) {
      final recipient = _allUsers.firstWhere(
            (u) => u.id == request.friendId,
        orElse: () => User(
          id: '',
          pseudo: 'Inconnu',
          firstname: 'Utilisateur',
          email: '',
          league: '',
          status: '',
          role: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          xp: 0,
          duelWins: 0,
          isActive: false,
        ),
      );
      return _filteredUsers.contains(recipient);
    }).toList();

    if (incomingRequestsList.isEmpty && outgoingRequestsList.isEmpty) {
      return Center(
        child: Text(
          'Aucune demande trouvée',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      children: [
        if (incomingRequestsList.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Demandes reçues',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          ...incomingRequestsList.map((request) {
            final requester = _allUsers.firstWhere(
                  (u) => u.id == request.userId,
              orElse: () => User(
                id: '',
                pseudo: 'Inconnu',
                firstname: 'Utilisateur',
                email: '',
                league: '',
                status: '',
                role: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                xp: 0,
                duelWins: 0,
                isActive: false,
              ),
            );
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildUserTile(
                user: requester,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      isLoading: _actionLoading[requester.id] ?? false,
                      onPressed: () => _acceptRequest(requester.id),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      isLoading: _actionLoading[requester.id] ?? false,
                      onPressed: () => _rejectRequest(requester.id),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        if (outgoingRequestsList.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Demandes envoyées',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          ...outgoingRequestsList.map((request) {
            final recipient = _allUsers.firstWhere(
                  (u) => u.id == request.friendId,
              orElse: () => User(
                id: '',
                pseudo: 'Inconnu',
                firstname: 'Utilisateur',
                email: '',
                league: '',
                status: '',
                role: '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                xp: 0,
                duelWins: 0,
                isActive: false,
              ),
            );
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildUserTile(
                user: recipient,
                trailing: _buildActionButton(
                  icon: const Icon(Icons.cancel, color: Colors.orange),
                  isLoading: _actionLoading[recipient.id] ?? false,
                  onPressed: () => _cancelRequest(recipient.id),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSuggestionsList() {
    final suggestions = _searchController.text.isEmpty
        ? _allUsers.where((user) {
      return user.id != _friendService.currentUserId &&
          !_friends.any((f) => f.userId == user.id || f.friendId == user.id) &&
          !_incomingRequests.any((r) => r.userId == user.id || r.friendId == user.id) &&
          !_outgoingRequests.any((r) => r.userId == user.id || r.friendId == user.id);
    }).toList()
        : _filteredUsers.where((user) {
      return user.id != _friendService.currentUserId &&
          !_friends.any((f) => f.userId == user.id || f.friendId == user.id) &&
          !_incomingRequests.any((r) => r.userId == user.id || r.friendId == user.id) &&
          !_outgoingRequests.any((r) => r.userId == user.id || r.friendId == user.id);
    }).toList();

    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          'Aucune suggestion trouvée',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final user = suggestions[index];
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _buildUserTile(
            user: user,
            trailing: _buildActionButton(
              icon: const Icon(Icons.person_add, color: Color(0xFF7A5AF8)),
              isLoading: _actionLoading[user.id] ?? false,
              onPressed: () => _sendFriendRequest(user.id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserTile({required User user, required Widget trailing}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
      ),
      color: Colors.white.withOpacity(0.95),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 2),
                    ),
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
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: trailing,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileOtherUserScreen(userId: user.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required Icon icon,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return isLoading
        ? const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7A5AF8)),
      ),
    )
        : IconButton(
      icon: icon,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Future<void> _sendFriendRequest(String friendId) async {
    setState(() => _actionLoading[friendId] = true);
    try {
      final response = await _friendService.request(friendId);
      if (response['statusCode'] == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande d\'ami envoyée avec succès'),
            backgroundColor: const Color(0xFF7A5AF8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Erreur lors de l\'envoi de la demande'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _logger.e('Erreur lors de l\'envoi de la demande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur inattendue lors de l\'envoi de la demande'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _actionLoading.remove(friendId));
    }
  }

  Future<void> _acceptRequest(String friendId) async {
    setState(() => _actionLoading[friendId] = true);
    try {
      final response = await _friendService.accept(friendId);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande d\'ami acceptée'),
            backgroundColor: const Color(0xFF7A5AF8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Erreur lors de l\'acceptation'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _logger.e('Erreur lors de l\'acceptation de la demande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur inattendue lors de l\'acceptation'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _actionLoading.remove(friendId));
    }
  }

  Future<void> _rejectRequest(String friendId) async {
    setState(() => _actionLoading[friendId] = true);
    try {
      final response = await _friendService.reject(friendId);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande d\'ami rejetée'),
            backgroundColor: const Color(0xFF7A5AF8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Erreur lors du rejet'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _logger.e('Erreur lors du rejet de la demande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur inattendue lors du rejet'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _actionLoading.remove(friendId));
    }
  }

  Future<void> _cancelRequest(String friendId) async {
    setState(() => _actionLoading[friendId] = true);
    try {
      final response = await _friendService.cancel(friendId);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande d\'ami annulée'),
            backgroundColor: const Color(0xFF7A5AF8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Erreur lors de l\'annulation'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _logger.e('Erreur lors de l\'annulation de la demande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur inattendue lors de l\'annulation'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _actionLoading.remove(friendId));
    }
  }

  Future<void> _removeFriend(String friendId) async {
    setState(() => _actionLoading[friendId] = true);
    try {
      final response = await _friendService.remove(friendId);
      if (response['statusCode'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ami supprimé avec succès'),
            backgroundColor: const Color(0xFF7A5AF8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Erreur lors de la suppression'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _logger.e('Erreur lors de la suppression de l\'ami: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur inattendue lors de la suppression'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _actionLoading.remove(friendId));
    }
  }
}