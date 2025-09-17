import 'package:flutter/material.dart';
import 'package:quiz_gamifie/src/models/quiz.dart';
import 'package:quiz_gamifie/src/screens/quiz_screen.dart';
import 'package:quiz_gamifie/src/services/quiz_service.dart';

class QuizListScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const QuizListScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final QuizService _quizService = QuizService();
  late Future<List<Quiz>> _quizzesFuture;
  final List<String> _levels = ['Facile', 'Moyen', 'Difficile'];
  List<Quiz>? _cachedQuizzes;
  final Map<String, List<Quiz>> _filteredCache = {};

  @override
  void initState() {
    super.initState();
    _quizzesFuture = _fetchQuizzes();
  }

  Future<List<Quiz>> _fetchQuizzes() async {
    if (_cachedQuizzes != null) {
      return _cachedQuizzes!;
    }
    final quizzes = await _quizService.getAllQuizzes(categoryId: widget.categoryId);
    _cachedQuizzes = quizzes;
    _filteredCache.clear();
    return quizzes;
  }

  Future<void> _refreshQuizzes() async {
    setState(() {
      _cachedQuizzes = null;
      _filteredCache.clear();
      _quizzesFuture = _fetchQuizzes();
    });
    await _quizzesFuture;
  }

  List<Quiz> _filterQuizzesByLevel(List<Quiz> quizzes, String level) {
    if (_filteredCache[level] != null) {
      return _filteredCache[level]!;
    }
    final filtered = quizzes.where((quiz) => quiz.niveau.toLowerCase() == level.toLowerCase()).toList();
    _filteredCache[level] = filtered;
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _levels.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF7A5AF8),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          title: Text(
            'Quiz - ${widget.categoryName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _levels
                .map((level) => Tab(
              text: level,
            ))
                .toList(),
          ),
        ),
        body: FutureBuilder<List<Quiz>>(
          future: _quizzesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8)));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Erreur lors du chargement des quiz : ${snapshot.error}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final quizzes = snapshot.data ?? [];
            if (quizzes.isEmpty) {
              return Center(
                child: Text(
                  'Aucun quiz disponible dans cette catégorie',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              );
            }

            return TabBarView(
              children: _levels.map((level) {
                final filteredQuizzes = _filterQuizzesByLevel(quizzes, level);
                return RefreshIndicator(
                  onRefresh: _refreshQuizzes,
                  color: const Color(0xFF7A5AF8),
                  backgroundColor: Colors.white,
                  child: filteredQuizzes.isEmpty
                      ? Center(
                    child: Text(
                      'Aucun quiz disponible pour le niveau $level',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    itemCount: filteredQuizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = filteredQuizzes[index];
                      return Card(
                        key: Key(quiz.id.toString()),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF7A5AF8), width: 0.5),
                        ),
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            quiz.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Niveau: ${quiz.niveau}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                              if (quiz.description != null)
                                Text(
                                  quiz.description!,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF7A5AF8)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizScreen(quiz: quiz),
                              ),
                            ).then((_) {
                              _refreshQuizzes();
                            });
                          },
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}