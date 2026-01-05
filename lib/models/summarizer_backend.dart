import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// SummarizerBackend - Generates concise summaries for topics
class SummarizerBackend {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a summary for a topic or video
  static Future<Map<String, dynamic>> generateSummary({
    required String topicName,
    required String courseName,
    required String difficulty,
    String userLevel = 'intermediate',
    Map<String, dynamic>? videoData,
  }) async {
    print('📝 Generating summary for: $topicName');
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      // Determine document ID based on whether it's a video summary or topic summary
      final docId = videoData != null 
          ? '${courseName}_${topicName}_${videoData['videoId'] ?? videoData['title']}'
          : '${courseName}_$topicName';
      
      // Check if summary already exists in Firebase
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('summaries')
          .doc(docId);

      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data() != null) {
        final existingData = docSnap.data()!;
        print('✅ Found existing summary in Firebase');
        return {
          'success': true,
          'summary': existingData['summary'] ?? '',
          'generatedAt': existingData['generatedAt'],
        };
      }

      // Generate summary using AI
      final result = await _generateWithAI(
        topicName: topicName,
        courseName: courseName,
        difficulty: difficulty,
        userLevel: userLevel,
        videoData: videoData,
      );

      if (result['success'] == true) {
        final summary = result['summary'] as String;
        
        // Save to Firebase
        await docRef.set({
          'topicName': topicName,
          'courseName': courseName,
          'summary': summary,
          'userLevel': userLevel,
          'videoId': videoData?['videoId'],
          'videoTitle': videoData?['title'],
          'generatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Summary generated and saved');
        return {
          'success': true,
          'summary': summary,
          'generatedAt': DateTime.now().toIso8601String(),
        };
      } else {
        return result;
      }
    } catch (e, stackTrace) {
      print('❌ Error generating summary: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error generating summary: ${e.toString()}',
      };
    }
  }

  /// Generate summary using Groq API
  static Future<Map<String, dynamic>> _generateWithAI({
    required String topicName,
    required String courseName,
    required String difficulty,
    required String userLevel,
    Map<String, dynamic>? videoData,
  }) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      
      if (apiKey.isEmpty) {
        return {
          'success': false,
          'message': 'API key not configured',
        };
      }

      String prompt;
      
      if (videoData != null) {
        // Generate summary for a specific video
        final videoTitle = videoData['title'] ?? 'the video';
        final videoDescription = videoData['description'] ?? '';
        
        prompt = '''Create a concise, well-structured summary for the video: **$videoTitle**

**Context:**
- Course: $courseName
- Topic: $topicName
- Difficulty: $difficulty
- Student Level: $userLevel
- Video Description: $videoDescription

**Requirements:**
1. Write a clear, engaging summary (300-500 words) based on the video content
2. Structure with clear sections (DO NOT use ## headers, use plain text with bold labels):
   - **Overview:** What is this video about?
   - **Key Concepts:** 3-5 main points covered in the video
   - **Important Formulas/Principles:** If applicable
   - **Real-World Applications:** Where is this used?
   - **Key Takeaways:** 3-5 bullet points

3. Formatting rules:
   - DO NOT use markdown headers (##, ###) - use plain text with **Bold** labels instead
   - Use bullet points (-) for lists
   - Use **Bold** for section labels and emphasis
   - Use code blocks (```) for formulas if needed
   - Start each section on a new line with a bold label, then the content

4. Make it scannable and easy to understand
5. Adjust complexity based on level: $userLevel
6. Focus on the specific content covered in this video

Example format:
**Overview**
[Content here without ## header]

**Key Concepts**
- Point 1
- Point 2

Generate the summary now:''';
      } else {
        // Generate summary for the topic
        prompt = '''Create a concise, well-structured summary for the topic: **$topicName**

**Context:**
- Course: $courseName
- Difficulty: $difficulty
- Student Level: $userLevel

**Requirements:**
1. Write a clear, engaging summary (300-500 words)
2. Structure with clear sections (DO NOT use ## headers, use plain text with bold labels):
   - **Overview:** What is this topic about?
   - **Key Concepts:** 3-5 main points
   - **Important Formulas/Principles:** If applicable
   - **Real-World Applications:** Where is this used?
   - **Key Takeaways:** 3-5 bullet points

3. Formatting rules:
   - DO NOT use markdown headers (##, ###) - use plain text with **Bold** labels instead
   - Use bullet points (-) for lists
   - Use **Bold** for section labels and emphasis
   - Use code blocks (```) for formulas if needed
   - Start each section on a new line with a bold label, then the content

4. Make it scannable and easy to understand
5. Adjust complexity based on level: $userLevel

Example format:
**Overview**
[Content here without ## header]

**Key Concepts**
- Point 1
- Point 2

Generate the summary now:''';
      }

      print('🤖 Calling Groq API for summary generation...');
      
      final requestBody = jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert educator who creates clear, concise summaries that help students understand complex topics quickly.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 1500,
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
        var summary = jsonResponse['choices'][0]['message']['content'];
        
        // Remove markdown headers (##, ###) from the summary
        summary = _removeMarkdownHeaders(summary);
        
        print('✅ Summary generated successfully');
        return {
          'success': true,
          'summary': summary,
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

  /// Remove markdown headers (##, ###) from text
  static String _removeMarkdownHeaders(String text) {
    // Remove lines that start with ## or ###
    final lines = text.split('\n');
    final cleanedLines = lines.where((line) {
      final trimmed = line.trim();
      return !trimmed.startsWith('##') && !trimmed.startsWith('###');
    }).toList();
    
    return cleanedLines.join('\n').trim();
  }
}

