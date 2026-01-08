import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduai/models/course_selection_backend.dart';
import 'package:eduai/models/roadmap_backend.dart';
import 'package:eduai/screens/roadmap_screen.dart';
import 'package:eduai/screens/exam_level_assessment.dart';

class CourseQuestionnaireScreen extends StatefulWidget {
  final String courseName;
  final IconData courseIcon;
  final Color courseColor;

  const CourseQuestionnaireScreen({
    super.key,
    required this.courseName,
    required this.courseIcon,
    required this.courseColor,
  });

  @override
  State<CourseQuestionnaireScreen> createState() =>
      _CourseQuestionnaireScreenState();
}

class _CourseQuestionnaireScreenState extends State<CourseQuestionnaireScreen> {
  final Map<String, String> _answers = {};
  int _currentPage = 0;
  final PageController _pageController = PageController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Why do you want to pursue this exam?',
      'key': 'q1',
      'options': [
        'Career opportunity',
        'Family pressure',
        'Good salary',
        'Personal interest',
        'Social status',
      ],
    },
    {
      'question': 'What do you know about this exam?',
      'key': 'q2',
      'options': [
        'Everything about it',
        'Basic knowledge',
        'Only heard about it',
        'Not much',
      ],
    },
    {
      'question': 'What opportunities excite you most about this field?',
      'key': 'q3',
      'options': [
        'Job security',
        'Growth potential',
        'Making a difference',
        'Financial independence',
        'Work-life balance',
      ],
    },
    {
      'question': 'How much time can you dedicate daily for preparation?',
      'key': 'q4',
      'options': [
        'Less than 1 hour',
        '1-2 hours',
        '3-4 hours',
        '5-6 hours',
        'More than 6 hours',
      ],
    },
    {
      'question': 'When are you planning to take this exam?',
      'key': 'q5',
      'options': [
        'Within 6 months',
        '6 months to 1 year',
        '1-2 years',
        'More than 2 years',
        'Not sure yet',
      ],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitAnswers();
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

  Future<void> _submitAnswers() async {
    setState(() => _isLoading = true);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Analyzing your responses...'),
          ],
        ),
        duration: const Duration(seconds: 15),
        backgroundColor: widget.courseColor,
      ),
    );

    try {
      final result = await CourseSelectionBackend.saveCourseSelection(
        courseName: widget.courseName,
        answers: _answers,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success']) {
        final insights = result['insights'] as String?;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: widget.courseColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your Course Path',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.courseColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.courseColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.courseIcon,
                          color: widget.courseColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.courseName.split('(')[0].trim(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.courseColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (insights != null && insights.isNotEmpty) ...[
                    const Text(
                      'AI Insights for You:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      insights,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'We\'ve saved your course selection and will create a personalized learning path for you!',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Close dialog
                  Navigator.of(context).pop();
                  
                  // Navigate to level assessment screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExamLevelAssessmentScreen(
                        courseName: widget.courseName,
                        courseIcon: widget.courseIcon,
                        courseColor: widget.courseColor,
                      ),
                    ),
                  );
                },
                child: Text(
                  'Continue to Assessment',
                  style: TextStyle(
                    color: widget.courseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save selection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: widget.courseColor,
        elevation: 0,
        title: Text(
          widget.courseName.split('(')[0].trim(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              Container(
                color: widget.courseColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentPage + 1} of ${_questions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${((_currentPage + 1) / _questions.length * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _questions.length,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              // Questions
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    return _buildQuestionPage(_questions[index]);
                  },
                ),
              ),
              // Navigation buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: widget.courseColor),
                          ),
                          child: Text(
                            'Previous',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.courseColor,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _currentPage > 0 ? 1 : 2,
                      child: ElevatedButton(
                        onPressed: _canProceed()
                            ? _nextPage
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.courseColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: Text(
                          _currentPage < _questions.length - 1 ? 'Next' : 'Submit',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> question) {
    final questionKey = question['key'] as String;
    final options = question['options'] as List<String>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            question['question'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 32),
          ...options.map((option) => _buildOptionCard(questionKey, option)),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String questionKey, String option) {
    final isSelected = _answers[questionKey] == option;

    return GestureDetector(
      onTap: () {
        setState(() {
          _answers[questionKey] = option;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? widget.courseColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? widget.courseColor : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? widget.courseColor : Colors.white,
                border: Border.all(
                  color: isSelected ? widget.courseColor : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? widget.courseColor : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    final currentQuestion = _questions[_currentPage];
    return _answers.containsKey(currentQuestion['key']);
  }
}
