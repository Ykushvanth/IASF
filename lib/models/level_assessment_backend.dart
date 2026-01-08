import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LevelAssessmentBackend {
  static String get groqApiKey =>
      dotenv.env['GROQ_API_KEY'] ?? 'API_KEY_NOT_SET';
  static const String groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  /// Generate assessment questions based on selected topics and user's mindset profile
  static Future<Map<String, dynamic>> generateQuestions({
    required String courseName,
    required List<String> selectedTopics,
    Map<String, String>? mindsetProfile,
  }) async {
    print('🎯 Generating AI-analyzed assessment questions...');
    print('📚 Course: $courseName');
    print('📝 Selected topics: $selectedTopics');
    print('🧠 Mindset profile provided: ${mindsetProfile != null}');

    try {
      // Build mindset context for personalized questions
      String mindsetContext = '';
      if (mindsetProfile != null && mindsetProfile.isNotEmpty) {
        final studyHours = mindsetProfile['q1'] ?? 'Not specified';
        final consistency = mindsetProfile['q2'] ?? 'Not specified';
        final clarity = mindsetProfile['q3'] ?? 'Not specified';
        final practice = mindsetProfile['q9'] ?? 'Not specified';
        
        mindsetContext = '''
User's Learning Profile:
- Study Duration: $studyHours
- Study Consistency: $consistency
- Concept Clarity: $clarity
- Practice Frequency: $practice

Based on this profile, generate questions that accurately assess their current knowledge level.
''';
      }

      final prompt = '''
You are an expert exam assessor for $courseName. Generate 10 multiple-choice questions to accurately assess the user's knowledge level across different difficulty ranges.

$mindsetContext

Selected topics: ${selectedTopics.join(', ')}

IMPORTANT: Generate questions that test REAL understanding, not just memorization:
1. Mix conceptual understanding with application-based problems
2. Include scenario-based questions
3. Test both fundamentals and advanced concepts
4. Vary difficulty: 3 easy (basic concepts), 4 medium (application), 3 hard (advanced analysis)

For each question, generate:
1. A clear, specific question text
2. Four distinct options (make distractors plausible but incorrect)
3. The correct answer (must match one of the options exactly)
4. The topic it belongs to
5. Difficulty level (easy, medium, hard)

Return ONLY a valid JSON array with this exact structure:
[
  {
    "id": "q1",
    "question": "Specific question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": "Option A",
    "topic": "Specific topic name",
    "difficulty": "easy"
  }
]

Make questions exam-relevant and rigorous. Return ONLY the JSON array, no markdown, no extra text.
''';

      final response = await http.post(
        Uri.parse(groqApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
          'max_tokens': 4000,
        }),
      );

      print('📡 Groq API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'];
        
        print('🤖 Raw AI Response: $content');
        
        // Clean up markdown code blocks if present
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        
        // Parse the JSON array from the response
        final questions = jsonDecode(content) as List;
        
        print('✅ Generated ${questions.length} AI-analyzed questions');
        
        return {
          'success': true,
          'questions': questions,
        };
      } else {
        print('❌ API Error: ${response.statusCode}');
        print('Response: ${response.body}');
        
        // Fallback: Generate sample questions
        return {
          'success': true,
          'questions': _generateFallbackQuestions(selectedTopics),
        };
      }
    } catch (e, stackTrace) {
      print('❌ Error generating questions: $e');
      print('Stack trace: $stackTrace');
      
      // Return fallback questions
      return {
        'success': true,
        'questions': _generateFallbackQuestions(selectedTopics),
      };
    }
  }

  static List<Map<String, dynamic>> _generateFallbackQuestions(List<String> topics) {
    // Fallback sample questions if AI fails
    return [
      {
        'id': 'q1',
        'question': 'What is the fundamental concept of ${topics.isNotEmpty ? topics[0] : "this topic"}?',
        'options': [
          'Option A - Basic principle',
          'Option B - Advanced concept',
          'Option C - Intermediate idea',
          'Option D - Complex theory'
        ],
        'correctAnswer': 'Option A - Basic principle',
        'topic': topics.isNotEmpty ? topics[0] : 'General',
        'difficulty': 'easy'
      },
      {
        'id': 'q2',
        'question': 'Which formula is commonly used in ${topics.length > 1 ? topics[1] : topics.isNotEmpty ? topics[0] : "this subject"}?',
        'options': [
          'Formula A',
          'Formula B',
          'Formula C',
          'Formula D'
        ],
        'correctAnswer': 'Formula A',
        'topic': topics.length > 1 ? topics[1] : topics.isNotEmpty ? topics[0] : 'General',
        'difficulty': 'medium'
      },
      {
        'id': 'q3',
        'question': 'What is the practical application of ${topics.isNotEmpty ? topics[0] : "this concept"}?',
        'options': [
          'Application 1',
          'Application 2',
          'Application 3',
          'Application 4'
        ],
        'correctAnswer': 'Application 1',
        'topic': topics.isNotEmpty ? topics[0] : 'General',
        'difficulty': 'medium'
      },
    ];
  }

  /// Save assessment results to Firebase
  static Future<Map<String, dynamic>> saveAssessmentResults({
    required String courseName,
    required bool knowsExam,
    required List<String> selectedTopics,
    required String userLevel,
    required int correctAnswers,
    required int totalQuestions,
    required List<String> improvementAreas,
    required int studyHoursPerDay,
    required int daysUntilExam,
  }) async {
    print('💾 Saving assessment results...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
        };
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'levelAssessment': {
          'courseName': courseName,
          'knowsExam': knowsExam,
          'selectedTopics': selectedTopics,
          'userLevel': userLevel,
          'correctAnswers': correctAnswers,
          'totalQuestions': totalQuestions,
          'score': totalQuestions > 0 ? (correctAnswers / totalQuestions * 100).round() : 0,
          'improvementAreas': improvementAreas,
          'studyHoursPerDay': studyHoursPerDay,
          'daysUntilExam': daysUntilExam,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      print('✅ Assessment results saved successfully');

      return {
        'success': true,
        'message': 'Assessment results saved',
      };
    } catch (e, stackTrace) {
      print('❌ Error saving assessment results: $e');
      print('Stack trace: $stackTrace');

      return {
        'success': false,
        'message': 'Failed to save assessment results: $e',
      };
    }
  }

  /// Get user's assessment results
  static Future<Map<String, dynamic>> getAssessmentResults() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      if (data != null && data.containsKey('levelAssessment')) {
        return {
          'success': true,
          'assessment': data['levelAssessment'],
        };
      }

      return {
        'success': false,
        'message': 'No assessment data found',
      };
    } catch (e) {
      print('❌ Error getting assessment results: $e');
      return {
        'success': false,
        'message': 'Failed to get assessment results: $e',
      };
    }
  }
}
