import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eduai/models/level_assessment_backend.dart';
import 'package:eduai/screens/roadmap_screen.dart';
import 'package:eduai/models/roadmap_backend.dart';
import 'package:lottie/lottie.dart';

class ExamLevelAssessmentScreen extends StatefulWidget {
  final String courseName;
  final IconData courseIcon;
  final Color courseColor;

  const ExamLevelAssessmentScreen({
    super.key,
    required this.courseName,
    required this.courseIcon,
    required this.courseColor,
  });

  @override
  State<ExamLevelAssessmentScreen> createState() => _ExamLevelAssessmentScreenState();
}

class _ExamLevelAssessmentScreenState extends State<ExamLevelAssessmentScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _knowsExam = false;
  List<String> _selectedTopics = [];
  List<Map<String, dynamic>> _assessmentQuestions = [];
  Map<String, String> _answers = {};
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  String _userLevel = '';
  List<String> _improvementAreas = [];
  int _studyHoursPerDay = 0;
  int _daysUntilExam = 0;
  bool _showingAnswerFeedback = false;
  bool _isAnswerCorrect = false;
  int _currentQuestionIndex = 0;
  Map<String, String>? _mindsetProfile;

  // Topics for different exams (can be expanded)
  final Map<String, List<String>> _examTopics = {
    'JEE (Joint Entrance Examination)': [
      'Physics - Mechanics',
      'Physics - Electromagnetism',
      'Physics - Thermodynamics',
      'Chemistry - Organic',
      'Chemistry - Inorganic',
      'Chemistry - Physical',
      'Mathematics - Calculus',
      'Mathematics - Algebra',
      'Mathematics - Coordinate Geometry',
      'Mathematics - Vectors & 3D',
    ],
    'NEET (National Eligibility cum Entrance Test)': [
      'Physics - Mechanics',
      'Physics - Optics',
      'Chemistry - Organic',
      'Chemistry - Inorganic',
      'Biology - Botany',
      'Biology - Zoology',
      'Biology - Human Physiology',
      'Biology - Genetics',
    ],
    'UPSC (Union Public Service Commission)': [
      'History - Ancient India',
      'History - Modern India',
      'Geography - Physical',
      'Geography - Economic',
      'Polity & Governance',
      'Economics',
      'Current Affairs',
      'Ethics & Integrity',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadMindsetProfile();
  }

  Future<void> _loadMindsetProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final rawAnswers = userDoc.data()?['mindsetAnswers'] ?? {};
        final mindsetAnswers = <String, String>{};
        
        if (rawAnswers is Map) {
          rawAnswers.forEach((key, value) {
            if (value is String) {
              mindsetAnswers[key.toString()] = value;
            } else if (value is List) {
              mindsetAnswers[key.toString()] = value.join(', ');
            } else {
              mindsetAnswers[key.toString()] = value.toString();
            }
          });
        }
        
        setState(() {
          _mindsetProfile = mindsetAnswers;
        });
      }
    } catch (e) {
      print('Error loading mindset profile: $e');
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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: widget.courseColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Generating personalized questions...',
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : _buildCurrentStep(),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildUnifiedAssessmentFlow();
      case 1:
        return _buildComprehensiveResults();
      case 2:
        return _buildStudyPlanStep();
      default:
        return Container();
    }
  }

  // Unified Assessment Flow - Mix of Static and AI Questions
  Widget _buildUnifiedAssessmentFlow() {
    if (_assessmentQuestions.isEmpty) {
      // Initialize assessment on first load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeAssessment();
      });
      return const Center(child: CircularProgressIndicator());
    }

    final question = _assessmentQuestions[_currentQuestionIndex];

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.courseColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assessment Progress',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.courseColor,
                          ),
                        ),
                        Text(
                          '${_currentQuestionIndex + 1}/${_assessmentQuestions.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.courseColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / _assessmentQuestions.length,
                      backgroundColor: widget.courseColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.courseColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Question type badge - All questions are now AI-personalized
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI-Analyzed Question',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Question
              Text(
                question['question'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Options
              ...(question['options'] as List<String>).asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final optionLabel = String.fromCharCode(65 + index); // A, B, C, D
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _handleAnswerSelection(
                      question['id'],
                      option,
                      question['correctAnswer'],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: widget.courseColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                optionLabel,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.courseColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF475569),
                                height: 1.4,
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
        ),
        if (_showingAnswerFeedback) _buildAnswerFeedbackOverlay(),
      ],
    );
  }

  // Step 0: Exam Knowledge
  Widget _buildExamKnowledgeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 64, color: widget.courseColor),
          const SizedBox(height: 24),
          Text(
            'How familiar are you with ${widget.courseName.split('(')[0].trim()}?',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 32),
          _buildOptionCard(
            'Yes, I know the exam well',
            'I understand the structure and topics',
            Icons.check_circle,
            true,
            () {
              setState(() {
                _knowsExam = true;
                _currentStep = 1;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildOptionCard(
            'Not really',
            'I need guidance and a clear roadmap',
            Icons.school,
            false,
            () async {
              setState(() {
                _knowsExam = false;
                _isLoading = true;
              });
              await _skipToStudyPlan();
            },
          ),
        ],
      ),
    );
  }

  // Step 1: Topic Selection
  Widget _buildTopicSelectionStep() {
    final topics = _examTopics[widget.courseName] ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which topics do you already know?',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all topics you\'ve studied or are familiar with',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          ...topics.map((topic) {
            final isSelected = _selectedTopics.contains(topic);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTopics.remove(topic);
                    } else {
                      _selectedTopics.add(topic);
                    }
                  });
                },
                child: Container(
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
                      Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isSelected ? widget.courseColor : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          topic,
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
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedTopics.isNotEmpty
                  ? () async {
                      setState(() => _isLoading = true);
                      await _generateAssessmentQuestions();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.courseColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text(
                'Continue to Assessment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Assessment Questions
  Widget _buildAssessmentQuestionsStep() {
    if (_assessmentQuestions.isEmpty) {
      return const Center(child: Text('No questions available'));
    }

    final currentQuestionIndex = _answers.length;
    if (currentQuestionIndex >= _assessmentQuestions.length) {
      // All questions answered, move to results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateLevel();
      });
      return const Center(child: CircularProgressIndicator());
    }

    final question = _assessmentQuestions[currentQuestionIndex];

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: currentQuestionIndex / _assessmentQuestions.length,
                backgroundColor: widget.courseColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(widget.courseColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Question ${currentQuestionIndex + 1} of ${_assessmentQuestions.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                question['question'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ...(question['options'] as List<String>).map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _handleAnswerSelection(
                      question['id'],
                      option,
                      question['correctAnswer'],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
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
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF475569),
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
        ),
        if (_showingAnswerFeedback) _buildAnswerFeedbackOverlay(),
      ],
    );
  }

  Widget _buildAnswerFeedbackOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnswerCorrect)
              Lottie.asset(
                'assets/animations/Done _ Correct _ Tick.json',
                width: 200,
                height: 200,
                repeat: false,
                fit: BoxFit.contain,
              )
            else
              Lottie.asset(
                'assets/animations/Error Animation.json',
                width: 200,
                height: 200,
                repeat: false,
                fit: BoxFit.contain,
              ),
            const SizedBox(height: 24),
            Text(
              _isAnswerCorrect ? 'Correct!' : 'Incorrect',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _isAnswerCorrect ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Level Results
  Widget _buildLevelResultsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.courseColor, widget.courseColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Your Level',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _userLevel,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Correct',
                        _correctAnswers.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Wrong',
                        _wrongAnswers.toString(),
                        Colors.red,
                        Icons.cancel,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_improvementAreas.isNotEmpty) ...[
            const Text(
              'Areas to Improve',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            ..._improvementAreas.map((area) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          area,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 4);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.courseColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create My Study Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Study Plan Details
  Widget _buildStudyPlanStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Let\'s plan your study schedule',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'How many hours can you study per day?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [1, 2, 3, 4, 5, 6, 8].map((hours) {
              final isSelected = _studyHoursPerDay == hours;
              return ChoiceChip(
                label: Text('$hours hrs'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _studyHoursPerDay = hours;
                  });
                },
                selectedColor: widget.courseColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            'How many days until your exam?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [30, 60, 90, 180, 365].map((days) {
              final isSelected = _daysUntilExam == days;
              String label;
              if (days < 60) {
                label = '$days days';
              } else if (days < 365) {
                label = '${(days / 30).round()} months';
              } else {
                label = '1 year';
              }
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _daysUntilExam = days;
                  });
                },
                selectedColor: widget.courseColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_studyHoursPerDay > 0 && _daysUntilExam > 0)
                  ? () async {
                      await _saveAndGenerateRoadmap();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.courseColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text(
                'Generate My Personalized Roadmap',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String title, String subtitle, IconData icon, bool primary, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: primary ? widget.courseColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? widget.courseColor : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 48,
              color: primary ? widget.courseColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary ? widget.courseColor : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: primary ? widget.courseColor : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // Logic methods
  Future<void> _initializeAssessment() async {
    setState(() => _isLoading = true);

    try {
      // Generate 10 AI-analyzed questions based on user's mindset profile
      final aiQuestions = await _generateAIQuestions();
      
      print('📊 Generated ${aiQuestions.length} questions');
      
      setState(() {
        _assessmentQuestions = aiQuestions.take(10).toList();
        _currentQuestionIndex = 0; // Reset to first question
        _isLoading = false;
      });
      
      print('✅ Assessment initialized with ${_assessmentQuestions.length} questions');
    } catch (e) {
      print('❌ Error initializing assessment: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate assessment questions. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _generateAIQuestions() async {
    try {
      // Get all topics for this exam
      final allTopics = _examTopics[widget.courseName] ?? [];
      
      if (allTopics.isEmpty) {
        print('⚠️ No topics found, using fallback questions');
        return _getFallbackAIQuestions();
      }

      print('🔄 Generating questions for ${allTopics.length} topics');
      final result = await LevelAssessmentBackend.generateQuestions(
        courseName: widget.courseName,
        selectedTopics: allTopics.take(5).toList(), // Use first 5 topics
        mindsetProfile: _mindsetProfile, // Pass user's mindset profile for personalized assessment
      );

      if (result['success'] == true) {
        final questions = List<Map<String, dynamic>>.from(result['questions'] ?? []);
        print('✅ Received ${questions.length} questions from API');
        
        // Ensure we have at least 10 questions
        if (questions.length >= 10) {
          // Mark as AI-generated
          for (var q in questions) {
            q['isStatic'] = false;
          }
          return questions.take(10).toList(); // Return exactly 10 questions
        } else {
          print('⚠️ Only ${questions.length} questions received, using fallback for remaining');
          // Combine API questions with fallback to reach 10
          final fallback = _getFallbackAIQuestions();
          final combined = <Map<String, dynamic>>[];
          combined.addAll(questions);
          combined.addAll(fallback.skip(questions.length).take(10 - questions.length));
          
          for (var q in combined) {
            q['isStatic'] = false;
          }
          return combined.take(10).toList();
        }
      } else {
        print('⚠️ API returned success=false, using fallback');
      }
    } catch (e) {
      print('❌ Error generating AI questions: $e');
    }
    
    print('🔄 Using fallback questions');
    return _getFallbackAIQuestions();
  }

  List<Map<String, dynamic>> _getFallbackAIQuestions() {
    // Generate 10 fallback questions if AI fails
    final topics = _examTopics[widget.courseName] ?? ['General Knowledge'];
    final topicList = topics.length >= 10 ? topics : List.generate(10, (i) => topics[i % topics.length]);
    
    return List.generate(10, (index) {
      final topic = topicList[index];
      return {
        'id': 'fallback_${index + 1}',
        'question': 'Question ${index + 1}: What is a fundamental concept in $topic?',
        'options': [
          'Option A - Core principle',
          'Option B - Advanced theory',
          'Option C - Intermediate concept',
          'Option D - Basic definition'
        ],
        'correctAnswer': 'Option A - Core principle',
        'topic': topic,
        'difficulty': index < 3 ? 'easy' : (index < 7 ? 'medium' : 'hard'),
        'isStatic': false,
      };
    });
  }

  void _handleAnswerSelection(String questionId, String selectedAnswer, String correctAnswer) {
    final isCorrect = selectedAnswer == correctAnswer;
    
    setState(() {
      _answers[questionId] = selectedAnswer;
      if (isCorrect) {
        _correctAnswers++;
      } else {
        _wrongAnswers++;
        // Track the topic for improvement
        final question = _assessmentQuestions.firstWhere((q) => q['id'] == questionId);
        if (!_improvementAreas.contains(question['topic'])) {
          _improvementAreas.add(question['topic']);
        }
      }
      _isAnswerCorrect = isCorrect;
      _showingAnswerFeedback = true;
    });

    // Hide feedback and move to next question after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showingAnswerFeedback = false;
          _currentQuestionIndex++;
          
          // Check if all questions are done
          if (_currentQuestionIndex >= _assessmentQuestions.length) {
            _calculateLevelAndShowResults();
          }
        });
      }
    });
  }

  void _calculateLevelAndShowResults() {
    final totalQuestions = _assessmentQuestions.length;
    final percentage = (_correctAnswers / totalQuestions) * 100;

    String level;
    if (percentage >= 80) {
      level = 'Advanced';
    } else if (percentage >= 60) {
      level = 'Intermediate';
    } else if (percentage >= 40) {
      level = 'Beginner';
    } else {
      level = 'Foundation';
    }

    setState(() {
      _userLevel = level;
      _currentStep = 1; // Move to comprehensive results
    });
  }

  // Comprehensive Results with Mindset + Journey Guidance
  Widget _buildComprehensiveResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Celebration header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.courseColor, widget.courseColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Learning Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete Analysis & Journey Guide',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Section 1: Assessment Results
          _buildResultSection(
            'Your Current Level',
            Icons.trending_up,
            widget.courseColor,
            [
              _buildLevelCard(),
              const SizedBox(height: 16),
              _buildPerformanceStats(),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Section 2: Mindset Analysis Summary
          if (_mindsetProfile != null) ...[
            _buildResultSection(
              'Your Learning Mindset',
              Icons.psychology,
              Colors.purple,
              [
                _buildMindsetInsights(),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Section 3: Your Learning Journey
          _buildResultSection(
            'Your Personalized Journey',
            Icons.map,
            Colors.blue,
            [
              _buildJourneyGuidance(),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Section 4: Improvement Areas
          if (_improvementAreas.isNotEmpty) ...[
            _buildResultSection(
              'Focus Areas',
              Icons.flag,
              Colors.orange,
              [
                ..._improvementAreas.map((area) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            area,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.courseColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue to Study Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.courseColor.withOpacity(0.1), widget.courseColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.courseColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.courseColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Level',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userLevel,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: widget.courseColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats() {
    final totalQuestions = _assessmentQuestions.length;
    final percentage = ((_correctAnswers / totalQuestions) * 100).round();
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Correct',
            _correctAnswers.toString(),
            Colors.green,
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Score',
            '$percentage%',
            widget.courseColor,
            Icons.percent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total',
            totalQuestions.toString(),
            Colors.grey,
            Icons.quiz,
          ),
        ),
      ],
    );
  }

  Widget _buildMindsetInsights() {
    if (_mindsetProfile == null) {
      return const Text('No mindset data available');
    }

    // Analyze key mindset patterns
    final studyHours = _mindsetProfile!['q1'] ?? 'Not specified';
    final studyConsistency = _mindsetProfile!['q2'] ?? 'Not specified';
    final studyClarity = _mindsetProfile!['q3'] ?? 'Not specified';
    final practiceFrequency = _mindsetProfile!['q9'] ?? 'Not specified';
    final examAnxiety = _mindsetProfile!['q11'] ?? 'Not specified';
    final confidence = _mindsetProfile!['q13'] ?? 'Not specified';
    final satisfaction = _mindsetProfile!['q25'] ?? 'Not specified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInsightRow('Study Routine', studyHours, Icons.schedule),
        _buildInsightRow('Consistency', studyConsistency, Icons.calendar_today),
        _buildInsightRow('Study Clarity', studyClarity, Icons.lightbulb),
        _buildInsightRow('Practice Habit', practiceFrequency, Icons.fitness_center),
        _buildInsightRow('Exam Emotions', examAnxiety, Icons.favorite),
        _buildInsightRow('Confidence Level', confidence, Icons.trending_up),
        _buildInsightRow('Current Satisfaction', satisfaction, Icons.sentiment_satisfied),
      ],
    );
  }

  Widget _buildInsightRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: widget.courseColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyGuidance() {
    // Generate personalized guidance based on level and mindset
    String journeyTitle;
    String journeyDescription;
    List<String> journeySteps;

    switch (_userLevel) {
      case 'Advanced':
        journeyTitle = '🚀 Advanced Fast Track';
        journeyDescription = 'You have a strong foundation. Focus on advanced concepts, practice intensive problem-solving, and take regular mock tests to maintain your edge.';
        journeySteps = [
          'Master advanced topics and complex problems',
          'Practice previous year papers extensively',
          'Take weekly mock tests to simulate exam conditions',
          'Focus on speed and accuracy improvement',
          'Teach concepts to others to reinforce learning',
        ];
        break;
      case 'Intermediate':
        journeyTitle = '📈 Progressive Learning Path';
        journeyDescription = 'You have good basics. Strengthen your foundation while gradually moving to advanced topics. Balance theory with consistent practice.';
        journeySteps = [
          'Review fundamentals in weak areas',
          'Progress systematically from basic to advanced',
          'Practice daily with increasing difficulty',
          'Take bi-weekly mock tests',
          'Focus on concept clarity before speed',
        ];
        break;
      case 'Beginner':
        journeyTitle = '🌱 Foundation Builder Route';
        journeyDescription = 'Start with building a solid foundation. Focus on understanding core concepts thoroughly before moving to advanced topics.';
        journeySteps = [
          'Master fundamental concepts first',
          'Use visual aids and simple explanations',
          'Practice basic problems extensively',
          'Revise regularly within 24-48 hours',
          'Take monthly assessment tests',
        ];
        break;
      default: // Foundation
        journeyTitle = '🎯 Ground-Up Learning Journey';
        journeyDescription = 'Begin with the absolute basics. Take your time to understand each concept deeply. Consistent daily study is your key to success.';
        journeySteps = [
          'Start with elementary concepts and definitions',
          'Use multiple learning resources (videos, books, notes)',
          'Practice very basic problems repeatedly',
          'Build study routine and consistency first',
          'Focus on understanding, not memorization',
        ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          journeyTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          journeyDescription,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your Action Plan:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...journeySteps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Missing methods
  Future<void> _skipToStudyPlan() async {
    setState(() {
      _currentStep = 2; // Go directly to study plan step
      _isLoading = false;
    });
  }

  Future<void> _generateAssessmentQuestions() async {
    // This is handled by _initializeAssessment, so just set loading to false
    setState(() {
      _isLoading = false;
    });
  }

  void _calculateLevel() {
    _calculateLevelAndShowResults();
  }

  Future<void> _saveAndGenerateRoadmap() async {
    setState(() => _isLoading = true);

    try {
      // Save assessment results
      await LevelAssessmentBackend.saveAssessmentResults(
        courseName: widget.courseName,
        knowsExam: _knowsExam,
        selectedTopics: _selectedTopics,
        userLevel: _userLevel,
        correctAnswers: _correctAnswers,
        totalQuestions: _assessmentQuestions.length,
        improvementAreas: _improvementAreas,
        studyHoursPerDay: _studyHoursPerDay,
        daysUntilExam: _daysUntilExam,
      );

      // Get mindset profile
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();

      final rawAnswers = userDoc.data()?['mindsetAnswers'] ?? {};
      final mindsetAnswers = <String, String>{};

      if (rawAnswers is Map) {
        rawAnswers.forEach((key, value) {
          if (value is String) {
            mindsetAnswers[key.toString()] = value;
          } else if (value is List) {
            mindsetAnswers[key.toString()] = value.join(', ');
          } else {
            mindsetAnswers[key.toString()] = value.toString();
          }
        });
      }

      // Generate roadmap with assessment context
      final roadmapResult = await RoadmapBackend.generateRoadmap(
        courseName: widget.courseName,
        mindsetProfile: mindsetAnswers,
        userLevel: _userLevel,
        improvementAreas: _improvementAreas,
        studyHoursPerDay: _studyHoursPerDay,
        daysUntilExam: _daysUntilExam,
      );

      setState(() => _isLoading = false);

      if (roadmapResult['success']) {
        final roadmap = roadmapResult['roadmap'] as List<Map<String, dynamic>>;
        
        if (!mounted) return;

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RoadmapScreen(
                courseName: widget.courseName,
                roadmap: roadmap,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(roadmapResult['message'] ?? 'Failed to generate roadmap'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
}
