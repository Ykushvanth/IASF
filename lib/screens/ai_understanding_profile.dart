import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIUnderstandingProfileScreen extends StatefulWidget {
  const AIUnderstandingProfileScreen({super.key});

  @override
  State<AIUnderstandingProfileScreen> createState() =>
      _AIUnderstandingProfileScreenState();
}

class _AIUnderstandingProfileScreenState
    extends State<AIUnderstandingProfileScreen> {
  Map<String, dynamic>? _mindsetProfile;
  String? _userLevel;
  String? _selectedCourse;
  bool _isLoading = true;
  String? _aiSummary;
  List<String>? _aiRecommendations;

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
            }
          });
        }

        // Get selected course
        final selectedCourse = userDoc.data()?['selectedCourse'] as String?;

        // Get user's assessment level
        String? userLevel;
        if (selectedCourse != null) {
          final assessmentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('assessments')
              .doc(selectedCourse)
              .get();

          if (assessmentDoc.exists) {
            userLevel = assessmentDoc.data()?['level'] as String?;
          }
        }

        setState(() {
          _mindsetProfile = mindsetAnswers;
          _userLevel = userLevel;
          _selectedCourse = selectedCourse;
          _isLoading = false;
        });

        // Generate AI summary after loading profile
        if (mindsetAnswers.isNotEmpty) {
          _generateAISummaryFromGroq();
        }
      }
    } catch (e) {
      print('Error loading mindset profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAISummaryFromGroq() async {
    try {
      final profile = _mindsetProfile ?? {};

      // Build context from all mindset answers
      final contextParts = <String>[];

      contextParts.add('Learning Habits:');
      contextParts.add(
        '- Daily Study Duration: ${profile['q1'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Study Consistency: ${profile['q2'] ?? 'Not specified'}',
      );
      contextParts.add('- Study Place: ${profile['q1b'] ?? 'Not specified'}');

      contextParts.add('\nUnderstanding & Clarity:');
      contextParts.add(
        '- Understanding Challenges: ${profile['q3'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Confusion Points: ${profile['q4'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Concept Application: ${profile['q5'] ?? 'Not specified'}',
      );

      contextParts.add('\nMemory & Retention:');
      contextParts.add(
        '- Forgetting Patterns: ${profile['q6'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Revision Frequency: ${profile['q7'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Long-term Retention: ${profile['q8'] ?? 'Not specified'}',
      );

      contextParts.add('\nPractice & Problem Solving:');
      contextParts.add(
        '- Problem Solving Frequency: ${profile['q9'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Mistake Analysis: ${profile['q10'] ?? 'Not specified'}',
      );

      contextParts.add('\nEmotional & Mental Health:');
      contextParts.add(
        '- Exam Anxiety Level: ${profile['q11'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Stress Management: ${profile['q12'] ?? 'Not specified'}',
      );

      contextParts.add('\nConfidence & Self-Belief:');
      contextParts.add(
        '- Subject Confidence: ${profile['q13'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Handling Difficult Topics: ${profile['q14'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Exam Readiness Belief: ${profile['q15'] ?? 'Not specified'}',
      );

      contextParts.add('\nFocus & Concentration:');
      contextParts.add(
        '- Concentration Duration: ${profile['q16'] ?? 'Not specified'}',
      );
      contextParts.add('- Fatigue Level: ${profile['q17'] ?? 'Not specified'}');

      contextParts.add('\nLearning Behavior:');
      contextParts.add(
        '- Learning Style Preference: ${profile['q18'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Resource Variety: ${profile['q19'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Study Group Participation: ${profile['q20'] ?? 'Not specified'}',
      );

      contextParts.add('\nMotivation & Goals:');
      contextParts.add('- Goal Clarity: ${profile['q21'] ?? 'Not specified'}');
      contextParts.add(
        '- Obstacle Handling: ${profile['q22'] ?? 'Not specified'}',
      );

      contextParts.add('\nProgress & Satisfaction:');
      contextParts.add(
        '- Progress Awareness: ${profile['q23'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Improvement Recognition: ${profile['q24'] ?? 'Not specified'}',
      );
      contextParts.add(
        '- Overall Satisfaction: ${profile['q25'] ?? 'Not specified'}',
      );

      contextParts.add('\nAdditional Insights:');
      contextParts.add(
        '- Unique Strengths: ${profile['q26'] ?? 'Not specified'}',
      );

      if (_userLevel != null) {
        contextParts.add('\nAssessment Level: $_userLevel');
      }

      final fullContext = contextParts.join('\n');

      // Call Groq API to generate personalized summary
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert educational psychologist and learning coach who creates deeply personalized learning profiles. Analyze the student\'s complete learning profile and generate a unique, insightful summary that captures their specific strengths, challenges, and learning patterns. Be specific and reference their actual responses.',
            },
            {
              'role': 'user',
              'content':
                  '''Analyze this student's complete learning profile and create a personalized AI summary:

$fullContext

Generate a comprehensive, personalized summary (3-4 paragraphs) that:
1. Analyzes their learning routine and habits with specific references to their responses
2. Evaluates their performance patterns (understanding, retention, practice)
3. Assesses their mental health and confidence levels
4. Discusses their engagement, focus, and motivation
5. Provides an overall trajectory assessment with specific, actionable insights

Then, generate 4 specific, actionable recommendations tailored to their unique profile.

Format your response as:
SUMMARY:
[Your detailed summary here]

RECOMMENDATIONS:
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]
4. [Recommendation 4]

Make this truly personalized - no generic advice. Reference their actual responses and create insights specific to this individual learner.''',
            },
          ],
          'temperature': 0.8,
          'max_tokens': 1500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Parse the response
        final summaryMatch = RegExp(
          r'SUMMARY:\s*(.+?)(?=RECOMMENDATIONS:)',
          dotAll: true,
        ).firstMatch(content);
        final recommendationsMatch = RegExp(
          r'RECOMMENDATIONS:\s*(.+)',
          dotAll: true,
        ).firstMatch(content);

        String summary = summaryMatch?.group(1)?.trim() ?? content;

        List<String> recommendations = [];
        if (recommendationsMatch != null) {
          final recsText = recommendationsMatch.group(1)?.trim() ?? '';
          recommendations = recsText
              .split('\n')
              .where(
                (line) =>
                    line.trim().isNotEmpty &&
                    RegExp(r'^\d+\.').hasMatch(line.trim()),
              )
              .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
              .where((line) => line.isNotEmpty)
              .toList();
        }

        // If we didn't get exactly 4 recommendations, fall back to template-based ones
        if (recommendations.length < 4) {
          recommendations = _generateRecommendations();
        }

        setState(() {
          _aiSummary = summary;
          _aiRecommendations = recommendations;
        });
      } else {
        print('Error generating AI summary: ${response.statusCode}');
        // Fall back to template-based summary
        setState(() {
          _aiSummary = _generateAISummaryText();
          _aiRecommendations = _generateRecommendations();
        });
      }
    } catch (e) {
      print('Error calling Groq API: $e');
      // Fall back to template-based summary
      setState(() {
        _aiSummary = _generateAISummaryText();
        _aiRecommendations = _generateRecommendations();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Understanding Profile'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mindsetProfile == null || _mindsetProfile!.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No Mindset Profile Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your mindset analysis to see how AI understands you',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'How AI Understands You',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your Complete Learning Profile',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // User's Level Card
                  if (_userLevel != null)
                    _buildLevelCard()
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Take the exam level assessment to see your proficiency level',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Section 1: Learning Habits
                  _buildProfileSection(
                    'Learning Habits',
                    Icons.schedule,
                    const Color(0xFF6366F1),
                    [
                      _buildProfileItem(
                        'Daily Study Duration',
                        _mindsetProfile!['q1'] ?? 'Not specified',
                        Icons.timer,
                      ),
                      _buildProfileItem(
                        'Study Consistency',
                        _mindsetProfile!['q2'] ?? 'Not specified',
                        Icons.calendar_today,
                      ),
                      _buildProfileItem(
                        'Study Place',
                        _mindsetProfile!['q1b'] ?? 'Not specified',
                        Icons.location_on,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Understanding & Clarity
                  _buildProfileSection(
                    'Learning Clarity',
                    Icons.lightbulb,
                    Colors.orange,
                    [
                      _buildProfileItem(
                        'Understanding Challenges',
                        _mindsetProfile!['q3'] ?? 'Not specified',
                        Icons.question_mark,
                      ),
                      _buildProfileItem(
                        'Confusion Points',
                        _mindsetProfile!['q4'] ?? 'Not specified',
                        Icons.warning_amber,
                      ),
                      _buildProfileItem(
                        'Concept Application',
                        _mindsetProfile!['q5'] ?? 'Not specified',
                        Icons.psychology,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Memory & Retention
                  _buildProfileSection(
                    'Memory & Retention',
                    Icons.memory,
                    Colors.purple,
                    [
                      _buildProfileItem(
                        'Forgetting Patterns',
                        _mindsetProfile!['q6'] ?? 'Not specified',
                        Icons.history,
                      ),
                      _buildProfileItem(
                        'Revision Frequency',
                        _mindsetProfile!['q7'] ?? 'Not specified',
                        Icons.refresh,
                      ),
                      _buildProfileItem(
                        'Long-term Retention',
                        _mindsetProfile!['q8'] ?? 'Not specified',
                        Icons.storage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 4: Practice & Problem Solving
                  _buildProfileSection(
                    'Practice Habits',
                    Icons.fitness_center,
                    Colors.green,
                    [
                      _buildProfileItem(
                        'Problem Solving Frequency',
                        _mindsetProfile!['q9'] ?? 'Not specified',
                        Icons.calculate,
                      ),
                      _buildProfileItem(
                        'Mistake Analysis',
                        _mindsetProfile!['q10'] ?? 'Not specified',
                        Icons.bug_report,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 5: Emotional & Mental Health
                  _buildProfileSection(
                    'Emotional Resilience',
                    Icons.favorite,
                    Colors.red,
                    [
                      _buildProfileItem(
                        'Exam Anxiety Level',
                        _mindsetProfile!['q11'] ?? 'Not specified',
                        Icons.sentiment_dissatisfied,
                      ),
                      _buildProfileItem(
                        'Stress Management',
                        _mindsetProfile!['q12'] ?? 'Not specified',
                        Icons.spa,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 6: Confidence & Self-Belief
                  _buildProfileSection(
                    'Confidence Profile',
                    Icons.trending_up,
                    Colors.teal,
                    [
                      _buildProfileItem(
                        'Subject Confidence',
                        _mindsetProfile!['q13'] ?? 'Not specified',
                        Icons.star,
                      ),
                      _buildProfileItem(
                        'Handling Difficult Topics',
                        _mindsetProfile!['q14'] ?? 'Not specified',
                        Icons.flag,
                      ),
                      _buildProfileItem(
                        'Exam Readiness Belief',
                        _mindsetProfile!['q15'] ?? 'Not specified',
                        Icons.verified,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 7: Focus & Concentration
                  _buildProfileSection(
                    'Focus & Concentration',
                    Icons.remove_red_eye,
                    Colors.blue,
                    [
                      _buildProfileItem(
                        'Concentration Duration',
                        _mindsetProfile!['q16'] ?? 'Not specified',
                        Icons.av_timer,
                      ),
                      _buildProfileItem(
                        'Fatigue Level',
                        _mindsetProfile!['q17'] ?? 'Not specified',
                        Icons.sentiment_very_dissatisfied,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 8: Learning Behavior
                  _buildProfileSection(
                    'Learning Behavior',
                    Icons.school,
                    Colors.indigo,
                    [
                      _buildProfileItem(
                        'Learning Style Preference',
                        _mindsetProfile!['q18'] ?? 'Not specified',
                        Icons.style,
                      ),
                      _buildProfileItem(
                        'Resource Variety',
                        _mindsetProfile!['q19'] ?? 'Not specified',
                        Icons.library_books,
                      ),
                      _buildProfileItem(
                        'Study Group Participation',
                        _mindsetProfile!['q20'] ?? 'Not specified',
                        Icons.group,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 9: Motivation & Goals
                  _buildProfileSection(
                    'Motivation & Goals',
                    Icons.flag,
                    Colors.amber,
                    [
                      _buildProfileItem(
                        'Goal Clarity',
                        _mindsetProfile!['q21'] ?? 'Not specified',
                        Icons.gps_fixed,
                      ),
                      _buildProfileItem(
                        'Obstacle Handling',
                        _mindsetProfile!['q22'] ?? 'Not specified',
                        Icons.shield,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 10: Progress & Satisfaction
                  _buildProfileSection(
                    'Progress Tracking',
                    Icons.timeline,
                    Colors.cyan,
                    [
                      _buildProfileItem(
                        'Progress Awareness',
                        _mindsetProfile!['q23'] ?? 'Not specified',
                        Icons.show_chart,
                      ),
                      _buildProfileItem(
                        'Improvement Recognition',
                        _mindsetProfile!['q24'] ?? 'Not specified',
                        Icons.grade,
                      ),
                      _buildProfileItem(
                        'Overall Satisfaction',
                        _mindsetProfile!['q25'] ?? 'Not specified',
                        Icons.sentiment_satisfied,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 11: Additional Insights
                  _buildProfileSection(
                    'Additional Insights',
                    Icons.insights,
                    Colors.pink,
                    [
                      _buildProfileItem(
                        'Unique Strengths',
                        _mindsetProfile!['q26'] ?? 'Not specified',
                        Icons.favorite,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // AI Summary Section
                  _buildAISummary(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildLevelCard() {
    // Get color and icon based on level
    Color levelColor;
    IconData levelIcon;
    String levelDescription;

    switch (_userLevel?.toLowerCase()) {
      case 'advanced':
        levelColor = Colors.green;
        levelIcon = Icons.local_fire_department;
        levelDescription =
            'You\'re performing at an advanced level with strong command over concepts';
        break;
      case 'intermediate':
        levelColor = Colors.blue;
        levelIcon = Icons.trending_up;
        levelDescription =
            'You\'re at an intermediate level with good foundation and growth potential';
        break;
      case 'beginner':
        levelColor = Colors.orange;
        levelIcon = Icons.school;
        levelDescription =
            'You\'re at a beginner level and building your foundational knowledge';
        break;
      case 'foundation':
        levelColor = Colors.amber;
        levelIcon = Icons.construction;
        levelDescription =
            'You\'re at the foundation level and ready to start your learning journey';
        break;
      default:
        levelColor = Colors.grey;
        levelIcon = Icons.help_outline;
        levelDescription = 'Take the assessment to determine your level';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [levelColor.withOpacity(0.1), levelColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: levelColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: levelColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: levelColor,
              shape: BoxShape.circle,
            ),
            child: Icon(levelIcon, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Assessment Level',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _userLevel ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: levelColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  levelDescription,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> items,
  ) {
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildAISummary() {
    // Use AI-generated summary or show loading
    final summary = _aiSummary ?? 'Generating your personalized AI summary...';
    final recommendations = _aiRecommendations ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Key Recommendations:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '✓ ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rec,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _generateAISummaryText() {
    final profile = _mindsetProfile ?? {};

    // Score different learning dimensions
    int studyScore = _scoreAttribute(profile['q1'], 'study_hours');
    int consistencyScore = _scoreAttribute(profile['q2'], 'consistency');
    int clarityScore = _scoreAttribute(profile['q3'], 'clarity');
    int retentionScore = _scoreAttribute(profile['q6'], 'retention');
    int practiceScore = _scoreAttribute(profile['q9'], 'practice');
    int anxietyScore = _scoreAttribute(profile['q11'], 'anxiety');
    int confidenceScore = _scoreAttribute(profile['q13'], 'confidence');
    int focusScore = _scoreAttribute(profile['q16'], 'focus');
    int learningStyleScore = _scoreAttribute(profile['q18'], 'learning_style');
    int motivationScore = _scoreAttribute(profile['q21'], 'motivation');
    int satisfactionScore = _scoreAttribute(profile['q25'], 'satisfaction');

    // Calculate overall scores by category
    int routineScore = (studyScore + consistencyScore) ~/ 2;
    int mentalhealthScore = (anxietyScore + confidenceScore) ~/ 2;
    int performanceScore = (clarityScore + retentionScore + practiceScore) ~/ 3;
    int engagementScore =
        (focusScore + learningStyleScore + motivationScore) ~/ 3;

    List<String> summaryParts = [];
    summaryParts.add('Based on your comprehensive learning profile, ');

    // Routine analysis
    if (routineScore >= 8) {
      summaryParts.add(
        'you demonstrate exceptional consistency with a well-established study routine that shows dedication and discipline. ',
      );
    } else if (routineScore >= 6) {
      summaryParts.add(
        'you maintain a decent study routine with good consistency, though there\'s room to strengthen your daily habits. ',
      );
    } else if (routineScore >= 4) {
      summaryParts.add(
        'you struggle with establishing a consistent study routine, and building daily habits is essential for improvement. ',
      );
    } else {
      summaryParts.add(
        'your study routine needs significant restructuring to create a sustainable learning schedule. ',
      );
    }

    // Performance analysis
    if (performanceScore >= 8) {
      summaryParts.add(
        'Your learning performance is outstanding - you grasp concepts quickly, retain information well, and practice consistently. ',
      );
    } else if (performanceScore >= 6) {
      summaryParts.add(
        'Your learning performance is solid with good comprehension and practice habits, but strategic improvements in retention could help. ',
      );
    } else if (performanceScore >= 4) {
      summaryParts.add(
        'Your learning performance shows potential but needs focused work on concept clarity, retention, and regular practice. ',
      );
    } else {
      summaryParts.add(
        'Your learning performance requires comprehensive improvements across understanding, retention, and practice frequency. ',
      );
    }

    // Mental health & resilience analysis
    if (mentalhealthScore >= 8) {
      summaryParts.add(
        'You handle stress remarkably well with strong confidence, which is a powerful asset for exam preparation. ',
      );
    } else if (mentalhealthScore >= 6) {
      summaryParts.add(
        'You manage exam anxiety reasonably well, though building additional confidence through targeted practice would strengthen your performance. ',
      );
    } else if (mentalhealthScore >= 4) {
      summaryParts.add(
        'Exam anxiety affects your performance, and developing confidence-building strategies should be a priority. ',
      );
    } else {
      summaryParts.add(
        'Managing exam anxiety and building confidence are critical focus areas that require immediate attention. ',
      );
    }

    // Engagement analysis
    if (engagementScore >= 8) {
      summaryParts.add(
        'Your engagement level is exceptional - you maintain excellent focus, have strong motivation, and align well with effective learning strategies. ',
      );
    } else if (engagementScore >= 6) {
      summaryParts.add(
        'Your engagement is good with decent focus and motivation, creating a positive foundation for learning. ',
      );
    } else if (engagementScore >= 4) {
      summaryParts.add(
        'Your engagement varies - working on focus duration and strengthening motivation will enhance your learning effectiveness. ',
      );
    } else {
      summaryParts.add(
        'Your engagement is low across focus, motivation, and learning strategy alignment - rebuilding these foundations is essential. ',
      );
    }

    // Overall trajectory
    int overallScore =
        (routineScore +
            performanceScore +
            mentalhealthScore +
            engagementScore) ~/
        4;
    if (overallScore >= 8) {
      summaryParts.add(
        'Overall, you\'re a high-performing learner with excellent habits and mindset. Continue refining your strategies for peak performance.',
      );
    } else if (overallScore >= 6) {
      summaryParts.add(
        'Overall, you\'re on a positive learning trajectory with good fundamentals. Targeted improvements will unlock your full potential.',
      );
    } else if (overallScore >= 4) {
      summaryParts.add(
        'Overall, you have the foundation to succeed but need focused efforts on consistency, performance, and resilience. Consistent application of improvements will yield results.',
      );
    } else {
      summaryParts.add(
        'Overall, transforming your learning approach requires comprehensive changes across routine, performance, and mindset. Start with small, consistent improvements.',
      );
    }

    return summaryParts.join('');
  }

  int _scoreAttribute(String? value, String type) {
    if (value == null || value.isEmpty) return 0;

    final lowerValue = value.toLowerCase();

    switch (type) {
      case 'study_hours':
        if (lowerValue.contains('4-5') || lowerValue.contains('more'))
          return 10;
        if (lowerValue.contains('2-3')) return 8;
        if (lowerValue.contains('1-2')) return 6;
        if (lowerValue.contains('less than 1')) return 3;
        return 5;

      case 'consistency':
        if (lowerValue.contains('daily')) return 10;
        if (lowerValue.contains('alternate') || lowerValue.contains('5 days'))
          return 7;
        if (lowerValue.contains('3-4')) return 5;
        if (lowerValue.contains('1-2')) return 2;
        return 3;

      case 'clarity':
        if (lowerValue.contains('never')) return 10;
        if (lowerValue.contains('sometimes')) return 6;
        if (lowerValue.contains('frequently')) return 3;
        if (lowerValue.contains('always')) return 1;
        return 5;

      case 'retention':
        if (lowerValue.contains('never') || lowerValue.contains('excellent'))
          return 10;
        if (lowerValue.contains('after few days') ||
            lowerValue.contains('1-2 weeks'))
          return 7;
        if (lowerValue.contains('few weeks')) return 4;
        if (lowerValue.contains('very soon')) return 2;
        return 5;

      case 'practice':
        if (lowerValue.contains('daily')) return 10;
        if (lowerValue.contains('3-4') || lowerValue.contains('weekly'))
          return 7;
        if (lowerValue.contains('1-2')) return 4;
        if (lowerValue.contains('rarely') || lowerValue.contains('never'))
          return 1;
        return 5;

      case 'anxiety':
        if (lowerValue.contains('never') || lowerValue.contains('not at all'))
          return 10;
        if (lowerValue.contains('sometimes')) return 6;
        if (lowerValue.contains('often')) return 3;
        if (lowerValue.contains('always') || lowerValue.contains('very high'))
          return 1;
        return 5;

      case 'confidence':
        if (lowerValue.contains('very confident') ||
            lowerValue.contains('extremely'))
          return 10;
        if (lowerValue.contains('moderately')) return 7;
        if (lowerValue.contains('somewhat')) return 4;
        if (lowerValue.contains('not at all')) return 1;
        return 5;

      case 'focus':
        if (lowerValue.contains('30+') || lowerValue.contains('more than 30'))
          return 10;
        if (lowerValue.contains('20-30')) return 8;
        if (lowerValue.contains('10-20')) return 6;
        if (lowerValue.contains('5-10')) return 3;
        if (lowerValue.contains("can't")) return 1;
        return 5;

      case 'learning_style':
        // Different styles, scoring based on active vs passive
        if (lowerValue.contains('group') ||
            lowerValue.contains('discussion') ||
            lowerValue.contains('interactive'))
          return 9;
        if (lowerValue.contains('video')) return 8;
        if (lowerValue.contains('practice') || lowerValue.contains('problem'))
          return 10;
        if (lowerValue.contains('reading') || lowerValue.contains('text'))
          return 6;
        return 5;

      case 'motivation':
        if (lowerValue.contains('very high') ||
            lowerValue.contains('extremely motivated'))
          return 10;
        if (lowerValue.contains('high') || lowerValue.contains('moderately'))
          return 7;
        if (lowerValue.contains('low') || lowerValue.contains('somewhat'))
          return 3;
        if (lowerValue.contains('very low')) return 1;
        return 5;

      case 'satisfaction':
        if (lowerValue.contains('very satisfied') ||
            lowerValue.contains('excellent'))
          return 10;
        if (lowerValue.contains('satisfied') || lowerValue.contains('good'))
          return 7;
        if (lowerValue.contains('neutral') || lowerValue.contains('moderate'))
          return 5;
        if (lowerValue.contains('not satisfied') || lowerValue.contains('poor'))
          return 2;
        return 5;

      default:
        return 5;
    }
  }

  List<String> _generateRecommendations() {
    final profile = _mindsetProfile ?? {};
    final recommendations = <String>[];

    final studyHours = profile['q1'] ?? '';
    final clarity = profile['q3'] ?? '';
    final practice = profile['q9'] ?? '';
    final anxiety = profile['q11'] ?? '';
    final focus = profile['q16'] ?? '';
    final learningStyle = profile['q18'] ?? '';

    // Study hours recommendation
    if (studyHours.contains('Less than 1')) {
      recommendations.add(
        'Gradually increase study duration to 2-3 hours daily for better retention and skill development.',
      );
    } else {
      recommendations.add(
        'Maintain your current study schedule while focusing on quality and active learning.',
      );
    }

    // Clarity recommendation
    if (clarity.contains('Sometimes') || clarity.contains('Frequently')) {
      recommendations.add(
        'Diversify your learning resources - try videos, animations, and visual explanations alongside traditional learning.',
      );
    } else {
      recommendations.add(
        'Continue with your effective learning methods and share your strategies with peers.',
      );
    }

    // Practice recommendation
    if (practice.contains('Less') || practice.contains('Never')) {
      recommendations.add(
        'Integrate daily problem-solving practice (even 30 minutes) to strengthen conceptual understanding.',
      );
    } else {
      recommendations.add(
        'Maintain your practice routine and gradually increase difficulty level of problems.',
      );
    }

    // Anxiety recommendation
    if (anxiety.contains('Often') || anxiety.contains('Always')) {
      recommendations.add(
        'Practice stress-relief techniques: meditation, exercise, or hobbies to manage exam anxiety effectively.',
      );
    } else {
      recommendations.add(
        'Continue your anxiety management strategies - they\'re working well for you.',
      );
    }

    // Focus recommendation
    if (focus.contains("Can't") || focus.contains('5-10')) {
      recommendations.add(
        'Use the Pomodoro Technique: 25-min focused study + 5-min breaks to improve concentration.',
      );
    } else {
      recommendations.add(
        'Your focus duration is good - utilize these focused sessions for deep learning.',
      );
    }

    // Learning style recommendation
    if (learningStyle.contains('Video')) {
      recommendations.add(
        'Leverage video-based learning platforms and visual content for maximum engagement and retention.',
      );
    } else if (learningStyle.contains('Reading')) {
      recommendations.add(
        'Supplement reading with practice problems and discussions to deepen understanding.',
      );
    } else if (learningStyle.contains('Group')) {
      recommendations.add(
        'Continue collaborative learning and teaching concepts to others for better mastery.',
      );
    }

    // Default recommendations if none above
    if (recommendations.isEmpty) {
      recommendations.add(
        'Set specific, measurable learning goals for each week.',
      );
      recommendations.add(
        'Track your progress regularly and adjust strategies based on results.',
      );
      recommendations.add(
        'Create a distraction-free study environment for optimal learning.',
      );
    }

    return recommendations.take(4).toList(); // Show top 4 recommendations
  }
}
