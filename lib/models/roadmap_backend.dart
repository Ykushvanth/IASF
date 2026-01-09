import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:eduai/models/roadmap_week_generator.dart';

/// RoadmapBackend - Generates personalized learning roadmaps with topic-specific videos
/// 
/// KEY FEATURES:
/// - Generates UNIQUE, SPECIFIC topics for each day (no repetition)
/// - Topic-specific video search (e.g., "Mathematics - Differential Calculus" not "Study Math")
/// - User's preferred language support for videos
/// - Recommended YouTube channels prioritization
/// - Concise video duration filter (4-20 minutes)
/// - Week-based generation for >30 days, day-by-day for ≤30 days
///
/// IMPROVEMENTS (Dec 29, 2024):
/// - AI prompts now demand specific topics (e.g., "Linear Algebra - Matrices" not "Week 1 Math")
/// - Video search includes course context for better relevance
/// - Language preference integrated into video queries
/// - Removes generic words from topics for cleaner searches
class RoadmapBackend {
  /// Generate only the next week of roadmap based on completed progress
  static Future<Map<String, dynamic>> generateNextWeek({
    required String courseName,
  }) async {
    print('═══════════════════════════════════════════════════════');
    print('📅 Generating NEXT WEEK of roadmap');
    print('📚 Course: $courseName');
    print('═══════════════════════════════════════════════════════');
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }
      
      // Get current roadmap and user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final existingRoadmap = (userDoc.data()?['roadmap'] as List?) ?? [];
      final courseAnswers = userDoc.data()?['courseAnswers'] as Map<String, dynamic>? ?? {};
      final mindsetProfile = <String, String>{};
      final rawAnswers = userDoc.data()?['mindsetAnswers'] ?? {};
      
      if (rawAnswers is Map) {
        rawAnswers.forEach((key, value) {
          if (value is String) {
            mindsetProfile[key.toString()] = value;
          } else if (value is List) {
            mindsetProfile[key.toString()] = value.join(', ');
          }
        });
      }
      
      // Calculate which week to generate
      int nextWeekNumber = 1;
      if (existingRoadmap.isNotEmpty) {
        final weeks = existingRoadmap.map((item) => item['week'] ?? 1).toList();
        nextWeekNumber = weeks.reduce((a, b) => a > b ? a : b) + 1;
      }
      
      print('📊 Next week to generate: Week $nextWeekNumber');
      print('📋 Existing roadmap has ${existingRoadmap.length} items');
      
      // Get previous week's topics for context
      String previousContext = '';
      if (existingRoadmap.isNotEmpty) {
        final lastWeekItems = existingRoadmap.where((item) => item['week'] == nextWeekNumber - 1).toList();
        if (lastWeekItems.isNotEmpty) {
          final topics = lastWeekItems.map((item) => item['topic'] ?? '').join(', ');
          previousContext = 'Last week covered: $topics. Build upon these concepts.';
        }
      }
      
      // Generate the next week
      final studyTime = courseAnswers['q4'] ?? 'Not specified';
      final targetDate = courseAnswers['q5'] ?? 'Not specified';
      final currentKnowledge = courseAnswers['q2'] ?? 'Not specified';
      final preferredLanguage = userDoc.data()?['preferredLanguage'] as String? ?? 'English';
      final userLevel = userDoc.data()?['userLevel'] as String? ?? 'Intermediate';
      final improvementAreas = (userDoc.data()?['improvementAreas'] as List?)?.cast<String>() ?? [];
      
      final nextWeekData = await RoadmapWeekGenerator.generateSingleWeek(
        courseName: courseName,
        weekNumber: nextWeekNumber,
        previousContext: previousContext,
        mindsetProfile: mindsetProfile,
        studyTime: studyTime.toString(),
        userLevel: userLevel,
        improvementAreas: improvementAreas,
        preferredLanguage: preferredLanguage,
      );
      
      if (nextWeekData == null || nextWeekData.isEmpty) {
        return {'success': false, 'message': 'Failed to generate week content'};
      }
      
      // Fetch videos for the new week
      final weekWithVideos = await _fetchVideosForRoadmap(
        nextWeekData,
        courseName,
        mindsetProfile,
        preferredLanguage,
      );
      
      // Append to existing roadmap
      final updatedRoadmap = [...existingRoadmap, ...weekWithVideos];
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'roadmap': updatedRoadmap,
        'currentWeek': nextWeekNumber,
        'lastWeekGeneratedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Week $nextWeekNumber generated and added!');
      print('═══════════════════════════════════════════════════════\n');
      
      return {
        'success': true,
        'weekNumber': nextWeekNumber,
        'weekData': weekWithVideos,
        'message': 'Week $nextWeekNumber generated successfully',
      };
    } catch (e, stackTrace) {
      print('❌ Error generating next week: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> generateRoadmap({
    required String courseName,
    required Map<String, String> mindsetProfile,
    bool forceRegenerate = false,
    String? userLevel,
    List<String>? improvementAreas,
    int? studyHoursPerDay,
    int? daysUntilExam,
  }) async {
    print('═══════════════════════════════════════════════════════');
    print('🗺️ Starting PERSONALIZED roadmap generation');
    print('📚 Course: $courseName');
    print('🧠 Mindset profile keys: ${mindsetProfile.keys.join(", ")}');
    print('🔄 Force regenerate: $forceRegenerate');
    if (userLevel != null) print('📊 User Level: $userLevel');
    if (improvementAreas != null) print('📈 Improvement Areas: ${improvementAreas.join(", ")}');
    if (studyHoursPerDay != null) print('⏰ Study Hours/Day: $studyHoursPerDay');
    if (daysUntilExam != null) print('📅 Days Until Exam: $daysUntilExam');
    print('═══════════════════════════════════════════════════════');
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        print('❌ CRITICAL ERROR: No user logged in');
        return {'success': false, 'message': 'User not logged in. Please sign in again.'};
      }
      
      print('✅ User authenticated: ${user.uid}');

      // Get user's course answers to understand their goals
      print('📋 Fetching user profile and goals...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final courseAnswers = userDoc.data()?['courseAnswers'] as Map<String, dynamic>? ?? {};
      final preferredLanguage = userDoc.data()?['preferredLanguage'] as String? ?? 'English';
      print('🌍 User preferred language: $preferredLanguage');
      
      // Check if roadmap already exists
      final existingRoadmap = userDoc.data()?['roadmap'] as List?;
      if (!forceRegenerate && existingRoadmap != null && existingRoadmap.isNotEmpty) {
        print('ℹ️ Roadmap already exists with ${existingRoadmap.length} items');
        print('💡 To regenerate, use forceRegenerate = true');
        // Convert existing roadmap to proper format and return as success
        final roadmapList = (existingRoadmap as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return {
          'success': true,
          'message': 'Roadmap loaded from existing data.',
          'roadmap': roadmapList,
        };
      }
      
      // Store user level and improvement areas for week generation
      if (userLevel != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'userLevel': userLevel,
          'improvementAreas': improvementAreas ?? [],
        });
      }
      
      if (forceRegenerate && existingRoadmap != null && existingRoadmap.isNotEmpty) {
        print('🗑️ Clearing existing roadmap (${existingRoadmap.length} items) for regeneration...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'roadmap': [],
          'roadmapGeneratedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Old roadmap cleared');
      }
      
      // Generate ONLY FIRST WEEK initially (progressive generation)
      print('🤖 Generating FIRST WEEK of personalized roadmap...');
      final firstWeekData = await RoadmapWeekGenerator.generateSingleWeek(
        courseName: courseName,
        weekNumber: 1,
        previousContext: 'This is the first week - establish strong fundamentals.',
        mindsetProfile: mindsetProfile,
        studyTime: courseAnswers['q4']?.toString() ?? '2-3 hours',
        userLevel: userLevel ?? 'Intermediate',
        improvementAreas: improvementAreas ?? [],
        preferredLanguage: preferredLanguage,
      );

      if (firstWeekData == null || firstWeekData.isEmpty) {
        print('⚠️ First week generation failed, using structured fallback');
        // Use structured topics without videos initially
        final topics = _getCourseTopics(courseName);
        final roadmap = topics.asMap().entries.map((entry) {
          final index = entry.key;
          final topic = entry.value;
          return {
            'day': index + 1,
            'week': 1,
            'topic': 'Step ${index + 1}: ${topic['name']}',
            'difficulty': topic['difficulty'],
            'whyNow': topic['whyNow'] ?? 'Essential topic in the curriculum',
            'includesRevision': false,
            'videos': [],
            'completed': false,
            'isSubject': topic['isSubject'] ?? false,
            if (topic['topics'] != null) 'topics': topic['topics'],
          };
        }).toList();
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'roadmap': roadmap,
          'currentWeek': 1,
          'roadmapGeneratedAt': FieldValue.serverTimestamp(),
        });
        
        return {
          'success': true,
          'roadmap': roadmap,
        };
      }

      // Fetch videos for first week
      print('\n🎥 Fetching videos for Week 1...');
      final weekWithVideos = await _fetchVideosForRoadmap(
        firstWeekData,
        courseName,
        mindsetProfile,
        preferredLanguage,
      );
      
      // Save first week to Firebase
      print('\n💾 Saving Week 1 to Firebase...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'roadmap': weekWithVideos,
        'currentWeek': 1,
        'roadmapGeneratedAt': FieldValue.serverTimestamp(),
      });

      print('✅ FIRST WEEK SAVED! User can generate next weeks progressively.');
      print('📊 Week 1 items: ${weekWithVideos.length}');
      print('═══════════════════════════════════════════════════════\n');
      
      return {
        'success': true,
        'roadmap': weekWithVideos,
        'message': 'Week 1 generated. Complete it to unlock Week 2!',
      };
    } catch (e, stackTrace) {
      print('\n❌ CRITICAL ERROR generating roadmap: $e');
      print('📋 Stack trace:\n$stackTrace');
      print('═══════════════════════════════════════════════════════\n');
      return {
        'success': false,
        'message': 'Failed to generate roadmap: ${e.toString()}',
      };
    }
  }

  /// Generate AI-powered personalized roadmap like a teacher would
  static Future<List<Map<String, dynamic>>?> _generatePersonalizedRoadmap({
    required String courseName,
    required Map<String, String> mindsetProfile,
    required Map<String, dynamic> courseAnswers,
    required String preferredLanguage,
  }) async {
    try {
      // Build teacher-like assessment
      final studyTime = courseAnswers['q4'] ?? 'Not specified';
      final targetDate = courseAnswers['q5'] ?? 'Not specified';
      final currentKnowledge = courseAnswers['q2'] ?? 'Not specified';
      
      // Calculate exact number of days based on target date
      int totalDays = _calculateDaysFromTarget(targetDate as String, studyTime as String);
      print('📅 Calculated total days for roadmap: $totalDays');
      
      final confusion = mindsetProfile['confusionFactors'] ?? 'none';
      
      // Use week-based structure for longer roadmaps to avoid token limits
      final useWeeklyStructure = totalDays > 30;
      final structureType = useWeeklyStructure ? 'WEEK-BY-WEEK' : 'DAY-BY-DAY';
      final totalWeeks = (totalDays / 7).ceil();
      
      final prompt = useWeeklyStructure ? '''You are an expert exam coach creating a COMPLETE $courseName preparation roadmap for $totalWeeks weeks.

STUDENT PROFILE:
- Daily study: $studyTime | Target: $targetDate ($totalDays days = $totalWeeks weeks)
- Current level: $currentKnowledge | Language: $preferredLanguage
- Learning challenges: $confusion

🎯 EXAM-READY GOAL: Cover ALL syllabus topics systematically to ensure complete preparation.

🔗 LOGICAL PROGRESSION RULES:
1. Each topic must BUILD ON previous topics (e.g., "Functions" only after "Variables")
2. In "whyNow" field, EXPLAIN how today's topic connects to yesterday's learning
3. Start with fundamentals → intermediate → advanced → practice → mock tests
4. Every 7th day: Review + Practice previous 6 days' topics
5. Final 2 weeks: Full syllabus revision + mock exams

📚 COVERAGE REQUIREMENTS:
- Include ALL major subjects/topics for $courseName exam
- No topic left behind - comprehensive coverage
- Balance theory (60%) + practice (30%) + revision (10%)
- Recommended YouTube channels for EACH topic

🚨 CRITICAL: Generate EXACTLY $totalWeeks week objects (week 1 to $totalWeeks).
🚨 COUNT VERIFICATION: Week 1, 2, 3... $totalWeeks (MUST = $totalWeeks elements!)

FORMAT (dailyBreakdown): "Day 1: Topic • Day 2: Topic • Day 3: Topic • Day 4: Topic • Day 5: Topic • Day 6: Topic • Day 7: Revision"

JSON FORMAT:
{
  "roadmap": [
    {"week": 1, "weekTheme": "Subject Area", "topic": "Week 1 Focus", "dailyBreakdown": "Day 1: Topic1 • Day 2: Topic2 • Day 3: Topic3 • Day 4: Topic4 • Day 5: Topic5 • Day 6: Topic6 • Day 7: Practice", "difficulty": "easy", "whyNow": "Foundation for later topics", "includesRevision": false, "recommendedChannels": ["Channel1", "Channel2"]},
    {"week": 2, "whyNow": "Builds on Week 1 by...", ...},
    ...
    {"week": $totalWeeks, "whyNow": "Final preparation building on all previous weeks", ...}
  ],
  "teacherNote": "Complete exam strategy with progression",
  "studyTips": ["Tip1", "Tip2"]
}

🚨 VERIFY: Array length MUST = $totalWeeks before responding!''' : '''You are an expert exam coach creating a COMPLETE $courseName preparation roadmap for $totalDays days.

STUDENT PROFILE:
- Daily study: $studyTime | Target: $targetDate ($totalDays days)
- Current level: $currentKnowledge | Language: $preferredLanguage
- Learning challenges: $confusion

🎯 EXAM-READY GOAL: Cover ALL syllabus topics systematically with logical progression.

🔗 LOGICAL PROGRESSION RULES:
1. Each day's topic must BUILD ON previous day's learning
2. In "whyNow" field, EXPLAIN how today connects to yesterday (e.g., "After learning variables yesterday, functions will use them")
3. Progression: Basics → Fundamentals → Intermediate → Advanced → Practice → Mock Tests
4. Every 7th day: Practice + Review previous 6 days
5. Last week: Full syllabus revision + timed mock exams

📚 COVERAGE REQUIREMENTS:
- Include ALL major topics/subjects for $courseName exam
- Complete syllabus coverage - nothing skipped
- Balance: Theory (60%) + Problem solving (30%) + Revision (10%)
- Provide 2-3 recommended YouTube channels for EACH topic

🚨 CRITICAL: Generate EXACTLY $totalDays day objects (day 1 to $totalDays).
🚨 COUNT VERIFICATION: Day 1, 2, 3... $totalDays (MUST = $totalDays elements!)

Each day = ONE SPECIFIC topic (e.g., "Calculus - Limits & Derivatives", "DBMS - Normalization").

JSON FORMAT:
{
  "roadmap": [
    {"day": 1, "week": 1, "weekTheme": "Foundation", "topic": "Specific Topic 1", "difficulty": "easy", "whyNow": "Starting point for all concepts", "includesRevision": false, "recommendedChannels": ["Channel1", "Channel2"]},
    {"day": 2, "week": 1, "topic": "Specific Topic 2", "whyNow": "Builds on Day 1 by...", ...},
    {"day": 7, "week": 1, "topic": "Week 1 Practice", "whyNow": "Consolidate Days 1-6", "includesRevision": true, ...},
    ...
    {"day": $totalDays, "topic": "Final Mock Test", "whyNow": "Test all learned concepts", ...}
  ],
  "teacherNote": "Complete strategy with connected learning path",
  "studyTips": ["Tip1", "Tip2", "Tip3"]
}

🚨 VERIFY: Array length MUST = $totalDays before responding!''';

      print('\n📤 Asking AI teacher for roadmap...');
      print('📊 Course: $courseName');
      print('⏱️ Study time: $studyTime');
      print('🎯 Target: $targetDate');
      print('🌍 Language: $preferredLanguage');
      final groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      print('🔑 API Key configured: ${groqApiKey.isNotEmpty}');
      print('🔑 API Key length: ${groqApiKey.length} chars');
      
      print('\n🌐 Making API request to Groq...');
      print('📊 Structure: $structureType (${useWeeklyStructure ? "$totalWeeks weeks" : "$totalDays days"})');
      
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
              'content': 'You are an expert exam preparation coach. Create roadmaps with COMPLETE syllabus coverage and LOGICAL PROGRESSION where each topic builds on previous ones. Always respond with valid JSON only (no markdown). Generate EXACTLY the requested number of ${useWeeklyStructure ? "weeks" : "days"}. Each "whyNow" must explain connection to previous topics.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': useWeeklyStructure ? 12000 : 16000,
        }),
      ).timeout(
        Duration(seconds: useWeeklyStructure ? 45 : 60),
        onTimeout: () {
          print('⏱️ AI API request timed out');
          throw Exception('AI API timeout - please try again');
        },
      );

      print('\n📬 Received API response: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('❌ AI API ERROR: Status ${response.statusCode}');
        print('📄 Response body: ${response.body}');
        print('💡 Possible causes:');
        print('   - Invalid or expired API key');
        print('   - Rate limit exceeded');
        print('   - Network connectivity issues');
        return null;
      }

      final data = jsonDecode(response.body);
      
      if (data['choices'] == null || (data['choices'] as List).isEmpty) {
        print('❌ No choices in AI response');
        return null;
      }
      
      String content = data['choices'][0]['message']['content'] as String;
      
      print('📄 Raw AI response length: ${content.length} characters');
      print('📄 Response preview: ${content.substring(0, content.length > 200 ? 200 : content.length)}...');
      
      // Clean markdown and extra formatting
      content = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // Try to find JSON in the content
      int jsonStart = content.indexOf('{');
      int jsonEnd = content.lastIndexOf('}') + 1;
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        content = content.substring(jsonStart, jsonEnd);
        print('📄 Extracted JSON from position $jsonStart to $jsonEnd');
      }
      
      print('📄 Final content length: ${content.length} characters');
      
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(content) as Map<String, dynamic>;
        print('✅ Successfully parsed JSON');
      } catch (e) {
        print('❌ JSON parsing failed: $e');
        print('📄 Content that failed to parse: $content');
        return null;
      }
      final roadmapData = parsed['roadmap'];
      final teacherNote = parsed['teacherNote'] ?? '';
      final studyTips = parsed['studyTips'] as List? ?? [];
      
      // Handle if roadmapData is null or not a list
      if (roadmapData == null || roadmapData is! List) {
        print('⚠️ Invalid roadmap data format from AI');
        return null;
      }
      
      final List<dynamic> roadmapList = roadmapData;
      
      print('\n📊 AI GENERATION RESULTS:');
      print('   Expected: ${useWeeklyStructure ? "$totalWeeks weeks" : "$totalDays days"}');
      print('   Received: ${roadmapList.length} items from AI');
      if (useWeeklyStructure && roadmapList.length < totalWeeks) {
        print('   ⚠️ AI GENERATED TOO FEW WEEKS! Got ${roadmapList.length}, need $totalWeeks');
      }
      
      print('👨‍🏫 Teacher note: $teacherNote');
      if (studyTips.isNotEmpty) {
        print('💡 Study tips: ${studyTips.join(", ")}');
      }
      
      // Convert to app format with null safety
      List<Map<String, dynamic>> roadmap = [];
      int skippedItems = 0;
      
      for (var item in roadmapList) {
        if (item == null || item is! Map) {
          skippedItems++;
          continue;
        }
        
        final itemMap = item as Map<String, dynamic>;
        final dayNumber = itemMap['day'];
        final weekNumber = itemMap['week'];
        final weekTheme = itemMap['weekTheme'];
        final topicName = itemMap['topic'];
        final difficultyValue = itemMap['difficulty'];
        final whyNow = itemMap['whyNow'];
        final includesRevision = itemMap['includesRevision'] ?? false;
        final recommendedChannels = itemMap['recommendedChannels'] as List? ?? [];
        final targetMarks = itemMap['targetMarks'];
        
        if (topicName == null || difficultyValue == null) {
          skippedItems++;
          print('⚠️ Skipping item with missing topic or difficulty');
          continue;
        }
        
        // Calculate week from day number if not provided by AI
        final actualDay = dayNumber ?? (roadmap.length + 1);
        final actualWeek = weekNumber ?? ((actualDay - 1) ~/ 7 + 1);
        
        final Map<String, dynamic> topic = {
          'day': actualDay,
          'week': actualWeek,
          'weekTheme': weekTheme?.toString() ?? '',
          'topic': topicName.toString(),
          'difficulty': difficultyValue.toString(),
          'whyNow': whyNow?.toString() ?? '',
          'includesRevision': includesRevision,
          'recommendedChannels': recommendedChannels.map((e) => e.toString()).toList(),
          'videos': [],
          'completed': false,
        };
        
        if (targetMarks != null) {
          topic['targetMarks'] = targetMarks.toString();
        }
        
        roadmap.add(topic);
      }
      
      if (skippedItems > 0) {
        print('⚠️ Skipped $skippedItems invalid items');
      }
      
      print('✅ Generated ${roadmap.length} personalized steps');
      print('📅 Expected: $totalDays days, Generated: ${roadmap.length} items');
      
      if (roadmap.isEmpty) {
        print('❌ No valid roadmap items generated!');
        return null;
      }
      
      // CRITICAL FIX: If using weekly structure but AI generated insufficient weeks, add generic weeks
      if (useWeeklyStructure && roadmap.length < totalWeeks) {
        final missingWeeks = totalWeeks - roadmap.length;
        print('\n⚠️⚠️⚠️ AI WEEK GENERATION SHORTFALL ⚠️⚠️⚠️');
        print('   AI generated: ${roadmap.length} weeks');
        print('   Required: $totalWeeks weeks');
        print('   Missing: $missingWeeks weeks');
        print('   🔧 Generating $missingWeeks fallback weeks to complete roadmap...');
        
        // Default recommended channels for fallback weeks
        final List<String> defaultChannels = ['Khan Academy', 'Crash Course'];
        
        // Generate fallback weeks to fill the gap
        for (int weekNum = roadmap.length + 1; weekNum <= totalWeeks; weekNum++) {
          roadmap.add({
            'week': weekNum,
            'weekTheme': 'Week $weekNum Study',
            'topic': 'Week $weekNum Topics',
            'dailyBreakdown': 'Day 1: Review and Practice • Day 2: Problem Solving • Day 3: Advanced Concepts • Day 4: Application • Day 5: Mock Tests • Day 6: Revision • Day 7: Assessment',
            'difficulty': 'medium',
            'whyNow': 'Continuing structured learning',
            'includesRevision': weekNum % 4 == 0,
            'recommendedChannels': defaultChannels,
            'videos': [],
            'completed': false,
          });
        }
        print('✅ Added ${totalWeeks - roadmap.length} fallback weeks. Total: ${roadmap.length} weeks');
      }
      
      // If using weekly structure, expand weeks into individual days
      List<Map<String, dynamic>> expandedRoadmap = roadmap;
      if (useWeeklyStructure && roadmap.isNotEmpty) {
        print('📅 Expanding ${roadmap.length} weeks into daily items...');
        print('📊 Target: $totalDays days from $totalWeeks weeks');
        expandedRoadmap = [];
        
        for (int i = 0; i < roadmap.length; i++) {
          final weekItem = roadmap[i];
          final weekNumber = (weekItem['week'] as int?) ?? (i + 1);
          final weekTheme = (weekItem['weekTheme'] as String?) ?? 'Week $weekNumber';
          final weekTopic = (weekItem['topic'] as String?) ?? 'Study topics';
          final difficulty = (weekItem['difficulty'] as String?) ?? 'medium';
          final channels = (weekItem['recommendedChannels'] as List?) ?? [];
          final dailyBreakdown = weekItem['dailyBreakdown'] as String?;
          
          if (i == 0 || i == roadmap.length - 1 || i % 5 == 0) {
            print('📖 Processing Week $weekNumber: ${weekTheme.substring(0, weekTheme.length > 40 ? 40 : weekTheme.length)}...');
          }
          
          // Parse daily breakdown with multiple pattern attempts for robustness
          List<String> dailyTopics = [];
          if (dailyBreakdown != null && dailyBreakdown.isNotEmpty) {
            print('📖 Parsing daily breakdown: ${dailyBreakdown.substring(0, dailyBreakdown.length > 100 ? 100 : dailyBreakdown.length)}...');
            
            // Try multiple patterns to extract daily topics
            // Pattern 1: "Day 1: Topic • Day 2: Topic"
            var dayPattern = RegExp(r'Day \d+:\s*([^•]+)', multiLine: true);
            var matches = dayPattern.allMatches(dailyBreakdown);
            dailyTopics = matches.map((m) => m.group(1)?.trim() ?? '').where((t) => t.isNotEmpty).toList();
            
            // Pattern 2: If no bullet points, try newline separation
            if (dailyTopics.isEmpty) {
              dayPattern = RegExp(r'Day \d+:\s*([^\n]+)', multiLine: true);
              matches = dayPattern.allMatches(dailyBreakdown);
              dailyTopics = matches.map((m) => m.group(1)?.trim() ?? '').where((t) => t.isNotEmpty).toList();
            }
            
            // Pattern 3: If still empty, split by commas or semicolons
            if (dailyTopics.isEmpty) {
              final topics = dailyBreakdown.split(RegExp(r'[,;]'));
              dailyTopics = topics.map((t) => t.replaceAll(RegExp(r'Day \d+:\s*'), '').trim()).where((t) => t.isNotEmpty).toList();
            }
            
            print('✅ Extracted ${dailyTopics.length} daily topics from breakdown');
            if (dailyTopics.isNotEmpty) {
              print('   First topic: ${dailyTopics[0]}');
            }
          }
          
          // Create 7 daily items for this week
          for (int dayInWeek = 1; dayInWeek <= 7; dayInWeek++) {
            final dayNumber = (weekNumber - 1) * 7 + dayInWeek;
            if (dayNumber <= totalDays) {
              // Use specific daily topic if available
              String dayTopic;
              if (dailyTopics.isNotEmpty && dayInWeek <= dailyTopics.length) {
                dayTopic = dailyTopics[dayInWeek - 1];
                // Remove any remaining "Day N:" prefix from the topic
                dayTopic = dayTopic.replaceAll(RegExp(r'^Day \d+:\s*'), '').trim();
              } else if (dailyTopics.isNotEmpty) {
                // Cycle through available topics if we have fewer than 7
                dayTopic = dailyTopics[(dayInWeek - 1) % dailyTopics.length];
                dayTopic = dayTopic.replaceAll(RegExp(r'^Day \d+:\s*'), '').trim();
              } else {
                // Fallback: Generate meaningful daily topics based on week theme
                // Extract subject from week theme and create logical progression
                dayTopic = _generateFallbackTopic(weekTheme, weekTopic, dayInWeek, courseName);
              }
              
              // Ensure topic is not empty or too generic
              if (dayTopic.isEmpty || dayTopic.length < 5) {
                dayTopic = _generateFallbackTopic(weekTheme, weekTopic, dayInWeek, courseName);
              }
              
              // Remove any "Part X" patterns that might have slipped through
              if (dayTopic.contains('Part') && RegExp(r'Part \d+').hasMatch(dayTopic)) {
                dayTopic = _generateFallbackTopic(weekTheme, weekTopic, dayInWeek, courseName);
              }
              
              print('📝 Day $dayNumber: $dayTopic');
              
              expandedRoadmap.add({
                'day': dayNumber,
                'week': weekNumber,
                'weekTheme': weekTheme,
                'topic': dayTopic,
                'difficulty': difficulty,
                'whyNow': weekItem['whyNow']?.toString() ?? '',
                'includesRevision': weekItem['includesRevision'] ?? false,
                'recommendedChannels': channels.map((e) => e.toString()).toList(),
                'videos': [],
                'completed': false,
              });
            }
          }
        }
        print('✅ Expanded ${roadmap.length} weeks to ${expandedRoadmap.length} daily items');
      }
      
      // Warn if generated days don't match expected
      if (expandedRoadmap.length < totalDays) {
        print('⚠️ WARNING: Generated ${expandedRoadmap.length} days instead of $totalDays');
        print('⚠️ This might be due to AI model limitations or token limits');
      } else {
        print('✅ SUCCESS: Generated all ${expandedRoadmap.length} days as expected!');
      }
      
      roadmap = expandedRoadmap;
      
      print('\n📊 FINAL ROADMAP SUMMARY:');
      print('   Total daily items: ${roadmap.length}');
      print('   Expected: $totalDays days');
      print('   Coverage: ${(roadmap.length / totalDays * 100).toStringAsFixed(1)}%');
      
      // Store teacher note and tips in user profile for display
      if (teacherNote.isNotEmpty || studyTips.isNotEmpty) {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'teacherNote': teacherNote,
              'studyTips': studyTips,
            });
            print('💾 Saved teacher notes and tips to Firebase');
          } catch (e) {
            print('⚠️ Failed to save teacher notes: $e');
          }
        }
      }
      
      return roadmap;
      
    } catch (e) {
      print('❌ Error in personalized generation: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Clear old roadmap and force regeneration (migration helper)
  static Future<bool> clearRoadmap() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      print('🗑️ Clearing old roadmap data...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'roadmap': [],
        'roadmapGeneratedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Old roadmap cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing roadmap: $e');
      return false;
    }
  }

  /// Generate content for a specific topic (videos only)
  static Future<Map<String, dynamic>> generateTopicContent({
    required String topicName,
    required String courseName,
    required String subjectName,
    required String difficulty,
    required Map<String, String> mindsetProfile,
  }) async {
    print('📝 Generating video content for: $topicName');
    
    try {
      // Determine video style based on mindset
      final videoStyle = _determineVideoStyle(mindsetProfile);
      
      // Get user's preferred language
      final User? user = FirebaseAuth.instance.currentUser;
      String preferredLanguage = 'English';
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        preferredLanguage = userDoc.data()?['preferredLanguage'] as String? ?? 'English';
      }
      
      // Fetch YouTube videos
      print('🎥 Fetching videos for: $topicName in $preferredLanguage');
      final videos = await _searchYouTubeVideos(
        topicName,
        courseName,
        videoStyle,
        difficulty,
        preferredLanguage,
      );
      
      return {
        'success': true,
        'data': {
          'topic': topicName,
          'subject': subjectName,
          'difficulty': difficulty,
          'videos': videos,
          'completed': false,
        },
      };
    } catch (e) {
      print('❌ Error generating topic content: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  static List<Map<String, dynamic>> _getCourseTopics(String courseName) {
    // Define topics for each course with learning rationale
    final courseTopicsMap = {
      'JEE (Joint Entrance Examination)': [
        {'name': 'Physics - Mechanics', 'difficulty': 'medium', 'whyNow': 'Foundation for all physics topics'},
        {'name': 'Physics - Electromagnetism', 'difficulty': 'hard', 'whyNow': 'Builds on mechanics concepts'},
        {'name': 'Chemistry - Organic Chemistry', 'difficulty': 'medium', 'whyNow': 'Pattern-based, easier to start'},
        {'name': 'Chemistry - Physical Chemistry', 'difficulty': 'hard', 'whyNow': 'Requires math foundation'},
        {'name': 'Mathematics - Calculus', 'difficulty': 'hard', 'whyNow': 'Core to problem solving'},
        {'name': 'Mathematics - Algebra', 'difficulty': 'medium', 'whyNow': 'Used across all subjects'},
        {'name': 'Problem Solving Techniques', 'difficulty': 'medium', 'whyNow': 'Apply what you learned'},
        {'name': 'Time Management for JEE', 'difficulty': 'easy', 'whyNow': 'Crucial for exam success'},
      ],
      'NEET (National Eligibility cum Entrance Test)': [
        {'name': 'Physics - Mechanics & Properties', 'difficulty': 'medium'},
        {'name': 'Physics - Optics and Modern Physics', 'difficulty': 'medium'},
        {'name': 'Chemistry - Organic Chemistry', 'difficulty': 'hard'},
        {'name': 'Chemistry - Inorganic Chemistry', 'difficulty': 'medium'},
        {'name': 'Biology - Cell Biology & Genetics', 'difficulty': 'hard'},
        {'name': 'Biology - Human Physiology', 'difficulty': 'medium'},
        {'name': 'Biology - Plant Biology', 'difficulty': 'medium'},
        {'name': 'NEET Exam Strategy', 'difficulty': 'easy'},
      ],
      'GATE (Graduate Aptitude Test in Engineering)': [
        {
          'name': 'Engineering Mathematics',
          'difficulty': 'hard',
          'isSubject': true,
          'topics': [
            {'name': 'Linear Algebra - Matrices & Determinants', 'difficulty': 'medium'},
            {'name': 'Calculus - Differentiation & Integration', 'difficulty': 'hard'},
            {'name': 'Differential Equations', 'difficulty': 'hard'},
            {'name': 'Probability & Statistics', 'difficulty': 'medium'},
            {'name': 'Complex Variables', 'difficulty': 'hard'},
          ]
        },
        {
          'name': 'Core Concepts of CSE',
          'difficulty': 'hard',
          'isSubject': true,
          'topics': [
            {'name': 'Data Structures - Arrays & Linked Lists', 'difficulty': 'medium'},
            {'name': 'Data Structures - Trees & Graphs', 'difficulty': 'hard'},
            {'name': 'Algorithms - Sorting & Searching', 'difficulty': 'medium'},
            {'name': 'Algorithms - Dynamic Programming', 'difficulty': 'hard'},
            {'name': 'Operating Systems - Process Management', 'difficulty': 'medium'},
            {'name': 'Operating Systems - Memory Management', 'difficulty': 'hard'},
            {'name': 'Database Management Systems', 'difficulty': 'medium'},
            {'name': 'Computer Networks - OSI Model', 'difficulty': 'medium'},
            {'name': 'Computer Organization & Architecture', 'difficulty': 'hard'},
          ]
        },
        {
          'name': 'General Aptitude',
          'difficulty': 'easy',
          'isSubject': true,
          'topics': [
            {'name': 'Numerical Ability - Percentages & Ratios', 'difficulty': 'easy'},
            {'name': 'Verbal Ability - Grammar & Comprehension', 'difficulty': 'easy'},
            {'name': 'Logical Reasoning', 'difficulty': 'medium'},
            {'name': 'Data Interpretation', 'difficulty': 'medium'},
          ]
        },
      ],
      'CAT (Common Admission Test)': [
        {'name': 'Quantitative Aptitude', 'difficulty': 'hard'},
        {'name': 'Verbal Ability and Reading Comprehension', 'difficulty': 'medium'},
        {'name': 'Data Interpretation', 'difficulty': 'hard'},
        {'name': 'Logical Reasoning', 'difficulty': 'medium'},
        {'name': 'Time Management Skills', 'difficulty': 'easy'},
        {'name': 'Mock Test Strategies', 'difficulty': 'medium'},
      ],
      'UPSC (Union Public Service Commission)': [
        {'name': 'Indian Polity and Governance', 'difficulty': 'medium'},
        {'name': 'Indian Economy', 'difficulty': 'hard'},
        {'name': 'History and Culture', 'difficulty': 'medium'},
        {'name': 'Geography and Environment', 'difficulty': 'medium'},
        {'name': 'Current Affairs Analysis', 'difficulty': 'easy'},
        {'name': 'Essay Writing Skills', 'difficulty': 'medium'},
        {'name': 'Answer Writing Techniques', 'difficulty': 'hard'},
      ],
      'SSC (Staff Selection Commission)': [
        {'name': 'General Intelligence', 'difficulty': 'medium'},
        {'name': 'Quantitative Aptitude', 'difficulty': 'medium'},
        {'name': 'English Language', 'difficulty': 'easy'},
        {'name': 'General Awareness', 'difficulty': 'easy'},
        {'name': 'Speed and Accuracy', 'difficulty': 'medium'},
      ],
      'Banking (IBPS/SBI)': [
        {'name': 'Quantitative Aptitude', 'difficulty': 'medium'},
        {'name': 'Reasoning Ability', 'difficulty': 'medium'},
        {'name': 'English Language', 'difficulty': 'medium'},
        {'name': 'Banking Awareness', 'difficulty': 'easy'},
        {'name': 'Computer Knowledge', 'difficulty': 'easy'},
        {'name': 'Interview Preparation', 'difficulty': 'medium'},
      ],
      'CLAT (Common Law Admission Test)': [
        {'name': 'Legal Reasoning', 'difficulty': 'hard'},
        {'name': 'Logical Reasoning', 'difficulty': 'medium'},
        {'name': 'English Language', 'difficulty': 'medium'},
        {'name': 'Current Affairs and GK', 'difficulty': 'easy'},
        {'name': 'Quantitative Techniques', 'difficulty': 'medium'},
      ],
    };

    return courseTopicsMap[courseName] ?? [
      {'name': 'Getting Started', 'difficulty': 'easy'},
      {'name': 'Core Concepts', 'difficulty': 'medium'},
      {'name': 'Advanced Topics', 'difficulty': 'hard'},
      {'name': 'Practice and Revision', 'difficulty': 'medium'},
    ];
  }

  static String _determineVideoStyle(Map<String, String> mindsetProfile) {
    // Analyze mindset to determine best video style based on user's learning preferences
    
    final confusion = mindsetProfile['confusionFactors'] ?? '';
    final forgetting = mindsetProfile['forgettingFrequency'] ?? '';
    final emotional = mindsetProfile['examEmotionalState'] ?? '';
    
    // High confusion or fear? Need clear, step-by-step explanations
    if (confusion.contains('Often') || confusion.contains('Completely') || 
        emotional.contains('Fear') || emotional.contains('anxiety')) {
      return 'beginner friendly step by step';
    }
    
    // Frequent forgetting? Need revision-focused, memorable content
    if (forgetting.contains('Often') || forgetting.contains('frequently')) {
      return 'easy to remember concept explanation';
    }
    
    // Check learning style preferences
    if (mindsetProfile.containsValue('Visual diagrams') ||
        mindsetProfile.containsValue('Video tutorials')) {
      return 'animated visual tutorial';
    }
    
    if (mindsetProfile.containsValue('Quick summaries') ||
        mindsetProfile.containsValue('Short videos')) {
      return 'quick concept overview';
    }
    
    // Default: comprehensive but accessible
    return 'clear tutorial explained simply';
  }

  /// Build comprehensive mindset description from user profile for video recommendations
  static Future<String> _buildMindsetDescription(String userLevel, Map<String, dynamic> courseAnswers) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 'A learner seeking clear explanations and structured content.';
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final learningProfile = userDoc.data()?['learningProfile'] as Map<String, dynamic>? ?? {};
      final mindsetAnswers = userDoc.data()?['mindsetAnswers'] as Map<String, dynamic>? ?? {};
      
      List<String> preferences = [];
      List<String> avoids = [];

      // Determine learner level from courseAnswers
      final currentKnowledge = courseAnswers['q2']?.toString().toLowerCase() ?? '';
      if (currentKnowledge.contains('basic') || currentKnowledge.contains('beginner') || userLevel.toLowerCase() == 'beginner') {
        preferences.addAll([
          'foundational knowledge',
          'slow explanations',
          'visual demonstrations',
          'simple examples',
          'step-by-step tutorials',
          'basic terminology',
          'gentle introduction',
          'animated explanations',
          'whiteboard teaching',
          'complete beginner friendly',
          'from scratch tutorials',
          'zero to hero approach'
        ]);
        avoids.addAll([
          'complex optimization',
          'advanced algorithms',
          'time complexity analysis',
          'competitive programming',
          'leetcode hard problems'
        ]);
      } else if (currentKnowledge.contains('intermediate') || userLevel.toLowerCase() == 'intermediate') {
        preferences.addAll([
          'practical examples',
          'clear explanations',
          'real-world applications',
          'problem-solving approach',
          'conceptual understanding',
          'best practices'
        ]);
        avoids.addAll([
          'overly basic content',
          'too much theory without practice'
        ]);
      } else {
        preferences.addAll([
          'advanced concepts',
          'optimization techniques',
          'deep dives',
          'complex problem solving',
          'theoretical foundations',
          'cutting-edge approaches'
        ]);
        avoids.add('overly simplified content');
      }

      // Add learning style preferences from mindset analysis
      final confusion = learningProfile['confusionFactors']?.toString() ?? '';
      final frustration = learningProfile['frustrationSource']?.toString() ?? '';
      final forgetting = learningProfile['forgettingFrequency']?.toString() ?? '';
      final emotional = learningProfile['examEmotionalState']?.toString() ?? '';

      if (confusion.contains('Often') || confusion.contains('time management')) {
        preferences.addAll(['structured content', 'time-boxed lessons', 'organized approach']);
      }

      if (frustration.contains('apply') || frustration.contains('application')) {
        preferences.addAll(['practical examples', 'hands-on tutorials', 'application-focused']);
        avoids.add('pure theory without examples');
      }

      if (forgetting.contains('Sometimes') || forgetting.contains('Often')) {
        preferences.addAll(['memorable explanations', 'mnemonics', 'revision techniques', 'spaced repetition']);
      }

      if (emotional.contains('Self-doubt') || emotional.contains('anxiety')) {
        preferences.addAll(['encouraging tone', 'supportive teaching', 'confidence building']);
        avoids.add('intimidating presentations');
      }

      // Build the mindset description
      String level = currentKnowledge.contains('basic') || userLevel.toLowerCase() == 'beginner' 
          ? 'beginner' 
          : currentKnowledge.contains('advanced') || userLevel.toLowerCase() == 'advanced'
          ? 'advanced'
          : 'intermediate';

      String mindsetDescription = 'A $level learner who needs ';
      if (preferences.isNotEmpty) {
        mindsetDescription += preferences.take(12).join(', ');
      }
      if (avoids.isNotEmpty) {
        mindsetDescription += '. Avoids ' + avoids.join(', ');
      }
      mindsetDescription += '.';

      return mindsetDescription;
    } catch (e) {
      print('❌ Error building mindset description: $e');
      return 'A learner seeking clear explanations and structured content.';
    }
  }

  static Future<List<Map<String, dynamic>>> _searchYouTubeVideos(
    String topic,
    String courseName,
    String videoStyle,
    String difficulty,
    String language, {
    List<String> channelHints = const [],
  }) async {
    try {
      // Validate API key
      final apiKey = dotenv.env['VIDEO_RECOMMENDATION_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        print('❌ ERROR: Video Recommendation API key is not configured!');
        print('💡 Please add VIDEO_RECOMMENDATION_API_KEY in config/.env');
        return [];
      }
      
      // Extract the core topic name
      String cleanTopic = topic
          .replaceAll(RegExp(r'^(Week|Day|Month)\s*\d+:\s*', caseSensitive: false), '')
          .trim();
      
      print('🔍 Searching videos for: $cleanTopic');
      print('🧠 Video style (based on mindset): $videoStyle');
      
      // Get user data to build comprehensive mindset
      final User? user = FirebaseAuth.instance.currentUser;
      String mindsetDescription = 'A learner seeking clear explanations and structured content.';
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final courseAnswers = userDoc.data()?['courseAnswers'] as Map<String, dynamic>? ?? {};
        final userLevel = userDoc.data()?['userLevel'] as String? ?? 'Intermediate';
        
        mindsetDescription = await _buildMindsetDescription(userLevel, courseAnswers);
      }
      
      print('📋 Mindset profile: ${mindsetDescription.substring(0, mindsetDescription.length > 100 ? 100 : mindsetDescription.length)}...');
      
      // Build request body
      final requestBody = jsonEncode({
        'api_key': apiKey,
        'topic': '$cleanTopic tutorial',
        'mindset': mindsetDescription,
        'max_results': 20,
      });
      
      // Call HuggingFace recommendation API
      final apiUrl = Uri.parse('https://hemanth0112-smilarity-check.hf.space/recommend');
      
      print('📡 Calling video recommendation API...');
      
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ API timeout for: $topic');
          throw Exception('Video recommendation API timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final recommendations = responseData['recommendations'] as List? ?? [];
        
        if (recommendations.isEmpty) {
          print('⚠️ No video recommendations found for: $topic');
          return [];
        }
        
        print('📦 Received ${recommendations.length} video recommendations');
        
        // Convert recommendations to our video format
        List<Map<String, dynamic>> videos = [];
        
        for (var rec in recommendations) {
          try {
            final url = rec['url'] as String? ?? '';
            final videoId = _extractVideoId(url);
            
            if (videoId == null || videoId.isEmpty) {
              print('⚠️ Could not extract video ID from: $url');
              continue;
            }
            
            final title = rec['title'] as String? ?? '';
            final views = rec['views'] as int? ?? 0;
            final score = (rec['score'] as num?)?.toDouble() ?? 0.0;
            final engagement = (rec['engagement'] as num?)?.toDouble() ?? 0.0;
            final detectedLevel = rec['detected_level'] as String? ?? '';
            final duration = rec['duration'] as int? ?? 0;
            final verdict = rec['verdict'] as String? ?? '';
            
            // Calculate relevance score (convert 0-1 score to 0-100)
            final relevanceScore = score * 100;
            
            // Skip videos that are not suitable
            if (verdict.toLowerCase().contains('not suitable')) {
              print('⏭️ Skipping unsuitable video: $title');
              continue;
            }
            
            videos.add({
              'videoId': videoId,
              'title': title,
              'thumbnail': 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
              'channelName': '', // Not provided by API, will be empty
              'description': 'Duration: ${duration}min | Level: $detectedLevel | Verdict: $verdict',
              'viewCount': views,
              'likeCount': 0, // Not provided by API
              'engagementScore': engagement,
              'relevanceScore': relevanceScore,
              'detectedLevel': detectedLevel,
              'verdict': verdict,
            });
          } catch (e) {
            print('❌ Error processing video recommendation: $e');
            continue;
          }
        }
        
        if (videos.isEmpty) {
          print('⚠️ No valid videos after processing recommendations');
          return [];
        }
        
        // Sort by relevance score (already provided by API)
        videos.sort((a, b) {
          final scoreA = (a['relevanceScore'] as num).toDouble();
          final scoreB = (b['relevanceScore'] as num).toDouble();
          return scoreB.compareTo(scoreA);
        });
        
        // Take top 3 videos
        final topVideos = videos.take(3).toList();
        print('✅ Selected ${topVideos.length} personalized video recommendations for: $topic');
        if (topVideos.isNotEmpty) {
          print('   Top video: "${topVideos[0]['title']}" (Score: ${topVideos[0]['relevanceScore'].toStringAsFixed(1)}%)');
          print('   Verdict: ${topVideos[0]['verdict']}');
        }
        
        return topVideos;
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        print('❌ API Error ${response.statusCode}: Rate limit or permission issue');
        print('💡 The video recommendation API may be rate limited');
        print('🔧 Solution: Wait a few moments and try again');
        return [];
      } else {
        print('⚠️ Video recommendation API error: ${response.statusCode}');
        print('   Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching videos: $e');
      return [];
    }
  }

  /// Extract YouTube video ID from various URL formats
  static String? _extractVideoId(String url) {
    try {
      // Handle youtube.com/watch?v=VIDEO_ID
      if (url.contains('youtube.com/watch?v=')) {
        final uri = Uri.parse(url);
        return uri.queryParameters['v'];
      }
      
      // Handle youtu.be/VIDEO_ID
      if (url.contains('youtu.be/')) {
        return url.split('youtu.be/').last.split('?').first.split('&').first;
      }
      
      // Handle youtube.com/embed/VIDEO_ID
      if (url.contains('youtube.com/embed/')) {
        return url.split('youtube.com/embed/').last.split('?').first.split('&').first;
      }
      
      // If already a video ID (11 characters, alphanumeric)
      if (url.length == 11 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(url)) {
        return url;
      }
      
      return null;
    } catch (e) {
      print('❌ Error extracting video ID from: $url');
      return null;
    }
  }

  /// Calculate video relevance score based on topic keywords in title and description
  /// Returns a score from 0-100 indicating how well the video matches the topic
  static double _calculateVideoRelevance(
    String topic,
    String videoTitle,
    String videoDescription,
    String videoStyle,
  ) {
    double score = 0.0;
    
    // Normalize text for comparison
    final topicLower = topic.toLowerCase();
    final titleLower = videoTitle.toLowerCase();
    final descLower = videoDescription.toLowerCase();
    
    // Extract key terms from topic (remove common words)
    final stopWords = ['study', 'learn', 'understand', 'practice', 'revision', 'tutorial', 'the', 'and', 'or', 'in', 'of', 'to', 'for', 'a', 'an'];
    final topicWords = topicLower
        .split(RegExp(r'[\s\-,•]+'))
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toSet();
    
    if (topicWords.isEmpty) {
      return 50.0; // Default score if no keywords
    }
    
    // Score components:
    int titleMatches = 0;
    int descMatches = 0;
    
    // 1. Check for exact phrase match (highest weight)
    if (titleLower.contains(topicLower)) {
      score += 50.0;
    } else if (descLower.contains(topicLower)) {
      score += 30.0;
    }
    
    // 2. Check individual keyword matches (more generous scoring)
    for (final word in topicWords) {
      if (titleLower.contains(word)) {
        titleMatches++;
        score += 8.0; // Increased from 5.0 - title matches are important
      }
      if (descLower.contains(word)) {
        descMatches++;
        score += 3.0; // Increased from 2.0 - description matches are supportive
      }
    }
    
    // 3. Bonus for matching video style keywords
    final styleKeywords = videoStyle.toLowerCase().split(' ');
    for (final styleWord in styleKeywords) {
      if (styleWord.length > 3) {
        if (titleLower.contains(styleWord)) score += 4.0; // Increased from 3.0
        if (descLower.contains(styleWord)) score += 2.0; // Increased from 1.0
      }
    }
    
    // 4. Educational content indicators (bonus points)
    final eduIndicators = ['tutorial', 'explained', 'learn', 'guide', 'lesson', 'course', 'lecture', 'introduction', 'complete', 'basics', 'fundamentals'];
    for (final indicator in eduIndicators) {
      if (titleLower.contains(indicator)) {
        score += 5.0; // Increased from 2.0
        break;
      }
    }
    
    // Calculate match percentage
    final titleMatchPercent = topicWords.isEmpty ? 0 : (titleMatches / topicWords.length * 100);
    final descMatchPercent = topicWords.isEmpty ? 0 : (descMatches / topicWords.length * 100);
    
    // 5. Bonus for high keyword coverage
    if (titleMatchPercent > 50) score += 15.0; // Increased from 10.0
    else if (titleMatchPercent > 25) score += 8.0; // New: bonus for partial coverage
    
    if (descMatchPercent > 30) score += 8.0; // Increased from 5.0
    else if (descMatchPercent > 15) score += 4.0; // New: bonus for partial coverage
    
    // Cap at 100
    return score.clamp(0, 100);
  }

  /// Get ISO 639-1 language code for YouTube API
  static String _getLanguageCode(String language) {
    final languageCodes = {
      'English': 'en',
      'Hindi': 'hi',
      'Tamil': 'ta',
      'Telugu': 'te',
      'Kannada': 'kn',
      'Malayalam': 'ml',
      'Bengali': 'bn',
      'Marathi': 'mr',
      'Gujarati': 'gu',
      'Punjabi': 'pa',
      'Spanish': 'es',
      'French': 'fr',
      'German': 'de',
      'Chinese': 'zh',
      'Japanese': 'ja',
      'Korean': 'ko',
    };
    return languageCodes[language] ?? 'en';
  }

  /// Generate meaningful fallback topic when AI doesn't provide proper daily breakdown
  static String _generateFallbackTopic(String weekTheme, String weekTopic, int dayInWeek, String courseName) {
    // Common topic patterns for different course types
    final dayLabels = ['Fundamentals', 'Core Concepts', 'Advanced Topics', 'Applications', 'Practice', 'Problem Solving', 'Revision'];
    
    // For programming courses
    if (courseName.toLowerCase().contains('python') || 
        courseName.toLowerCase().contains('javascript') ||
        courseName.toLowerCase().contains('java') ||
        courseName.toLowerCase().contains('programming')) {
      final programmingTopics = [
        'Variables and Data Types',
        'Conditional Statements',
        'Loops and Iteration',
        'Functions and Methods',
        'Data Structures',
        'Practice Problems',
        'Project Work'
      ];
      return '${weekTheme} - ${programmingTopics[dayInWeek - 1]}';
    }
    
    // For web development
    if (courseName.toLowerCase().contains('web') || 
        courseName.toLowerCase().contains('html') ||
        courseName.toLowerCase().contains('css')) {
      final webTopics = [
        'HTML Basics',
        'CSS Styling',
        'Layout Design',
        'JavaScript Fundamentals',
        'DOM Manipulation',
        'Responsive Design',
        'Project Practice'
      ];
      return '${weekTheme} - ${webTopics[dayInWeek - 1]}';
    }
    
    // For data science/ML
    if (courseName.toLowerCase().contains('data') || 
        courseName.toLowerCase().contains('machine learning') ||
        courseName.toLowerCase().contains('ai')) {
      final dataTopics = [
        'Data Analysis Basics',
        'Statistics Fundamentals',
        'Data Visualization',
        'Machine Learning Intro',
        'Model Training',
        'Practice Projects',
        'Case Studies'
      ];
      return '${weekTheme} - ${dataTopics[dayInWeek - 1]}';
    }
    
    // For competitive exams (GATE, JEE, NEET, etc.)
    if (courseName.toLowerCase().contains('gate') || 
        courseName.toLowerCase().contains('jee') ||
        courseName.toLowerCase().contains('neet') ||
        courseName.toLowerCase().contains('exam')) {
      // Try to extract subject from week theme
      if (weekTheme.toLowerCase().contains('math')) {
        final mathTopics = [
          'Algebra - Linear Equations',
          'Calculus - Differentiation',
          'Calculus - Integration',
          'Probability Theory',
          'Statistics Basics',
          'Practice Problems',
          'Mock Test Review'
        ];
        return mathTopics[dayInWeek - 1];
      } else if (weekTheme.toLowerCase().contains('physics')) {
        final physicsTopics = [
          'Mechanics - Kinematics',
          'Mechanics - Dynamics',
          'Thermodynamics',
          'Electromagnetism',
          'Optics',
          'Practice Problems',
          'Previous Year Questions'
        ];
        return physicsTopics[dayInWeek - 1];
      } else if (weekTheme.toLowerCase().contains('chemistry')) {
        final chemTopics = [
          'Atomic Structure',
          'Chemical Bonding',
          'Organic Chemistry',
          'Inorganic Chemistry',
          'Physical Chemistry',
          'Practice Problems',
          'Revision'
        ];
        return chemTopics[dayInWeek - 1];
      } else if (weekTheme.toLowerCase().contains('data structure')) {
        final dsTopics = [
          'Arrays and Strings',
          'Linked Lists',
          'Stacks and Queues',
          'Trees',
          'Graphs',
          'Practice Problems',
          'Coding Practice'
        ];
        return dsTopics[dayInWeek - 1];
      } else if (weekTheme.toLowerCase().contains('algorithm')) {
        final algoTopics = [
          'Sorting Algorithms',
          'Searching Algorithms',
          'Dynamic Programming',
          'Greedy Algorithms',
          'Graph Algorithms',
          'Practice Problems',
          'Competitive Programming'
        ];
        return algoTopics[dayInWeek - 1];
      }
    }
    
    // Generic fallback - use day labels with week theme
    if (dayInWeek <= dayLabels.length) {
      return '${weekTheme} - ${dayLabels[dayInWeek - 1]}';
    }
    
    // Last resort: combine week theme with day-specific descriptor
    return '$weekTheme - Day $dayInWeek Session';
  }

  /// Calculate number of days based on target date answer
  static int _calculateDaysFromTarget(String targetDate, String studyTime) {
    // Map target date to approximate days
    int baseDays;
    switch (targetDate) {
      case 'Within 6 months':
        baseDays = 90; // 3 months intensive
        break;
      case '6 months to 1 year':
        baseDays = 120; // 4 months
        break;
      case '1-2 years':
        baseDays = 180; // 6 months
        break;
      case 'More than 2 years':
        baseDays = 240; // 8 months
        break;
      case 'Not sure yet':
        baseDays = 90; // Default 3 months
        break;
      default:
        baseDays = 90;
    }

    // Adjust based on daily study time
    // Less time per day = spread over more days
    switch (studyTime) {
      case 'Less than 1 hour':
        baseDays = (baseDays * 1.5).round(); // 50% more days
        break;
      case '1-2 hours':
        baseDays = (baseDays * 1.2).round(); // 20% more days
        break;
      case '3-4 hours':
        // Keep as is
        break;
      case '5-6 hours':
        baseDays = (baseDays * 0.8).round(); // 20% fewer days
        break;
      case 'More than 6 hours':
        baseDays = (baseDays * 0.7).round(); // 30% fewer days
        break;
    }

    // Ensure reasonable range (30-180 days)
    if (baseDays < 30) baseDays = 30;
    if (baseDays > 180) baseDays = 180;

    return baseDays;
  }

  /// Fetch videos for all topics in roadmap
  static Future<List<Map<String, dynamic>>> _fetchVideosForRoadmap(
    List<Map<String, dynamic>> roadmap,
    String courseName,
    Map<String, String> mindsetProfile,
    String preferredLanguage,
  ) async {
    print('🎥 Fetching videos for ALL topics in roadmap...');
    print('📊 Total roadmap items: ${roadmap.length}');
    final youtubeApiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';
    print('🔑 YouTube API Key present: ${youtubeApiKey.isNotEmpty}');
    print('🔑 YouTube API Key length: ${youtubeApiKey.length} chars');
    
    if (youtubeApiKey.isEmpty) {
      print('❌ ERROR: YouTube API Key is empty! Cannot fetch videos.');
      return roadmap;
    }
    
    final videoStyle = _determineVideoStyle(mindsetProfile);
    print('🎨 Video style based on mindset: $videoStyle');
    final updatedRoadmap = <Map<String, dynamic>>[];
    
    int successCount = 0;
    int failCount = 0;
    
    for (int i = 0; i < roadmap.length; i++) {
      final item = Map<String, dynamic>.from(roadmap[i]);
      final topic = item['topic'] as String? ?? '';
      final difficulty = item['difficulty'] as String? ?? 'medium';
      final dayNumber = item['day'] as int? ?? (i + 1);
      final recommendedChannels = item['recommendedChannels'] as List? ?? [];
      
      if (topic.isEmpty) {
        print('⚠️ Skipping empty topic at index $i');
        item['videos'] = [];
        updatedRoadmap.add(item);
        continue;
      }
      
      // Fetch videos for ALL topics (no limit)
      print('\n═══ VIDEO FETCH DEBUG ═══');
      print('📹 Day $dayNumber: $topic');
      print('📊 Difficulty: $difficulty');
      print('🌍 Language: $preferredLanguage');
      print('🎨 Video Style: $videoStyle');
      if (recommendedChannels.isNotEmpty) {
        print('📺 Recommended channels: ${recommendedChannels.join(", ")}');
      }
      
      try {
        print('🔍 Calling _searchYouTubeVideos...');
        final videos = await _searchYouTubeVideos(
          topic,
          courseName,
          videoStyle,
          difficulty,
          preferredLanguage,
          channelHints: recommendedChannels.map((e) => e.toString()).toList(),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ Timeout fetching videos for: $topic');
            return [];
          },
        );
        
        print('📦 Received ${videos.length} videos');
        if (videos.isNotEmpty) {
          item['videos'] = videos;
          successCount++;
          print('✅ SUCCESS: Saved ${videos.length} videos for: $topic');
          // Print first video title for verification
          print('   First video: ${videos[0]['title']}');
        } else {
          item['videos'] = [];
          failCount++;
          print('⚠️ NO VIDEOS FOUND for: $topic');
          if (failCount == 1) {
            print('💡 Tip: Check YouTube API quota if many videos are missing');
          }
        }
      } catch (e) {
        print('❌ ERROR fetching videos for $topic: $e');
        print('   Error type: ${e.runtimeType}');
        item['videos'] = [];
        failCount++;
      }
      print('═══ END DEBUG ═══\n');
      
      // Delay between requests to avoid rate limiting
      if (i < roadmap.length - 1) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      
      updatedRoadmap.add(item);
    }
    
    print('\n📊 Video fetch summary (ALL topics):');
    print('✅ Success: $successCount topics');
    print('⚠️ Failed: $failCount topics');
    print('📅 Total topics processed: ${roadmap.length}\n');
    
    if (failCount > 10) {
      print('⚠️ WARNING: Many video fetch failures detected!');
      print('💡 This usually means YouTube API quota is exceeded.');
      print('📌 Action needed:');
      print('   1. Check YouTube API quota in Google Cloud Console');
      print('   2. Wait 24 hours for quota reset (resets at midnight Pacific Time)');
      print('   3. Videos will auto-load when you open each topic later');
      print('   4. Consider getting additional API quota if needed\n');
    }
    
    return updatedRoadmap;
  }
}
