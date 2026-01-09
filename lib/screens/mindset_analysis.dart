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
  final TextEditingController _openEndedController = TextEditingController();
  
  // Total number of questions (25 questions - Q1 and Q2 combined into one)
  final int _totalQuestions = 25;

  @override
  void dispose() {
    _pageController.dispose();
    _openEndedController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalQuestions - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitAnalysis();
    }
  }

  void _previousPage() {
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
      return;
    }
    
    setState(() => _isLoading = true);
    print('✅ Loading state set to true');

    try {
      print('📝 Submitting answers: ${_answers.keys.toList()}');
      print('📝 Total answers: ${_answers.length}');
      
      print('🔥 Calling Firebase save...');
      final result = await MindsetAnalysisBackend.saveMindsetAnalysis(_answers);

      print('✅ Firebase save result: ${result['success']}');

      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }

      if (result['success']) {
        print('✅✅✅ FIREBASE SAVE SUCCESSFUL!');
        
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
            value: (_currentPage + 1) / _totalQuestions,
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
                  'Question ${_currentPage + 1} of $_totalQuestions',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4338CA),
                  ),
                ),
                Text(
                  '${((_currentPage + 1) / _totalQuestions * 100).toInt()}% Complete',
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
              children: _buildAllQuestions(),
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
                    onPressed: _canProceed() && !_isLoading ? _nextPage : null,
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
                        : Text(_currentPage == _totalQuestions - 1 ? 'Finish' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    final currentKey = 'q${_currentPage + 1}';
    final answer = _answers[currentKey];
    
    if (answer == null) return false;
    
    // For multi-select questions, check if at least one option is selected
    if (answer is List) {
      return answer.isNotEmpty;
    }
    
    // For text questions, check if not empty
    if (answer is String) {
      return answer.trim().isNotEmpty;
    }
    
    return true;
  }

  List<Widget> _buildAllQuestions() {
    return [
      // A. Study Reality & Time Investment
      _buildSingleChoiceQuestion(1, 'A. Study Reality & Time Investment', 
        'How many hours do you study per day and how consistent is your routine?',
        [
          'Less than 1 hour - Very inconsistent',
          '1–2 hours - Somewhat inconsistent', 
          '2–4 hours - Mostly consistent',
          'More than 4 hours - Very consistent'
        ], 'q1'),
      
      // Note: Q2 removed - study time and consistency combined into Q1
      
      // B. Clarity & Direction
      _buildSingleChoiceQuestion(2, 'B. Clarity & Direction',
        'When you sit down to study, how clear are you about what to study next?',
        ['Very clear', 'Somewhat clear', 'Often confused', 'Completely confused'], 'q3'),
      
      _buildMultipleChoiceQuestion(3, 'B. Clarity & Direction',
        'What usually makes you feel confused while planning what to study?',
        ['Too many resources', 'No clear roadmap', 'Conflicting advice', 'Fear of choosing the wrong topic', 'Too much syllabus'], 'q4'),
      
      _buildSingleChoiceQuestion(4, 'B. Clarity & Direction',
        'How often do you later feel you studied the wrong topic or wasted time?',
        ['Rarely', 'Sometimes', 'Often', 'Almost always'], 'q5'),
      
      // C. Retention & Forgetting
      _buildSingleChoiceQuestion(5, 'C. Retention & Forgetting',
        'How often do you forget topics you studied earlier?',
        ['Rarely', 'Sometimes', 'Often', 'Almost always'], 'q6'),
      
      _buildSingleChoiceQuestion(6, 'C. Retention & Forgetting',
        'When do you usually realize you\'ve forgotten something important?',
        ['During revision', 'During practice questions', 'During mock tests', 'In the main exam', 'When someone asks me'], 'q7'),
      
      _buildSingleChoiceQuestion(7, 'C. Retention & Forgetting',
        'What frustrates you the most when you forget something?',
        ['Forgetting formulas', 'Forgetting concepts', 'Knowing the concept but unable to apply it', 'Making silly mistakes'], 'q8'),
      
      // D. Practice & Application
      _buildSingleChoiceQuestion(8, 'D. Practice & Application',
        'Do you regularly practice questions while studying?',
        ['Yes, regularly', 'Sometimes', 'Rarely', 'Almost never'], 'q9'),
      
      _buildSingleChoiceQuestion(9, 'D. Practice & Application',
        'When you practice questions, what usually happens?',
        ['I solve most correctly', 'I understand solutions but can\'t solve independently', 'I struggle and feel stuck', 'I avoid practice altogether'], 'q10'),
      
      // E. Exam Emotions & Anxiety
      _buildSingleChoiceQuestion(10, 'E. Exam Emotions & Anxiety',
        'Before an important test or exam, what do you feel most?',
        ['Fear', 'Self-doubt', 'Panic', 'Motivation drop', 'Calm confidence'], 'q11'),
      
      _buildMultipleChoiceQuestion(11, 'E. Exam Emotions & Anxiety',
        'Even when you feel confident before a test, what still goes wrong?',
        ['Careless mistakes', 'Time management issues', 'Overthinking', 'Underestimating difficulty', 'Blanking out during the exam'], 'q12'),
      
      // F. Confidence & Recovery
      _buildSingleChoiceQuestion(12, 'F. Confidence & Recovery',
        'How confident are you with the core topics right now?',
        ['Very low', 'Low', 'Moderate', 'High', 'Very high'], 'q13'),
      
      _buildSingleChoiceQuestion(13, 'F. Confidence & Recovery',
        'After doing poorly in a test or study session, what usually happens?',
        ['I lose motivation for days', 'I struggle but continue', 'I recover after some time', 'I quickly adjust and continue', 'It motivates me to work harder'], 'q14'),
      
      _buildSingleChoiceQuestion(14, 'F. Confidence & Recovery',
        'After doing well in a test or mastering a topic, what usually happens next?',
        ['Reduce effort', 'Maintain consistency', 'Become overconfident', 'Become inconsistent', 'Push harder'], 'q15'),
      
      // G. Focus, Fatigue & Mental State
      _buildSingleChoiceQuestion(15, 'G. Focus, Fatigue & Mental State',
        'During long study sessions, what do you experience most often?',
        ['Stress', 'Boredom', 'Confusion', 'Fatigue', 'Motivation swings'], 'q16'),
      
      _buildSingleChoiceQuestion(16, 'G. Focus, Fatigue & Mental State',
        'When you feel bored, distracted, or mentally tired, what do you usually do?',
        ['Switch topics', 'Take a short break', 'Scroll social media', 'Stop studying for the day', 'Force myself to continue'], 'q17'),
      
      // H. Learning Behaviour & Habits
      _buildMultipleChoiceQuestion(17, 'H. Learning Behaviour & Habits',
        'Which of these do you do regularly while studying?',
        ['Read theory', 'Take notes', 'Practice problems', 'Revise within 48 hours', 'Teach or explain to someone'], 'q18'),
      
      _buildSingleChoiceQuestion(18, 'H. Learning Behaviour & Habits',
        'How often do you revise topics after first studying them?',
        ['Rarely', 'Occasionally', 'Regularly', 'Very systematically'], 'q19'),
      
      _buildSingleChoiceQuestion(19, 'H. Learning Behaviour & Habits',
        'How planned are your study sessions usually?',
        ['Completely unplanned', 'Rough idea only', 'Moderately planned', 'Well planned'], 'q20'),
      
      // I. Motivation & Obstacles
      _buildSingleChoiceQuestion(20, 'I. Motivation & Obstacles',
        'What keeps you studying when motivation is low?',
        ['Habit / routine', 'Fear of exams', 'Long-term goals', 'Support from others', 'Nothing really helps'], 'q21'),
      
      _buildSingleChoiceQuestion(21, 'I. Motivation & Obstacles',
        'What is the biggest obstacle to your learning right now?',
        ['Lack of time', 'Low motivation', 'Distractions', 'No clear plan', 'Poor guidance/resources'], 'q22'),
      
      // J. Reflection
      _buildTextQuestion(22, 'J. Reflection',
        'Describe one specific moment in the last 7 days when you felt your learning was going wrong.', 'q23'),
      
      _buildSingleChoiceQuestion(23, 'J. Reflection',
        'If your learning improved by just 20%, what would help you the most?',
        ['Clear roadmap', 'Better practice', 'More revision', 'Confidence building', 'Better time management'], 'q24'),
      
      _buildSingleChoiceQuestion(24, 'J. Reflection',
        'Overall, how satisfied are you with how you are studying right now?',
        ['Very dissatisfied', 'Dissatisfied', 'Neutral', 'Satisfied', 'Very satisfied'], 'q25'),
      
      _buildTextQuestion(25, 'J. Reflection',
        'What is one specific thing you want to improve about your learning in the next 30 days?', 'q26'),
    ];
  }

  Widget _buildSingleChoiceQuestion(int questionNumber, String category, String question, List<String> options, String answerKey) {
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
              category,
              style: const TextStyle(
                fontSize: 12,
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

  Widget _buildMultipleChoiceQuestion(int questionNumber, String category, String question, List<String> options, String answerKey) {
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
              category,
              style: const TextStyle(
                fontSize: 12,
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
          const SizedBox(height: 4),
          const Text(
            '(You can select multiple options)',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontStyle: FontStyle.italic,
            ),
          ),
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
        ]),
                  ),
                ),
              );
          }),
        ],
      ),
    );
  }

  Widget _buildTextQuestion(int questionNumber, String category, String question, String answerKey) {
    // Create controller if doesn't exist yet
    if (!_openEndedController.text.isNotEmpty && _answers[answerKey] != null) {
      _openEndedController.text = _answers[answerKey];
    }
    
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
              category,
              style: const TextStyle(
                fontSize: 12,
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
            controller: _openEndedController,
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
