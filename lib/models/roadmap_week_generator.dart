import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper class for generating individual weeks of roadmap progressively
class RoadmapWeekGenerator {
  /// Generate AI-powered single week for progressive learning
  static Future<List<Map<String, dynamic>>?> generateSingleWeek({
    required String courseName,
    required int weekNumber,
    required String previousContext,
    required Map<String, String> mindsetProfile,
    required String studyTime,
    required String userLevel,
    required List<String> improvementAreas,
    required String preferredLanguage,
  }) async {
    try {
      final improvementFocus = improvementAreas.isNotEmpty 
          ? 'Focus areas for improvement: ${improvementAreas.join(", ")}' 
          : '';
      
      final prompt = '''You are an expert exam coach creating Week $weekNumber of a personalized $courseName study plan.

STUDENT PROFILE:
- Current Level: $userLevel
- Daily study time: $studyTime
- Preferred Language: $preferredLanguage
$improvementFocus

CONTEXT:
$previousContext

🎯 WEEK $weekNumber OBJECTIVES:
Generate a comprehensive 7-day learning plan with SPECIFIC, CONNECTED topics.

🔗 TOPIC QUALITY RULES:
1. Each topic MUST be SPECIFIC (e.g., "Calculus - Limits using L'Hospital's Rule" NOT "Calculus basics")
2. Topics MUST connect logically day-by-day (explain in "whyNow")
3. Day 1-6: Core learning with increasing complexity
4. Day 7: Practice + Review of Week $weekNumber content
5. Include 2-3 SPECIFIC YouTube channel names per topic (e.g., "3Blue1Brown", "Khan Academy", "Physics Wallah")

📚 CONTENT DEPTH:
- Focus on ${userLevel == 'Advanced' ? 'advanced concepts and problem-solving' : userLevel == 'Intermediate' ? 'core concepts with applications' : 'fundamentals with clear examples'}
- Mix difficulty: ${userLevel == 'Advanced' ? '2 medium, 4 hard, 1 revision' : userLevel == 'Intermediate' ? '2 easy, 4 medium, 1 revision' : '4 easy, 2 medium, 1 revision'}
- Ensure topics are exam-relevant and syllabus-aligned

📅 FORMAT:
Return EXACTLY 7 day objects (Day 1-7) in this JSON structure:
{
  "weekPlan": [
    {
      "day": 1,
      "week": $weekNumber,
      "weekTheme": "Descriptive theme for Week $weekNumber",
      "topic": "Specific Subject - Specific Topic Name",
      "difficulty": "easy",
      "whyNow": "Clear explanation of why this topic now and how it connects",
      "dailyBreakdown": "Detailed breakdown of what to learn",
      "includesRevision": false,
      "completed": false,
      "recommendedChannels": ["Channel1", "Channel2", "Channel3"]
    },
    ...
    {
      "day": 7,
      "week": $weekNumber,
      "topic": "Week $weekNumber Practice & Review",
      "difficulty": "medium",
      "whyNow": "Consolidate Week $weekNumber learning through practice",
      "includesRevision": true,
      "completed": false,
      "recommendedChannels": ["Practice channel 1", "Practice channel 2"]
    }
  ]
}

🚨 RETURN ONLY THE JSON, NO MARKDOWN, NO EXTRA TEXT.''';

      print('\n📤 Asking AI for Week $weekNumber...');
      final groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert educational content planner. Generate high-quality, specific learning plans with connected topics.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.8,
          'max_tokens': 2500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'];
        
        print('🤖 AI Response received');
        
        // Clean markdown
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        
        final parsed = jsonDecode(content);
        final weekPlan = parsed['weekPlan'] as List;
        
        print('✅ Generated ${weekPlan.length} days for Week $weekNumber');
        
        return weekPlan.cast<Map<String, dynamic>>();
      } else {
        print('❌ API Error: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error in generateSingleWeek: $e');
      print('Stack: $stackTrace');
      return null;
    }
  }
}
