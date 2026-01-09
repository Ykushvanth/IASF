import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// PracticeBackend - Generates practice problems for topics
class PracticeBackend {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate practice problems for a topic
  static Future<Map<String, dynamic>> generatePracticeProblems({
    required String topicName,
    required String courseName,
    required String difficulty,
    int numberOfProblems = 5,
    String userLevel = 'intermediate',
  }) async {
    print('📝 Generating practice problems for: $topicName');
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      // Check if practice problems already exist in Firebase
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('practiceProblems')
          .doc('${courseName}_$topicName');

      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data() != null) {
        final existingData = docSnap.data()!;
        print('✅ Found existing practice problems in Firebase');
        return {
          'success': true,
          'problems': existingData['problems'] ?? [],
          'generatedAt': existingData['generatedAt'],
        };
      }

      // Generate practice problems using AI
      final result = await _generateWithAI(
        topicName: topicName,
        courseName: courseName,
        difficulty: difficulty,
        numberOfProblems: numberOfProblems,
        userLevel: userLevel,
      );

      if (result['success'] == true) {
        final problems = result['problems'] as List<dynamic>;
        
        // Save to Firebase
        await docRef.set({
          'topicName': topicName,
          'courseName': courseName,
          'problems': problems,
          'userLevel': userLevel,
          'generatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Practice problems generated and saved');
        return {
          'success': true,
          'problems': problems,
          'generatedAt': DateTime.now().toIso8601String(),
        };
      } else {
        return result;
      }
    } catch (e, stackTrace) {
      print('❌ Error generating practice problems: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error generating practice problems: ${e.toString()}',
      };
    }
  }

  /// Generate practice problems using Groq API
  static Future<Map<String, dynamic>> _generateWithAI({
    required String topicName,
    required String courseName,
    required String difficulty,
    required int numberOfProblems,
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

      final prompt = '''Generate $numberOfProblems practice problems for the topic: **$topicName**

**Context:**
- Course: $courseName
- Difficulty: $difficulty
- Student Level: $userLevel

**Requirements:**
1. Create $numberOfProblems diverse practice problems
2. Each problem should have:
   - **question:** Clear problem statement
   - **type:** "multiple_choice", "short_answer", or "calculation"
   - **options:** Array of choices (for multiple choice)
   - **correctAnswer:** The correct answer
   - **explanation:** Step-by-step solution explanation
   - **difficulty:** "easy", "medium", or "hard"

3. Vary problem types and difficulty levels
4. Make problems relevant to the topic and course
5. Provide clear, detailed explanations

**Output Format (JSON):**
{
  "problems": [
    {
      "question": "Problem statement here",
      "type": "multiple_choice",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctAnswer": "Option A",
      "explanation": "Detailed step-by-step explanation",
      "difficulty": "medium"
    },
    ...
  ]
}

Generate the practice problems now:''';

      print('🤖 Calling Groq API for practice problems generation...');
      
      final requestBody = jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert educator who creates high-quality practice problems that help students master topics. Always respond with valid JSON only.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 3000,
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
        final problems = data['problems'] as List<dynamic>;
        
        print('✅ Practice problems generated successfully');
        return {
          'success': true,
          'problems': problems,
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

  /// Get AI tutor help for a specific problem when student is stuck
  static Future<Map<String, dynamic>> getAITutorHelp({
    required Map<String, dynamic> problem,
    required String topicName,
    required String courseName,
    String? userAnswer,
  }) async {
    print('🤖 Getting AI tutor help for practice problem...');
    
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      
      if (apiKey.isEmpty) {
        return {
          'success': false,
          'message': 'API key not configured',
        };
      }

      final question = problem['question'] ?? '';
      final correctAnswer = problem['correctAnswer'] ?? '';
      final explanation = problem['explanation'] ?? '';
      
      final userAnswerText = userAnswer != null 
          ? '**Student Answer:** $userAnswer\n'
          : '';
      
      final taskText = userAnswer != null
          ? 'The student attempted: "$userAnswer" but it is not correct. Help them understand:\n1. What might have gone wrong in their thinking\n2. Provide a hint or clue (do not give away the full answer)\n3. Guide them step-by-step toward the solution\n4. Be encouraging and supportive'
          : 'The student is stuck on this problem. Provide:\n1. A helpful hint or clue (do not give away the full answer)\n2. Break down the problem into smaller steps\n3. Guide them to think through the approach\n4. Be encouraging and supportive';
      
      final prompt = '''You are a friendly and patient AI tutor helping a student solve a practice problem.

**Problem:**
$question

**Course:** $courseName
**Topic:** $topicName

$userAnswerText**Correct Answer:** $correctAnswer
**Explanation:** $explanation

**Your Task:**
$taskText

**Important:**
- Do not give away the answer directly - guide them to discover it
- Use simple, clear language
- Be encouraging and patient
- Break down complex problems into smaller steps
- Provide conceptual understanding, not just memorization

Give a helpful, step-by-step guidance:''';

      print('🤖 Calling Groq API for AI tutor help...');
      
      final requestBody = jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a patient, encouraging AI tutor who helps students learn by guiding them, not by giving direct answers. Always be supportive and break problems into manageable steps.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.8,
        'max_tokens': 500,
      });

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: requestBody,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw http.ClientException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['choices'][0]['message']['content'];
        
        print('✅ AI tutor help generated successfully');
        return {
          'success': true,
          'help': content,
        };
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'API error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error getting AI tutor help: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}

