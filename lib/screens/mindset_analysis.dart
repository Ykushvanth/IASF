import 'package:flutter/material.dart';
import 'package:eduai/models/mindset_analysis_backend.dart';
import 'package:eduai/screens/course_selection.dart';

class MindsetAnalysisScreen extends StatefulWidget {
  const MindsetAnalysisScreen({super.key});

  @override
  State<MindsetAnalysisScreen> createState() => _MindsetAnalysisScreenState();
}

class _MindsetAnalysisScreenState extends State<MindsetAnalysisScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  final Map<String, dynamic> _answers = {};
  final TextEditingController _q15Controller = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _q15Controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 2) {
      final q3Answer = _answers['q3'];
      if (q3Answer != 'Often confused' && q3Answer != 'Completely confused') {
        _answers.remove('q4');
        _pageController.jumpToPage(4);
        return;
      }
    }

    if (_currentPage < 14) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitAnalysis();
    }
  }

  void _previousPage() {
    if (_currentPage == 4) {
      final q3Answer = _answers['q3'];
      if (q3Answer != 'Often confused' && q3Answer != 'Completely confused') {
        _pageController.jumpToPage(2);
        return;
      }
    }

    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitAnalysis() async {
    print('🚀 _submitAnalysis CALLED!');
    
    if (_isLoading) {
      print('⚠️ Already loading, returning');
      return; // Prevent double submission
    }
    
    setState(() => _isLoading = true);
    print('✅ Loading state set to true');

    try {
      // Debug: Print answers to verify Q15 is captured
      print('📝 Submitting answers: ${_answers.keys.toList()}');
      print('📝 Q15 answer: ${_answers['q15']}');
      print('📝 Total answers: ${_answers.length}');
      
      // Save analysis to Firebase
      print('🔥 Calling Firebase save...');
      final result = await MindsetAnalysisBackend.saveMindsetAnalysis(_answers);

      print('✅ Firebase save result: ${result['success']}');

      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }

      if (result['success']) {
        print('✅✅✅ FIREBASE SAVE SUCCESSFUL!');
        
        // Show generating AI summary message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Generating AI insights...'),
                ],
              ),
              duration: Duration(seconds: 15),
              backgroundColor: Color(0xFF6366F1),
            ),
          );
        }
        
        print('🤖 Starting Groq API call...');
        
        // Get AI summary from Groq
        final summaryResult = await MindsetAnalysisBackend.summarizeWithGroq(
          _answers,
          result['profile'],
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('⏱️ Groq API timed out after 15s');
            return {
              'success': false,
              'message': 'AI summary is taking too long. Your analysis has been saved successfully.',
            };
          },
        );

        print('✅ Groq result: ${summaryResult['success']}');

        if (!mounted) {
          setState(() => _isLoading = false);
          return;
        }

        setState(() => _isLoading = false);

        if (summaryResult['success']) {
          ScaffoldMessenger.of(context).clearSnackBars();
          _showSummaryDialog(summaryResult['summary']);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Analysis saved! ${summaryResult['message'] ?? 'AI summary unavailable'}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to save analysis'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _submitAnalysis: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Still navigate back after error
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  void _showSummaryDialog(String summary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.psychology,
                color: Color(0xFF6366F1),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Your Learning Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4338CA),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI-Powered Analysis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This summary has been saved to your profile for future reference.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
              // Navigate to course selection
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseSelectionScreen(),
                ),
              );
            },
            child: const Text(
              'Choose Your Path',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mindset Analysis'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentPage + 1) / 15,
            backgroundColor: const Color(0xFFE0E7FF),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentPage + 1} of 15',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4338CA),
                  ),
                ),
                Text(
                  '${((_currentPage + 1) / 15 * 100).toInt()}% Complete',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildQuestion1(),
                _buildQuestion2(),
                _buildQuestion3(),
                _buildQuestion4(),
                _buildQuestion5(),
                _buildQuestion6(),
                _buildQuestion7(),
                _buildQuestion8(),
                _buildQuestion9(),
                _buildQuestion10(),
                _buildQuestion11(),
                _buildQuestion12(),
                _buildQuestion13(),
                _buildQuestion14(),
                _buildQuestion15(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF6366F1), width: 2),
                        foregroundColor: const Color(0xFF6366F1),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  flex: _currentPage > 0 ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: _isCanAnswerQuestion() && !_isLoading ? _nextPage : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_currentPage == 14 ? 'Finish' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isCanAnswerQuestion() {
    switch (_currentPage) {
      case 0:
        return _answers['q1'] != null;
      case 1:
        return _answers['q2'] != null;
      case 2:
        return _answers['q3'] != null;
      case 3:
        if (_answers['q3'] == 'Often confused' || _answers['q3'] == 'Completely confused') {
          return _answers['q4'] != null && (_answers['q4'] as List).isNotEmpty;
        }
        return true;
      case 4:
        return _answers['q5'] != null;
      case 5:
        return _answers['q6'] != null;
      case 6:
        return _answers['q7'] != null;
      case 7:
        return _answers['q8'] != null;
      case 8:
        return _answers['q9'] != null;
      case 9:
        return _answers['q10'] != null;
      case 10:
        return _answers['q11'] != null;
      case 11:
        return _answers['q12'] != null;
      case 12:
        return _answers['q13'] != null;
      case 13:
        return _answers['q14'] != null;
      case 14:
        return _answers['q15'] != null && _answers['q15'].toString().trim().isNotEmpty;
      default:
        return false;
    }
  }

  Widget _buildQuestion1() {
    return _buildSingleChoiceQuestion(
      questionNumber: 1,
      question: 'How many hours do you actually study per day on average?',
      options: ['Less than 1 hour', '1–2 hours', '2–4 hours', 'More than 4 hours'],
      answerKey: 'q1',
    );
  }

  Widget _buildQuestion2() {
    return _buildSingleChoiceQuestion(
      questionNumber: 2,
      question: 'When you sit down to study, how clear are you about what to study next?',
      options: ['Very clear', 'Somewhat clear', 'Often confused', 'Completely confused'],
      answerKey: 'q2',
    );
  }

  Widget _buildQuestion3() {
    return _buildSingleChoiceQuestion(
      questionNumber: 3,
      question: 'When you sit down to study, how clear are you about what to study next?',
      options: ['Very clear', 'Somewhat clear', 'Often confused', 'Completely confused'],
      answerKey: 'q3',
    );
  }

  Widget _buildQuestion4() {
    return _buildMultipleChoiceQuestion(
      questionNumber: 4,
      question: 'What things are hard for you and make you feel confused?',
      subtitle: '(You can select multiple options)',
      options: [
        'Too many resources',
        'No clear roadmap',
        'Conflicting advice',
        'Fear of choosing the wrong topic',
        'Too much syllabus',
      ],
      answerKey: 'q4',
    );
  }

  Widget _buildQuestion5() {
    return _buildSingleChoiceQuestion(
      questionNumber: 5,
      question: 'How often do you feel you studied the wrong topic or wasted time later?',
      options: ['Rarely', 'Sometimes', 'Often', 'Almost always'],
      answerKey: 'q5',
    );
  }

  Widget _buildQuestion6() {
    return _buildSingleChoiceQuestion(
      questionNumber: 6,
      question: 'How often do you forget topics you studied earlier?',
      options: ['Rarely', 'Sometimes', 'Often', 'Almost always'],
      answerKey: 'q6',
    );
  }

  Widget _buildQuestion7() {
    return _buildSingleChoiceQuestion(
      questionNumber: 7,
      question: 'When do you usually realize you\'ve forgotten something important?',
      options: [
        'During revision',
        'During practice questions',
        'During mock tests',
        'In the main exam',
        'When someone asks me',
      ],
      answerKey: 'q7',
    );
  }

  Widget _buildQuestion8() {
    return _buildSingleChoiceQuestion(
      questionNumber: 8,
      question: 'What frustrates you the most when you forget something?',
      options: [
        'Forgetting formulas',
        'Forgetting concepts',
        'Knowing the concept but unable to apply',
        'Making silly mistakes',
      ],
      answerKey: 'q8',
    );
  }

  Widget _buildQuestion9() {
    return _buildSingleChoiceQuestion(
      questionNumber: 9,
      question: 'Do you regularly practice questions while studying?',
      options: ['Yes', 'No'],
      answerKey: 'q9',
    );
  }

  Widget _buildQuestion10() {
    return _buildSingleChoiceQuestion(
      questionNumber: 10,
      question: 'Before an important test or exam, what do you feel most?',
      options: ['Fear', 'Self-doubt', 'Panic', 'Motivation drop'],
      answerKey: 'q10',
    );
  }

  Widget _buildQuestion11() {
    return _buildSingleChoiceQuestion(
      questionNumber: 11,
      question: 'Even when you feel confident before a test, what still goes wrong?',
      options: [
        'Careless mistakes',
        'Time management issues',
        'Overthinking',
        'Underestimating difficulty',
        'Blanking out during the exam',
      ],
      answerKey: 'q11',
    );
  }

  Widget _buildQuestion12() {
    return _buildSingleChoiceQuestion(
      questionNumber: 12,
      question: 'After doing well in a test or mastering a topic, what usually happens next?',
      options: [
        'Reduce effort',
        'Maintain consistency',
        'Over-confidence',
        'Become inconsistent',
        'Push harder',
      ],
      answerKey: 'q12',
    );
  }

  Widget _buildQuestion13() {
    return _buildSingleChoiceQuestion(
      questionNumber: 13,
      question: 'During long study sessions, what do you experience most often?',
      options: ['Stress', 'Boredom', 'Confusion', 'Fatigue', 'Motivation swings'],
      answerKey: 'q13',
    );
  }

  Widget _buildQuestion14() {
    return _buildSingleChoiceQuestion(
      questionNumber: 14,
      question: 'When you feel bored, distracted, or mentally tired while studying, what do you usually do?',
      options: [
        'Switch topics',
        'Take a break',
        'Scroll social media',
        'Stop studying',
        'Force myself to continue',
      ],
      answerKey: 'q14',
    );
  }

  Widget _buildQuestion15() {
    return _buildTextQuestion(
      questionNumber: 15,
      question: 'Describe one specific moment in the last 7 days when you felt your learning was going wrong.',
      answerKey: 'q15',
    );
  }

  Widget _buildSingleChoiceQuestion({
    required int questionNumber,
    required String question,
    required List<String> options,
    required String answerKey,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Q$questionNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4338CA),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...options.map((option) {
            final isSelected = _answers[answerKey] == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _answers[answerKey] = option;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceQuestion({
    required int questionNumber,
    required String question,
    String? subtitle,
    required List<String> options,
    required String answerKey,
  }) {
    if (_answers[answerKey] == null) {
      _answers[answerKey] = <String>[];
    }
    final selectedOptions = _answers[answerKey] as List<String>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Q$questionNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4338CA),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...options.map((option) {
            final isSelected = selectedOptions.contains(option);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedOptions.remove(option);
                    } else {
                      selectedOptions.add(option);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextQuestion({
    required int questionNumber,
    required String question,
    required String answerKey,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Q$questionNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4338CA),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _q15Controller,
            maxLines: 8,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Share your experience here...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
            ),
            onChanged: (value) {
              setState(() {
                _answers[answerKey] = value;
              });
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Be honest and specific. This helps us personalize your learning experience.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
