import 'package:flutter/material.dart';
import 'package:eduai/models/practice_backend.dart';
import 'package:eduai/models/gamification_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// PracticeScreen - Displays practice problems for a topic
class PracticeScreen extends StatefulWidget {
  final String courseName;
  final String topicName;
  final String difficulty;

  const PracticeScreen({
    super.key,
    required this.courseName,
    required this.topicName,
    required this.difficulty,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<Map<String, dynamic>>? _problems;
  bool _isLoading = false;
  String? _errorMessage;
  Map<int, String?> _userAnswers = {};
  Map<int, bool> _showExplanation = {};
  Map<int, bool> _isLoadingHelp = {};
  Map<int, String?> _aiTutorHelp = {};

  @override
  void initState() {
    super.initState();
    _loadPracticeProblems();
  }

  Future<void> _loadPracticeProblems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check Firebase first
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('practiceProblems')
            .doc('${widget.courseName}_${widget.topicName}');

        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          final data = docSnap.data()!;
          setState(() {
            _problems = List<Map<String, dynamic>>.from(data['problems'] ?? []);
            _isLoading = false;
          });
          return;
        }
      }

      // Generate new practice problems
      final result = await PracticeBackend.generatePracticeProblems(
        topicName: widget.topicName,
        courseName: widget.courseName,
        difficulty: widget.difficulty,
        numberOfProblems: 5,
        userLevel: 'intermediate',
      );

      if (result['success'] == true) {
        setState(() {
          _problems = List<Map<String, dynamic>>.from(result['problems'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to generate practice problems';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _checkAnswer(int index, String answer) {
    setState(() {
      _userAnswers[index] = answer;
      _showExplanation[index] = true;
    });
    
    // Track practice activity for gamification
    GamificationBackend.updatePracticeActivity(1);
  }

  Future<void> _getAITutorHelp(int index) async {
    if (_problems == null || index >= _problems!.length) return;
    
    setState(() {
      _isLoadingHelp[index] = true;
      _aiTutorHelp[index] = null;
    });

    try {
      final problem = _problems![index];
      final userAnswer = _userAnswers[index];
      
      final result = await PracticeBackend.getAITutorHelp(
        problem: problem,
        topicName: widget.topicName,
        courseName: widget.courseName,
        userAnswer: userAnswer,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _aiTutorHelp[index] = result['help'] as String?;
          _isLoadingHelp[index] = false;
        });
        
        // Show AI tutor dialog
        _showAITutorDialog(index, result['help'] as String);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingHelp[index] = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to get AI tutor help'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHelp[index] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAITutorDialog(int index, String help) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.school, color: const Color(0xFF6366F1)),
            const SizedBox(width: 8),
            const Text('AI Tutor Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            help,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating practice problems...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPracticeProblems,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_problems == null || _problems!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No practice problems available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPracticeProblems,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate Practice Problems'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Instructions header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFF6366F1),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Practice Problems',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select an answer for each problem. Click any option to see the explanation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Problems list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _problems!.length,
            itemBuilder: (context, index) {
              final problem = _problems![index];
              final userAnswer = _userAnswers[index];
              final showExplanation = _showExplanation[index] ?? false;
              final isCorrect = userAnswer != null &&
                  userAnswer.trim().toLowerCase() ==
                      (problem['correctAnswer'] ?? '').toString().trim().toLowerCase();

              return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Problem ${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (problem['difficulty'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(problem['difficulty'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          problem['difficulty'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getDifficultyColor(problem['difficulty']),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        problem['question'] ?? 'No question',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // AI Tutor Help Button
                    InkWell(
                      onTap: userAnswer == null ? () => _getAITutorHelp(index) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isLoadingHelp[index] ?? false) 
                              ? Colors.grey[300]
                              : const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_isLoadingHelp[index] ?? false)
                                ? Colors.grey[400]!
                                : const Color(0xFF6366F1),
                            width: 1,
                          ),
                        ),
                        child: (_isLoadingHelp[index] ?? false)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.school,
                                    size: 16,
                                    color: Color(0xFF6366F1),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Help',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Multiple choice questions
                if (problem['type'] == 'multiple_choice' &&
                    problem['options'] != null)
                  ...List.generate(
                    (problem['options'] as List).length,
                    (optionIndex) {
                      final option = (problem['options'] as List)[optionIndex];
                      final isSelected = userAnswer == option.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: userAnswer == null
                              ? () => _checkAnswer(index, option.toString())
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isCorrect
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1))
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? (isCorrect
                                        ? Colors.green
                                        : Colors.red)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? (isCorrect
                                          ? Icons.check_circle
                                          : Icons.cancel)
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? (isCorrect
                                          ? Colors.green
                                          : Colors.red)
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF1E293B),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Short answer or calculation questions
                if (problem['type'] == 'short_answer' || 
                    problem['type'] == 'calculation')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        enabled: userAnswer == null,
                        controller: TextEditingController(
                          text: userAnswer ?? '',
                        )..selection = TextSelection.fromPosition(
                            TextPosition(offset: userAnswer?.length ?? 0),
                          ),
                        decoration: InputDecoration(
                          hintText: 'Enter your answer here',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: userAnswer != null
                              ? (isCorrect
                                  ? Colors.green.withOpacity(0.05)
                                  : Colors.red.withOpacity(0.05))
                              : Colors.grey[50],
                        ),
                        onChanged: userAnswer == null
                            ? (value) {
                                setState(() {
                                  _userAnswers[index] = value;
                                });
                              }
                            : null,
                        onSubmitted: userAnswer == null
                            ? (value) {
                                if (value.isNotEmpty) {
                                  _checkAnswer(index, value);
                                }
                              }
                            : null,
                      ),
                      if (userAnswer == null && 
                          _userAnswers[index] != null && 
                          _userAnswers[index]!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _checkAnswer(index, _userAnswers[index] ?? ''),
                            icon: const Icon(Icons.check),
                            label: const Text('Check Answer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (showExplanation) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.info,
                              color: isCorrect ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect ? 'Correct!' : 'Incorrect',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Correct Answer: ${problem['correctAnswer']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (problem['explanation'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            problem['explanation'],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
            },
          ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'hard':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

