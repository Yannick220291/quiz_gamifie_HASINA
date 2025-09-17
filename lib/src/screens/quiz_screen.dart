import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quiz_gamifie/src/models/quiz.dart';
import 'package:quiz_gamifie/src/models/question.dart';
import 'package:quiz_gamifie/src/models/answer.dart';
import 'package:quiz_gamifie/src/services/quiz_service.dart';
import 'package:get/get.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter/services.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final QuizService _quizService = QuizService();
  late final QuizController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(QuizController());
    controller.initQuiz(widget.quiz);
  }

  @override
  void dispose() {
    controller.timer?.cancel();
    Get.delete<QuizController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => controller.isQuizCompleted.value,
      child: Obx(() {
        if (controller.isLoading.value) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0x801A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF7A5AF8))),
            ),
          );
        }

        if (controller.isSubmitting.value) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0x801A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: const Color(0xFF7A5AF8),
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Envoi des résultats...',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (controller.isQuizCompleted.value) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0x801A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: GlassmorphicContainer(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 250,
                    borderRadius: 20,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 2,
                    linearGradient: LinearGradient(
                      colors: [Color(0xFF4A4A6A).withOpacity(0.2), Color(0xFF4A4A6A).withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: const LinearGradient(colors: [Colors.white24, Colors.white10]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Quiz Terminé : ${widget.quiz.title}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Niveau: ${widget.quiz.niveau}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Score: ${controller.score.value} XP',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        Text(
                          'Réponses correctes: ${controller.correctAnswers.value}/${controller.questions.length}',
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 24.0),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7A5AF8),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          ),
                          child: const Text(
                            'Retour',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
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

        if (controller.questions.isEmpty) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0x801A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Text(
                  'Aucune question disponible',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          );
        }

        final currentQuestion = controller.questions[controller.currentQuestionIndex.value];

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0x801A1A2E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          widget.quiz.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Niveau: ${widget.quiz.niveau}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TimerWidget(controller: controller),
                            _ScoreWidget(controller: controller),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Question ${controller.currentQuestionIndex.value + 1}/${controller.questions.length}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                            currentQuestion.text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (currentQuestion.timeLimit != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Temps: ${currentQuestion.timeLimit!} secondes',
                                style: const TextStyle(fontSize: 16, color: Color(0x801A1A2E)),
                              ),
                            ),
                          const SizedBox(height: 16.0),
                          Expanded(
                            child: Obx(() => ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: controller.answers[currentQuestion.id]?.length ?? 0,
                              itemBuilder: (context, index) {
                                if (controller.answers[currentQuestion.id] == null) {
                                  print("No answers for question ID: ${currentQuestion.id}");
                                  return const SizedBox.shrink();
                                }
                                final answer = controller.answers[currentQuestion.id]![index];
                                final isSelected = controller.userAnswers[controller.currentQuestionIndex.value] == answer.id;
                                final isAnswered = controller.userAnswers[controller.currentQuestionIndex.value] != null;

                                print("Question ${controller.currentQuestionIndex.value + 1}: isAnswered=$isAnswered, isSelected=$isSelected, answerId=${answer.id}, isCorrect=${answer.isCorrect}");

                                return Semantics(
                                  button: true,
                                  enabled: !isAnswered,
                                  label: isAnswered
                                      ? (answer.isCorrect ? "Option correcte" : "Option incorrecte")
                                      : "Option ${index + 1}",
                                  child: GestureDetector(
                                    onTap: isAnswered
                                        ? null
                                        : () {
                                      controller.submitAnswer(answer.id);
                                      setState(() {});
                                    },
                                    child: AnimatedContainer(
                                      key: ValueKey(answer.id),
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: isAnswered
                                            ? (answer.isCorrect
                                            ? const Color(0xFF4CAF50)
                                            : (isSelected ? const Color(0xFFF44336) : Colors.white))
                                            : Colors.white,
                                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                                        border: Border.all(
                                          color: isAnswered
                                              ? (answer.isCorrect
                                              ? const Color(0xFF4CAF50)
                                              : (isSelected ? const Color(0xFFF44336) : const Color(0xFF888888).withOpacity(0.5)))
                                              : const Color(0xFF888888).withOpacity(0.5),
                                          width: 1,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              answer.text,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: isAnswered && (isSelected || answer.isCorrect)
                                                    ? Colors.white
                                                    : const Color(0xFF1A1A2E),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          if (isAnswered)
                                            Icon(
                                              answer.isCorrect ? Icons.check_circle : Icons.cancel,
                                              color: isAnswered && (isSelected || answer.isCorrect)
                                                  ? Colors.white
                                                  : Colors.white,
                                              size: 24,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )),
                          ),
                          const SizedBox(height: 16.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class QuizController extends GetxController {
  final QuizService _quizService = QuizService();
  final questions = <Question>[].obs;
  final answers = <int, List<Answer>>{}.obs;
  final userAnswers = <int?>[].obs;
  final currentQuestionIndex = 0.obs;
  final score = 0.obs;
  final correctAnswers = 0.obs;
  final remainingTime = 0.obs;
  final isLoading = true.obs;
  final isQuizCompleted = false.obs;
  final isSubmitting = false.obs;
  Timer? timer;
  String? quizLevel;

  Future<void> initQuiz(Quiz quiz) async {
    quizLevel = quiz.niveau;
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        isLoading.value = true;
        final fetchedQuestions = await _quizService.getQuestionsForQuiz(quiz.id);
        questions.assignAll(fetchedQuestions..shuffle());
        userAnswers.assignAll(List<int?>.filled(fetchedQuestions.length, null));

        final answersByQuestion = await _quizService.getAnswersForQuiz(quiz.id);
        print("Answers fetched: $answersByQuestion");
        answers.assignAll(answersByQuestion);
        for (var question in questions) {
          answers[question.id]?.shuffle();
        }

        if (questions.isNotEmpty && questions[0].timeLimit != null) {
          remainingTime.value = questions[0].timeLimit!;
          startTimer();
        }
        break;
      } catch (e) {
        if (attempt == maxRetries) {
          if (Get.context != null) {
            ScaffoldMessenger.of(Get.context!).showSnackBar(
              SnackBar(content: Text('Erreur lors du chargement des questions: $e')),
            );
          }
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } finally {
        isLoading.value = false;
      }
    }
  }

  void startTimer() {
    timer?.cancel();
    if (currentQuestionIndex.value >= questions.length) return;
    final currentQuestion = questions[currentQuestionIndex.value];
    if (currentQuestion.timeLimit != null) {
      remainingTime.value = currentQuestion.timeLimit!;
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (remainingTime.value > 0) {
          remainingTime.value--;
        } else {
          t.cancel();
          submitAnswer(null);
        }
      });
    }
  }

  void submitAnswer(int? answerId) async {
    if (currentQuestionIndex.value >= questions.length || userAnswers[currentQuestionIndex.value] != null) return;

    print("Submitting answer: $answerId for question index: ${currentQuestionIndex.value}");
    final currentQuestion = questions[currentQuestionIndex.value];
    if (answerId != null) {
      final selectedAnswer = answers[currentQuestion.id]?.firstWhere((answer) => answer.id == answerId);
      print("Selected answer: id=${selectedAnswer?.id}, isCorrect=${selectedAnswer?.isCorrect}");
    }

    HapticFeedback.lightImpact();
    timer?.cancel();

    userAnswers[currentQuestionIndex.value] = answerId;
    if (answerId != null) {
      final selectedAnswer = answers[currentQuestion.id]!.firstWhere((answer) => answer.id == answerId);
      if (selectedAnswer.isCorrect) {
        int points = switch (quizLevel?.toLowerCase()) {
          'facile' => 10,
          'moyen' => 20,
          'difficile' => 30,
          _ => 10,
        };
        score.value += points;
        correctAnswers.value++;
        HapticFeedback.vibrate();
      } else {
        HapticFeedback.heavyImpact();
      }
    } else {
      HapticFeedback.heavyImpact();
    }
    userAnswers.refresh();
    update();

    await Future.delayed(const Duration(seconds: 2));
    if (currentQuestionIndex.value < questions.length - 1) {
      currentQuestionIndex.value++;
      if (questions[currentQuestionIndex.value].timeLimit != null) {
        remainingTime.value = questions[currentQuestionIndex.value].timeLimit!;
        startTimer();
      }
    } else {
      await submitQuiz();
    }
  }

  Future<void> submitQuiz() async {
    if (userAnswers.length != questions.length) {
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          const SnackBar(content: Text('Veuillez répondre à toutes les questions')),
        );
      }
      return;
    }

    try {
      isSubmitting.value = true;
      final responses = userAnswers.asMap().entries.map((e) {
        final questionId = questions[e.key].id;
        final answerId = e.value;
        final isCorrect = answerId != null
            ? answers[questionId]!.firstWhere((answer) => answer.id == answerId).isCorrect
            : false;
        return {
          'question_id': questionId,
          'answer_id': answerId,
          'is_correct': isCorrect,
        };
      }).toList();

      await _quizService.submitQuiz(questions[0].quizId, responses, quizLevel ?? 'facile');
      isSubmitting.value = false;
      isQuizCompleted.value = true;
    } catch (e) {
      isSubmitting.value = false;
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  void onClose() {
    timer?.cancel();
    super.onClose();
  }
}

class _TimerWidget extends StatelessWidget {
  final QuizController controller;

  const _TimerWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.questions.isEmpty || controller.currentQuestionIndex.value >= controller.questions.length) {
        return const SizedBox.shrink();
      }
      final currentQuestion = controller.questions[controller.currentQuestionIndex.value];
      if (currentQuestion.timeLimit == null) {
        return const SizedBox.shrink();
      }
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
              value: controller.remainingTime.value / currentQuestion.timeLimit!,
              backgroundColor: const Color(0xFF888888).withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7A5AF8)),
              strokeWidth: 6,
            ),
            Text(
              "${controller.remainingTime.value}s",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      );
    });
  }
}

class _ScoreWidget extends StatelessWidget {
  final QuizController controller;

  const _ScoreWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Text(
      "XP: ${controller.score.value}",
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    ));
  }
}