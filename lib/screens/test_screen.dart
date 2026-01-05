import 'package:flutter/material.dart';
import 'package:eduai/models/test_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// TestScreen - Displays test/assessment and tracks progress
class TestScreen extends StatefulWidget {
  final String courseName;
  final String topicName;
  final String difficulty;

  const TestScreen({
    super.key,
    required this.courseName,
    required this.topicName,
    required this.difficulty,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Map<String, dynamic>>? _questions;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _userAnswers = {};
  Map<String, dynamic>? _testResults;
  bool _testCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadTest();
  }

  Future<void> _loadTest() async {
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
            .collection('tests')
            .doc('${widget.courseName}_${widget.topicName}');

        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          final data = docSnap.data()!;
          setState(() {
            _questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);
            _testCompleted = data['completed'] ?? false;
            if (_testCompleted) {
              _testResults = {
                'score': data['score'],
                'correct': data['correctAnswers'],
                'total': data['totalQuestions'],
                'passed': data['passed'],
                'results': data['results'],
              };
            }
            _isLoading = false;
          });
          return;
        }
      }

      // Generate new test
      final result = await TestBackend.generateTest(
        topicName: widget.topicName,
        courseName: widget.courseName,
        difficulty: widget.difficulty,
        numberOfQuestions: 10,
        userLevel: 'intermediate',
      );

      if (result['success'] == true) {
        setState(() {
          _questions = List<Map<String, dynamic>>.from(result['questions'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to generate test';
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

  Future<void> _submitTest() async {
    if (_questions == null || _questions!.isEmpty) return;

    // Check if all questions are answered
    final unanswered = _questions!.where((q) {
      final questionId = q['id']?.toString() ?? q['question'];
      return _userAnswers[questionId.toString()] == null ||
          _userAnswers[questionId.toString()]!.isEmpty;
    }).toList();

    if (unanswered.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please answer all ${unanswered.length} remaining question(s)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await TestBackend.submitTestResults(
        topicName: widget.topicName,
        courseName: widget.courseName,
        answers: _userAnswers,
        questions: _questions!,
      );

      if (result['success'] == true) {
        setState(() {
          _testResults = result;
          _testCompleted = true;
          _isSubmitting = false;
        });

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(
                result['passed'] == true ? '🎉 Test Passed!' : 'Test Completed',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score: ${result['score']}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: result['passed'] == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Correct: ${result['correct']}/${result['total']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (result['passed'] == true)
                    const Text(
                      'Great job! Your progress has been updated in the roadmap.',
                      style: TextStyle(color: Colors.green),
                    )
                  else
                    const Text(
                      'Keep practicing! You can retake this test anytime.',
                      style: TextStyle(color: Colors.orange),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      // Reload to show results
                    });
                  },
                  child: const Text('View Results'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          _isSubmitting = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to submit test'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              'Generating test...',
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
                onPressed: _loadTest,
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

    if (_questions == null || _questions!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No test available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTest,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Show results if test is completed
    if (_testCompleted && _testResults != null) {
      return _buildResultsView();
    }

    // Show test questions
    return Column(
      children: [
        // Header with progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test: ${widget.topicName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_userAnswers.length}/${_questions!.length} answered',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTest,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Questions list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions!.length,
            itemBuilder: (context, index) {
              final question = _questions![index];
              final questionId = question['id']?.toString() ?? question['question'];
              final userAnswer = _userAnswers[questionId.toString()];

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
                              'Question ${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          if (userAnswer != null) ...[
                            const Spacer(),
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        question['question'] ?? 'No question',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Multiple choice questions
                      if (question['type'] == 'multiple_choice' &&
                          question['options'] != null)
                        ...List.generate(
                          (question['options'] as List).length,
                          (optionIndex) {
                            final option = (question['options'] as List)[optionIndex];
                            final isSelected = userAnswer == option.toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _userAnswers[questionId.toString()] =
                                        option.toString();
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6366F1).withOpacity(0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF6366F1)
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? const Color(0xFF6366F1)
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
                        )
                      // Short answer or calculation questions
                      else if (question['type'] == 'short_answer' || 
                               question['type'] == 'calculation')
                        TextField(
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
                            fillColor: Colors.grey[50],
                          ),
                          onChanged: (value) {
                            setState(() {
                              _userAnswers[questionId.toString()] = value;
                            });
                          },
                        ),
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

  Widget _buildResultsView() {
    final results = _testResults!['results'] as List<dynamic>? ?? [];
    final score = _testResults!['score'] as int;
    final passed = _testResults!['passed'] as bool;

    return Column(
      children: [
        // Results header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: passed
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
          child: Column(
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.info,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                passed ? 'Test Passed!' : 'Test Completed',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: $score%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_testResults!['correct']}/${_testResults!['total']} correct',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        // Detailed results
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final isCorrect = result['isCorrect'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCorrect ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Question ${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result['question'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Answer: ${result['userAnswer']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCorrect ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Correct Answer: ${result['correctAnswer']}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (result['explanation'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result['explanation'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              height: 1.5,
                            ),
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
}

