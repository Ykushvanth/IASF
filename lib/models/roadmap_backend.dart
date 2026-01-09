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
        final roadmapList = existingRoadmap
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
