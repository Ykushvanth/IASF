import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MindsetAnalysisBackend {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save mindset analysis answers to Firestore
  static Future<Map<String, dynamic>> saveMindsetAnalysis(
    Map<String, dynamic> answers,
  ) async {
    try {
      print('💾 Starting Firebase save...');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      print('👤 User UID: ${user.uid}');
      print('📝 Saving ${answers.length} answers to Firebase...');

      // Analyze and categorize the user based on their answers
      final userProfile = _analyzeUserProfile(answers);
      
      print('📊 Profile analyzed: ${userProfile.keys.length} properties');

      // Save everything directly to user document (bypassing subcollection permission issues)
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'mindsetAnalysisCompleted': true,
          'mindsetAnalysisCompletedAt': FieldValue.serverTimestamp(),
          'learningProfile': userProfile,
          'mindsetAnswers': answers,
        });

        print('✅ All data saved to user document');
        
        return {
          'success': true,
          'message': 'Mindset analysis saved successfully',
          'profile': userProfile,
        };
      } on FirebaseException catch (e) {
        print('❌ Firebase Exception: ${e.code} - ${e.message}');
        return {
          'success': false,
          'message': 'Firebase error: ${e.message}',
        };
      }
    } catch (e, stackTrace) {
      print('❌ Firebase save error: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to save analysis: $e',
      };
    }
  }

  /// Analyze user's learning profile based on their answers
  static Map<String, dynamic> _analyzeUserProfile(Map<String, dynamic> answers) {
    final profile = <String, dynamic>{};

    // Study Time Analysis
    profile['studyHoursCategory'] = _categorizeStudyHours(answers['q1']);

    // Direction Clarity Analysis
    profile['directionClarity'] = _categorizeDirectionClarity(answers['q3']);

    // Confusion Factors
    if (answers['q4'] != null) {
      profile['confusionFactors'] = answers['q4'];
    }

    // Time Management Issues
    profile['timeWastageFrequency'] = answers['q5'];

    // Memory & Retention
    profile['forgettingFrequency'] = answers['q6'];
    profile['forgettingRealizationPoint'] = answers['q7'];
    profile['frustrationSource'] = answers['q8'];

    // Practice Habits
    profile['regularPractice'] = answers['q9'] == 'Yes';

    // Emotional State
    profile['examEmotionalState'] = answers['q10'];
    profile['confidenceIssues'] = answers['q11'];
    profile['postSuccessBehavior'] = answers['q12'];

    // Study Session Experience
    profile['longSessionExperience'] = answers['q13'];
    profile['fatigueReaction'] = answers['q14'];

    // Personal Reflection
    profile['recentLearningChallenge'] = answers['q15'];

    // Calculate overall learning scores
    profile['scores'] = _calculateLearningScores(answers);

    // Determine key areas to focus on
    profile['recommendedFocusAreas'] = _determinesFocusAreas(answers);

    return profile;
  }

  static String _categorizeStudyHours(String? hours) {
    switch (hours) {
      case 'Less than 1 hour':
        return 'low';
      case '1–2 hours':
        return 'moderate';
      case '2–4 hours':
        return 'good';
      case 'More than 4 hours':
        return 'high';
      default:
        return 'unknown';
    }
  }

  static String _categorizeDirectionClarity(String? clarity) {
    switch (clarity) {
      case 'Very clear':
        return 'excellent';
      case 'Somewhat clear':
        return 'good';
      case 'Often confused':
        return 'needs_improvement';
      case 'Completely confused':
        return 'critical';
      default:
        return 'unknown';
    }
  }

  static Map<String, int> _calculateLearningScores(Map<String, dynamic> answers) {
    // Scoring system (0-100 for each category)
    
    // Direction & Planning Score
    int directionScore = 50;
    if (answers['q3'] == 'Very clear') directionScore = 90;
    else if (answers['q3'] == 'Somewhat clear') directionScore = 70;
    else if (answers['q3'] == 'Often confused') directionScore = 40;
    else if (answers['q3'] == 'Completely confused') directionScore = 20;

    // Retention & Memory Score
    int retentionScore = 50;
    if (answers['q6'] == 'Rarely') retentionScore = 90;
    else if (answers['q6'] == 'Sometimes') retentionScore = 70;
    else if (answers['q6'] == 'Often') retentionScore = 40;
    else if (answers['q6'] == 'Almost always') retentionScore = 20;

    // Practice Consistency Score
    int practiceScore = answers['q9'] == 'Yes' ? 80 : 30;

    // Emotional Stability Score
    int emotionalScore = 50;
    if (answers['q10'] == 'Motivation drop') emotionalScore = 30;
    else if (answers['q10'] == 'Panic') emotionalScore = 35;
    else if (answers['q10'] == 'Self-doubt') emotionalScore = 40;
    else if (answers['q10'] == 'Fear') emotionalScore = 45;

    // Time Management Score
    int timeManagementScore = 50;
    if (answers['q5'] == 'Rarely') timeManagementScore = 90;
    else if (answers['q5'] == 'Sometimes') timeManagementScore = 70;
    else if (answers['q5'] == 'Often') timeManagementScore = 40;
    else if (answers['q5'] == 'Almost always') timeManagementScore = 20;

    // Overall Score (average of all)
    int overallScore = ((directionScore + retentionScore + practiceScore + 
                        emotionalScore + timeManagementScore) / 5).round();

    return {
      'direction': directionScore,
      'retention': retentionScore,
      'practice': practiceScore,
      'emotional': emotionalScore,
      'timeManagement': timeManagementScore,
      'overall': overallScore,
    };
  }

  static List<String> _determinesFocusAreas(Map<String, dynamic> answers) {
    final focusAreas = <String>[];

    // Check direction clarity
    if (answers['q3'] == 'Often confused' || answers['q3'] == 'Completely confused') {
      focusAreas.add('Study Planning & Direction');
    }

    // Check retention issues
    if (answers['q6'] == 'Often' || answers['q6'] == 'Almost always') {
      focusAreas.add('Memory & Retention Techniques');
    }

    // Check practice habits
    if (answers['q9'] == 'No') {
      focusAreas.add('Regular Practice & Application');
    }

    // Check emotional issues
    if (answers['q10'] != null) {
      focusAreas.add('Emotional Management & Confidence');
    }

    // Check time management
    if (answers['q5'] == 'Often' || answers['q5'] == 'Almost always') {
      focusAreas.add('Time Management & Prioritization');
    }

    // Check fatigue management
    if (answers['q13'] != null && 
        (answers['q13'] == 'Stress' || answers['q13'] == 'Fatigue' || 
         answers['q13'] == 'Motivation swings')) {
      focusAreas.add('Stress Management & Study Breaks');
    }

    // If no specific issues, focus on optimization
    if (focusAreas.isEmpty) {
      focusAreas.add('Advanced Learning Optimization');
    }

    return focusAreas;
  }

  /// Get user's mindset analysis
  static Future<Map<String, dynamic>?> getMindsetAnalysis(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('mindset_analysis')
          .doc('latest')
          .get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Summarize mindset analysis using Groq API
  static Future<Map<String, dynamic>> summarizeWithGroq(
    Map<String, dynamic> answers,
    Map<String, dynamic> profile,
  ) async {
    try {
      // Get API key from config
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      
      if (apiKey.isEmpty) {
        print('❌ API key not configured');
        return {
          'success': false,
          'message': 'Please configure your Groq API key in lib/config/api_keys.dart',
        };
      }
      
      if (!apiKey.startsWith('gsk_')) {
        print('❌ Invalid API key format');
        return {
          'success': false,
          'message': 'Invalid Groq API key format. Key should start with "gsk_"',
        };
      }
      
      // Prepare the data for summarization
      final analysisData = _prepareAnalysisText(answers, profile);
      
      print('🔄 Calling Groq API with key: ${apiKey.substring(0, 10)}...');
      print('📝 Analysis data length: ${analysisData.length} characters');
      
      // Call Groq API
      final requestBody = jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a caring learning mentor. Read the student\'s answers and write a friendly 2-3 paragraph message. Focus on: 1) Where they might be struggling based on their answers (confusion, forgetting, time management, confidence, etc), 2) One simple tip to help them improve in that area, 3) An encouraging closing. Be warm, personal, and avoid using scores or numbers. Speak directly to them like a friend.',
          },
          {
            'role': 'user',
            'content': 'Based on these answers, write a caring message about where this student is struggling and how they can improve:\n\n$analysisData',
          },
        ],
        'temperature': 0.8,
        'max_tokens': 300,
      });
      
      print('📤 Sending request to Groq...');
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: requestBody,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ HTTP request timed out after 10 seconds');
          throw http.ClientException('Request timeout after 10 seconds');
        },
      );
      
      print('📥 Response received');

      print('✅ Groq API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final summary = jsonResponse['choices'][0]['message']['content'];
        
        print('✅ Summary received: ${summary.substring(0, 100)}...');
        
        // Save summary to Firebase
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('mindset_analysis')
                .doc('latest')
                .update({
              'aiSummary': summary,
              'summarizedAt': FieldValue.serverTimestamp(),
            });
            
            // Also save to main user document
            await _firestore.collection('users').doc(user.uid).update({
              'latestAiSummary': summary,
            });
            
            print('✅ Summary saved to Firebase');
          } catch (fbError) {
            // Firebase save failed but we still have the summary
            // Silently continue - summary is still available
          }
        }

        return {
          'success': true,
          'summary': summary,
        };
      } else {
        final errorBody = response.body;
        print('❌ Groq API error ${response.statusCode}: $errorBody');
        
        // Try to parse error message from response
        String errorMessage = 'API returned status ${response.statusCode}';
        try {
          final errorJson = jsonDecode(errorBody);
          if (errorJson['error'] != null && errorJson['error']['message'] != null) {
            errorMessage = errorJson['error']['message'];
          }
        } catch (e) {
          // Couldn't parse error, use default
        }
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } on http.ClientException {
      print('❌ Network error: Unable to connect to Groq API');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to Groq API. Check your internet connection.',
      };
    } on FormatException {
      print('❌ Invalid response from Groq API');
      return {
        'success': false,
        'message': 'Invalid response from Groq API',
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }

  /// Prepare analysis text for Groq API
  static String _prepareAnalysisText(
    Map<String, dynamic> answers,
    Map<String, dynamic> profile,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('STUDENT ANSWERS:');
    buffer.writeln();
    
    buffer.writeln('1. Daily study time: ${answers['q1']}');
    buffer.writeln('2. Feels organized about studies: ${answers['q2']}');
    buffer.writeln('3. Direction about what to study: ${answers['q3']}');
    
    if (answers['q4'] != null && (answers['q4'] as List).isNotEmpty) {
      buffer.writeln('4. Main confusions: ${(answers['q4'] as List).join(', ')}');
    }
    
    buffer.writeln('5. Feels time is wasted: ${answers['q5']}');
    buffer.writeln('6. Forgets what studied: ${answers['q6']}');
    buffer.writeln('7. Realizes forgetting: ${answers['q7']}');
    buffer.writeln('8. Most frustrating: ${answers['q8']}');
    buffer.writeln('9. Practices regularly: ${answers['q9']}');
    buffer.writeln('10. Before exams feels: ${answers['q10']}');
    buffer.writeln('11. Confidence during tests: ${answers['q11']}');
    buffer.writeln('12. After doing well: ${answers['q12']}');
    buffer.writeln('13. During long study sessions: ${answers['q13']}');
    buffer.writeln('14. When tired but deadline near: ${answers['q14']}');
    buffer.writeln('15. Recent challenge: ${answers['q15'] ?? 'Not provided'}');
    
    return buffer.toString();
  }
}
