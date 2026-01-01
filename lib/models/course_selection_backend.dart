import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CourseSelectionBackend {
  static Future<Map<String, dynamic>> saveCourseSelection({
    required String courseName,
    required Map<String, String> answers,
  }) async {
    print('📚 Starting course selection save...');
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        print('❌ No user logged in');
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      print('👤 User UID: ${user.uid}');
      print('📝 Course: $courseName');
      print('💬 Answers: ${answers.length} responses');

      // Generate AI insights
      print('🤖 Generating AI insights for course selection...');
      final aiInsights = await summarizeWithGroq(courseName, answers);
      
      if (aiInsights == null) {
        print('⚠️ Failed to generate AI insights, proceeding without them');
      } else {
        print('✅ AI insights generated successfully');
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Save to user document with timestamp and AI insights
      await firestore.collection('users').doc(user.uid).update({
        'selectedCourse': courseName,
        'courseAnswers': answers,
        'courseInsights': aiInsights ?? 'Analysis unavailable',
        'courseSelectedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Course selection saved successfully');
      
      return {
        'success': true,
        'message': 'Course selection saved successfully',
        'insights': aiInsights,
      };
    } on FirebaseException catch (e) {
      print('🔥 Firebase error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': 'Firebase error: ${e.message}',
      };
    } catch (e) {
      print('❌ Error saving course selection: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  static Future<String?> summarizeWithGroq(
    String courseName,
    Map<String, String> answers,
  ) async {
    print('🤖 Starting Groq API call for course analysis...');
    
    try {
      final analysisText = _prepareAnalysisText(courseName, answers);
      print('📝 Prepared analysis text (${analysisText.length} chars)');

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${dotenv.env['GROQ_API_KEY'] ?? ''}',
            },
            body: jsonEncode({
              'model': 'llama-3.3-70b-versatile',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a friendly career counselor helping students choose their exam path. Be warm, encouraging, and practical.',
                },
                {
                  'role': 'user',
                  'content':
                      'A student selected $courseName and answered these questions:\n\n$analysisText\n\nWrite a friendly 2-3 paragraph message that:\n1) Shows understanding of their motivation and current knowledge level\n2) Gives practical advice on how to prepare effectively\n3) Encourages them with realistic expectations\n\nBe personal, supportive, and skip any scores or numbers.',
                },
              ],
              'temperature': 0.8,
              'max_tokens': 350,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('📡 API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['choices'][0]['message']['content'].toString();
        print('✅ Groq API success (${summary.length} chars)');
        return summary;
      } else {
        print('❌ Groq API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('🔥 Error calling Groq API: $e');
      return null;
    }
  }

  static String _prepareAnalysisText(
    String courseName,
    Map<String, String> answers,
  ) {
    final questions = [
      'Why do you want to pursue this exam?',
      'What do you know about this exam?',
      'What opportunities excite you most about this field?',
      'How much time can you dedicate daily for preparation?',
      'When are you planning to take this exam?',
    ];

    final buffer = StringBuffer();
    buffer.writeln('Course: $courseName\n');

    int index = 1;
    answers.forEach((key, value) {
      if (index <= questions.length) {
        buffer.writeln('Q$index: ${questions[index - 1]}');
        buffer.writeln('A$index: $value\n');
        index++;
      }
    });

    return buffer.toString();
  }
}
