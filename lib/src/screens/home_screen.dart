import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:quiz_gamifie/src/models/category.dart';
import 'package:quiz_gamifie/src/screens/lobby_screen.dart';
import 'package:quiz_gamifie/src/screens/profile_screen.dart';
import 'package:quiz_gamifie/src/screens/quiz_list_screen.dart';
import 'package:quiz_gamifie/src/screens/friends_screen.dart';
import 'package:quiz_gamifie/src/screens/leaderboard_screen.dart';
import 'package:quiz_gamifie/src/screens/settings_screen.dart';
import 'package:quiz_gamifie/src/services/quiz_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final QuizService _quizService = QuizService();
  late Future<List<Category>> _categoriesFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  List<Category> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _quizService.getCategories();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCategories() async {
    setState(() {
      _categoriesFuture = _quizService.getCategories();
      _filteredCategories = [];
      _searchController.clear();
    });
    await _categoriesFuture;
    _animationController.reset();
    _animationController.forward();
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    _categoriesFuture.then((categories) {
      setState(() {
        _filteredCategories = categories
            .where((category) => category.name.toLowerCase().contains(query))
            .toList();
      });
    });
  }

  final List<Widget> _pages = [
    const Center(child: Text(
        'List des catégories des quiz', style: TextStyle(fontSize: 20))),
    const FriendsScreen(),
    const ProfileScreen(),
    const LobbyScreen(),
    const LeaderboardScreen(),
  ];

  void _onItemChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    _pages[0] = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            children: const [
              Icon(Icons.quiz, color: Color(0xFF7A5AF8), size: 28),
              SizedBox(width: 8),
              Text(
                'Catégories de Quiz',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
              hintText: 'Rechercher une catégorie...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7A5AF8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCategories,
            color: const Color(0xFF7A5AF8),
            backgroundColor: Colors.white,
            child: FutureBuilder<List<Category>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: Color(0xFF7A5AF8)));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur: ${snapshot.error}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  );
                }
                final categories = _searchController.text.isEmpty
                    ? snapshot.data ?? []
                    : _filteredCategories;
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QuizListScreen(
                                    categoryId: category.id,
                                    categoryName: category.name,
                                  ),
                            ),
                          ).then((_) {
                            _refreshCategories();
                          });
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Color(0xFF7A5AF8), width: 0.5),
                          ),
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF7A5AF8)
                                  .withOpacity(0.1),
                              child: const Icon(
                                  Icons.quiz, color: Color(0xFF7A5AF8)),
                            ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: category.description != null
                                ? Text(
                              category.description!,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            )
                                : Text(
                              'Voir les quiz de cette catégorie',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Color(0xFF7A5AF8)),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A5AF8),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        title: const Text(
          "ToQuiz",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.quiz, size: 30, color: Colors.white),
          Icon(Icons.people, size: 30, color: Colors.white),
          Icon(Icons.person, size: 30, color: Colors.white),
          Icon(Icons.sports_esports, size: 30, color: Colors.white),
          Icon(Icons.leaderboard, size: 30, color: Colors.white),
        ],
        color: const Color(0xFF7A5AF8),
        buttonBackgroundColor: const Color(0xFF7A5AF8),
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: _onItemChange,
      ),
    );
  }
}