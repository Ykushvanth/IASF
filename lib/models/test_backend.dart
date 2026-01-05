import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// TestBackend - Generates tests/assessments for topics and tracks progress
class TestBackend {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a test for a topic
  static Future<Map<String, dynamic>> generateTest({
    required String topicName,
    required String courseName,
    required String difficulty,
    int numberOfQuestions = 10,
    String userLevel = 'intermediate',
  }) async {
    print('📝 Generating test for: $topicName');
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      // Check if test already exists in Firebase
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tests')
          .doc('${courseName}_$topicName');

      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data() != null) {
        final existingData = docSnap.data()!;
        print('✅ Found existing test in Firebase');
        return {
          'success': true,
          'questions': existingData['questions'] ?? [],
          'testId': existingData['testId'],
          'generatedAt': existingData['generatedAt'],
        };
      }

      // Generate test using AI
      final result = await _generateWithAI(
        topicName: topicName,
        courseName: courseName,
        difficulty: difficulty,
        numberOfQuestions: numberOfQuestions,
        userLevel: userLevel,
      );

      if (result['success'] == true) {
        final questions = result['questions'] as List<dynamic>;
        final testId = '${courseName}_$topicName';
        
        // Save to Firebase
        await docRef.set({
          'topicName': topicName,
          'courseName': courseName,
          'testId': testId,
          'questions': questions,
          'userLevel': userLevel,
          'completed': false,
          'score': null,
          'generatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Test generated and saved');
        return {
          'success': true,
          'questions': questions,
          'testId': testId,
          'generatedAt': DateTime.now().toIso8601String(),
        };
      } else {
        return result;
      }
    } catch (e, stackTrace) {
      print('❌ Error generating test: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error generating test: ${e.toString()}',
      };
    }
  }

  /// Submit test results and update progress
  static Future<Map<String, dynamic>> submitTestResults({
    required String topicName,
    required String courseName,
    required Map<String, String> answers, // questionId -> selectedAnswer
    required List<Map<String, dynamic>> questions,
  }) async {
    print('📊 Submitting test results for: $topicName');
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      // Calculate score
      int correct = 0;
      final results = <Map<String, dynamic>>[];
      
      for (var question in questions) {
        final questionId = question['id'] ?? question['question'];
        final userAnswer = answers[questionId.toString()] ?? '';
        final correctAnswer = question['correctAnswer'] ?? '';
        final isCorrect = userAnswer.trim().toLowerCase() == 
                         correctAnswer.toString().trim().toLowerCase();
        
        if (isCorrect) correct++;
        
        results.add({
          'question': question['question'],
          'userAnswer': userAnswer,
          'correctAnswer': correctAnswer,
          'isCorrect': isCorrect,
          'explanation': question['explanation'],
        });
      }

      final score = (correct / questions.length * 100).round();
      final passed = score >= 60; // 60% passing threshold

      // Save test results
      final testDocRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tests')
          .doc('${courseName}_$topicName');

      await testDocRef.update({
        'completed': true,
        'score': score,
        'correctAnswers': correct,
        'totalQuestions': questions.length,
        'results': results,
        'completedAt': FieldValue.serverTimestamp(),
        'passed': passed,
      });

      // Update roadmap progress
      await _updateRoadmapProgress(
        user.uid,
        courseName,
        topicName,
        passed,
        score,
      );

      print('✅ Test results saved and progress updated');
      return {
        'success': true,
        'score': score,
        'correct': correct,
        'total': questions.length,
        'passed': passed,
        'results': results,
      };
    } catch (e, stackTrace) {
      print('❌ Error submitting test results: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error submitting test: ${e.toString()}',
      };
    }
  }

  /// Update roadmap progress when test is completed
  static Future<void> _updateRoadmapProgress(
    String userId,
    String courseName,
    String topicName,
    bool passed,
    int score,
  ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final roadmap = userDoc.data()?['roadmap'] as List<dynamic>? ?? [];
      
      // Find the topic in roadmap and update its progress
      final updatedRoadmap = roadmap.map((day) {
        final dayMap = Map<String, dynamic>.from(day);
        if (dayMap['topic'] == topicName) {
          dayMap['completed'] = passed;
          dayMap['testScore'] = score;
          dayMap['testCompletedAt'] = FieldValue.serverTimestamp();
          print('✅ Updated roadmap progress for: $topicName (Score: $score%)');
        }
        return dayMap;
      }).toList();

      // Save updated roadmap
      await _firestore.collection('users').doc(userId).update({
        'roadmap': updatedRoadmap,
      });

      print('✅ Roadmap progress updated successfully');
    } catch (e) {
      print('❌ Error updating roadmap progress: $e');
      // Don't throw - progress update failure shouldn't block test submission
    }
  }

  /// Generate test using Groq API
  static Future<Map<String, dynamic>> _generateWithAI({
    required String topicName,
    required String courseName,
    required String difficulty,
    required int numberOfQuestions,
    required String userLevel,
  }) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      
      if (apiKey.isEmpty) {
        return {
          'success': false,
          'message': 'API key not configured',
        };
      }

      final prompt = '''Generate $numberOfQuestions test questions for the topic: **$topicName**

**Context:**
- Course: $courseName
- Difficulty: $difficulty
- Student Level: $userLevel

**Requirements:**
1. Create $numberOfQuestions diverse test questions
2. Each question should have:
   - **id:** Unique identifier (use question number)
   - **question:** Clear question statement
   - **type:** "multiple_choice" (preferred) or "short_answer"
   - **options:** Array of 4 choices (for multiple choice)
   - **correctAnswer:** The correct answer
   - **explanation:** Brief explanation of the answer
   - **points:** Points for this question (usually 1)

3. Mix question types and difficulty levels
4. Make questions comprehensive and test understanding
5. Provide clear, concise explanations

**Output Format (JSON):**
{
  "questions": [
    {
      "id": 1,
      "question": "Question text here",
      "type": "multiple_choice",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctAnswer": "Option A",
      "explanation": "Brief explanation",
      "points": 1
    },
    ...
  ]
}

Generate the test questions now:''';

      print('🤖 Calling Groq API for test generation...');
      
      final requestBody = jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert educator who creates comprehensive test questions that accurately assess student understanding. Always respond with valid JSON only.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 4000,
        'response_format': {'type': 'json_object'},
      });

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw http.ClientException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['choices'][0]['message']['content'];
        final data = jsonDecode(content);
        final questions = data['questions'] as List<dynamic>;
        
        print('✅ Test questions generated successfully');
        return {
          'success': true,
          'questions': questions,
        };
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'API error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error in AI generation: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}

