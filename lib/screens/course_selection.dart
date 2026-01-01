import 'package:flutter/material.dart';
import 'package:eduai/screens/course_questionnaire.dart';

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  final List<Map<String, dynamic>> _courses = [
    {
      'name': 'JEE (Joint Entrance Examination)',
      'icon': Icons.calculate,
      'color': const Color(0xFF6366F1),
      'description': 'Engineering entrance exam',
    },
    {
      'name': 'NEET (National Eligibility cum Entrance Test)',
      'icon': Icons.medical_services,
      'color': const Color(0xFFEC4899),
      'description': 'Medical entrance exam',
    },
    {
      'name': 'GATE (Graduate Aptitude Test in Engineering)',
      'icon': Icons.engineering,
      'color': const Color(0xFF8B5CF6),
      'description': 'Postgraduate engineering exam',
    },
    {
      'name': 'CAT (Common Admission Test)',
      'icon': Icons.business_center,
      'color': const Color(0xFFF59E0B),
      'description': 'MBA entrance exam',
    },
    {
      'name': 'UPSC (Union Public Service Commission)',
      'icon': Icons.account_balance,
      'color': const Color(0xFF10B981),
      'description': 'Civil services exam',
    },
    {
      'name': 'SSC (Staff Selection Commission)',
      'icon': Icons.work,
      'color': const Color(0xFF3B82F6),
      'description': 'Government job exams',
    },
    {
      'name': 'Banking Exams (IBPS, SBI)',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF06B6D4),
      'description': 'Banking sector exams',
    },
    {
      'name': 'CLAT (Common Law Admission Test)',
      'icon': Icons.gavel,
      'color': const Color(0xFFEF4444),
      'description': 'Law entrance exam',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        title: const Text(
          'Select Your Target Exam',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Your Path',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the exam you\'re preparing for',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return _buildCourseCard(course);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseQuestionnaireScreen(
                courseName: course['name'],
                courseIcon: course['icon'],
                courseColor: course['color'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: (course['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  course['icon'],
                  color: course['color'],
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
