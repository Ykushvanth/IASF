import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// CheatSheetBackend - Generates personalized cheat sheets for topics
/// 
/// Features:
/// - AI-generated cheat sheets with proper formatting
/// - Subject-specific templates (Math, Coding, Theory, Languages)
/// - Level-based complexity (beginner/intermediate/advanced)
/// - Color-coded sections for visual scanning
/// - Real-world applications and examples
class CheatSheetBackend {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a cheat sheet for a topic
  static Future<Map<String, dynamic>> generateCheatSheet({
    required String topicName,
    required String courseName,
    required String difficulty,
    String? examType,
    List<String>? subtopics,
    String userLevel = 'intermediate',
  }) async {
    print('📝 Generating cheat sheet for: $topicName');
    
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User not logged in',
        };
      }

      // Check if cheat sheet already exists in Firebase
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cheatSheets')
          .doc('${courseName}_$topicName');

      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data() != null) {
        final existingData = docSnap.data()!;
        print('✅ Found existing cheat sheet in Firebase');
        return {
          'success': true,
          'cheatSheet': existingData['markdown'] ?? '',
          'generatedAt': existingData['generatedAt'],
        };
      }

      // Get user's mindset profile for personalization
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final mindsetAnswers = <String, String>{};
      final rawAnswers = userDoc.data()?['mindsetAnswers'] ?? {};
      
      if (rawAnswers is Map) {
        rawAnswers.forEach((key, value) {
          if (value is String) {
            mindsetAnswers[key.toString()] = value;
          } else if (value is List) {
            mindsetAnswers[key.toString()] = value.join(', ');
          } else {
            mindsetAnswers[key.toString()] = value.toString();
          }
        });
      }

      // Determine subject type from topic/course name
      final subjectType = _determineSubjectType(topicName, courseName);
      
      // Generate cheat sheet using AI
      final result = await _generateWithAI(
        topicName: topicName,
        courseName: courseName,
        difficulty: difficulty,
        examType: examType,
        subtopics: subtopics,
        userLevel: userLevel,
        subjectType: subjectType,
        mindsetProfile: mindsetAnswers,
      );

      if (result['success'] == true) {
        final markdown = result['markdown'] as String;
        
        // Save to Firebase
        await docRef.set({
          'topicName': topicName,
          'courseName': courseName,
          'markdown': markdown,
          'subjectType': subjectType,
          'userLevel': userLevel,
          'generatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Cheat sheet generated and saved');
        return {
          'success': true,
          'cheatSheet': markdown,
          'generatedAt': DateTime.now().toIso8601String(),
        };
      } else {
        return result;
      }
    } catch (e, stackTrace) {
      print('❌ Error generating cheat sheet: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error generating cheat sheet: ${e.toString()}',
      };
    }
  }

  /// Determine subject type for appropriate template
  static String _determineSubjectType(String topicName, String courseName) {
    final topicLower = topicName.toLowerCase();
    final courseLower = courseName.toLowerCase();

    // Math/Physics/Chemistry
    if (topicLower.contains('math') || 
        topicLower.contains('calculus') ||
        topicLower.contains('algebra') ||
        topicLower.contains('physics') ||
        topicLower.contains('chemistry') ||
        topicLower.contains('formula') ||
        topicLower.contains('equation')) {
      return 'math';
    }

    // Coding/Programming
    if (topicLower.contains('programming') ||
        topicLower.contains('code') ||
        topicLower.contains('algorithm') ||
        topicLower.contains('data structure') ||
        topicLower.contains('software') ||
        topicLower.contains('computer science') ||
        courseLower.contains('gate') && topicLower.contains('cse')) {
      return 'coding';
    }

    // Languages
    if (topicLower.contains('english') ||
        topicLower.contains('grammar') ||
        topicLower.contains('language') ||
        topicLower.contains('vocabulary') ||
        topicLower.contains('comprehension')) {
      return 'language';
    }

    // Default: Theory/Concepts
    return 'theory';
  }

  /// Generate cheat sheet using Groq API
  static Future<Map<String, dynamic>> _generateWithAI({
    required String topicName,
    required String courseName,
    required String difficulty,
    String? examType,
    List<String>? subtopics,
    required String userLevel,
    required String subjectType,
    required Map<String, String> mindsetProfile,
  }) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      
      if (apiKey.isEmpty) {
        return {
          'success': false,
          'message': 'API key not configured',
        };
      }

      // Build the prompt based on subject type
      final prompt = _buildPrompt(
        topicName: topicName,
        courseName: courseName,
        difficulty: difficulty,
        examType: examType,
        subtopics: subtopics,
        userLevel: userLevel,
        subjectType: subjectType,
        mindsetProfile: mindsetProfile,
      );

      print('🤖 Calling Groq API for cheat sheet generation...');
      
      final requestBody = jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'system',
            'content': 'You are an expert educational content creator specializing in creating concise, visually appealing cheat sheets for students. Your cheat sheets are scannable, well-organized, and genuinely useful for exam revision.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 4000,
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
        var markdown = jsonResponse['choices'][0]['message']['content'];
        
        // Clean HTML tags from the generated content
        markdown = _cleanHtmlTags(markdown);
        
        print('✅ Cheat sheet generated successfully');
        return {
          'success': true,
          'markdown': markdown,
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

  /// Build the prompt for AI generation
  static String _buildPrompt({
    required String topicName,
    required String courseName,
    required String difficulty,
    String? examType,
    List<String>? subtopics,
    required String userLevel,
    required String subjectType,
    required Map<String, String> mindsetProfile,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('Create a professional, minimalist cheat sheet for the topic: **$topicName**');
    buffer.writeln('');
    buffer.writeln('**Context:**');
    buffer.writeln('- Course: $courseName');
    if (examType != null) buffer.writeln('- Exam: $examType');
    buffer.writeln('- Difficulty: $difficulty');
    buffer.writeln('- Student Level: $userLevel');
    buffer.writeln('- Subject Type: $subjectType');
    if (subtopics != null && subtopics.isNotEmpty) {
      buffer.writeln('- Subtopics to cover: ${subtopics.join(", ")}');
    }
    buffer.writeln('');
    buffer.writeln('**DESIGN PHILOSOPHY:**');
    buffer.writeln('Create a clean, minimalist cheat sheet matching professional educational content style.');
    buffer.writeln('Focus on clarity, simplicity, and immediate understanding.');
    buffer.writeln('');

    // Add subject-specific instructions with NxtWave style
    if (subjectType == 'math') {
      buffer.writeln('**FORMATTING REQUIREMENTS FOR MATH/PHYSICS/CHEMISTRY:**');
      buffer.writeln('1. Start with clear definition (1-2 sentences) before showing formulas');
      buffer.writeln('2. Use markdown code blocks (```) for formulas');
      buffer.writeln('3. Structure: Definition → Explanation → Formula → Examples → Note box if needed');
      buffer.writeln('4. Include: Clear definitions, formulas with variable explanations, step-by-step examples');
      buffer.writeln('5. Separate major sections with --- horizontal rules');
      buffer.writeln('6. Use note boxes (> **📝 Note**) for important clarifications');
      buffer.writeln('');
    } else if (subjectType == 'coding') {
      buffer.writeln('**FORMATTING REQUIREMENTS FOR CODING/PROGRAMMING:**');
      buffer.writeln('1. Start with explanation of what the concept does');
      buffer.writeln('2. Use language label above code: **PYTHON** (or **JAVASCRIPT**, **JAVA**, etc.)');
      buffer.writeln('3. Code in triple backticks with language: ```python');
      buffer.writeln('4. Explanation below code explaining what it does');
      buffer.writeln('5. Structure: Explanation → Language Label → Code Block → Code Explanation');
      buffer.writeln('6. Include: Syntax examples, 2-3 practical examples (simple → complex)');
      buffer.writeln('7. Use note boxes for edge cases and important rules');
      buffer.writeln('8. Separate sections with --- horizontal rules');
      buffer.writeln('');
    } else if (subjectType == 'language') {
      buffer.writeln('**FORMATTING REQUIREMENTS FOR LANGUAGES:**');
      buffer.writeln('1. Start with clear definition of grammar rule or concept');
      buffer.writeln('2. Use examples as bullet lists: **Examples:** followed by • items');
      buffer.writeln('3. Include: Rules, exceptions, practice sentences, common usage patterns');
      buffer.writeln('4. Use note boxes to highlight exceptions and important rules');
      buffer.writeln('5. Separate sections with --- horizontal rules');
      buffer.writeln('');
    } else {
      buffer.writeln('**FORMATTING REQUIREMENTS FOR THEORY/CONCEPTS:**');
      buffer.writeln('1. Start with clear definition (1-2 sentences)');
      buffer.writeln('2. Key terms in **BOLD**');
      buffer.writeln('3. Include: Definitions, bullet points, mnemonics, connections to other topics');
      buffer.writeln('4. Use note boxes for important clarifications');
      buffer.writeln('5. Separate sections with --- horizontal rules');
      buffer.writeln('');
    }

    buffer.writeln('**REQUIRED STRUCTURE (Professional NxtWave Style):**');
    buffer.writeln('');
    buffer.writeln('1. **# [Main Topic Title]** - Single H1 heading, no emoji in title');
    buffer.writeln('');
    buffer.writeln('2. **For Each Major Concept (## [Concept Name]):**');
    buffer.writeln('   - Start with clear 1-2 sentence definition');
    buffer.writeln('   - Add explanation paragraph if needed');
    buffer.writeln('   - Use **Examples:** followed by bullet list (•)');
    buffer.writeln('   - Use note boxes (> **📝 Note**) for important clarifications');
    buffer.writeln('   - Use **---** to separate major sections');
    buffer.writeln('');
    buffer.writeln('3. **For Code Examples:**');
    buffer.writeln('   - Language label: **PYTHON** (or appropriate language)');
    buffer.writeln('   - Code block: ```python');
    buffer.writeln('   - Explanation below code');
    buffer.writeln('');
    buffer.writeln('4. **For Formulas (Math/Physics):**');
    buffer.writeln('   - Explanation first');
    buffer.writeln('   - Formula in code block: ```');
    buffer.writeln('   - Variable explanations');
    buffer.writeln('');
    buffer.writeln('5. **Note Boxes Format:**');
    buffer.writeln('   > **📝 Note**');
    buffer.writeln('   >');
    buffer.writeln('   > [Important information]');
    buffer.writeln('   >');
    buffer.writeln('   > **Bold terms** and explanations.');
    buffer.writeln('   >');
    buffer.writeln('   > • Bullet point 1');
    buffer.writeln('   > • Bullet point 2');
    buffer.writeln('');

    buffer.writeln('**LEVEL ADJUSTMENTS:**');
    if (userLevel == 'beginner') {
      buffer.writeln('- More explanations, fewer assumptions');
      buffer.writeln('- Simpler examples');
      buffer.writeln('- More step-by-step breakdowns');
      buffer.writeln('- Links to prerequisite concepts');
    } else if (userLevel == 'advanced') {
      buffer.writeln('- Concise definitions');
      buffer.writeln('- Complex edge cases');
      buffer.writeln('- Integration with other topics');
      buffer.writeln('- Advanced applications and optimization');
    } else {
      buffer.writeln('- Balanced explanation and practice');
      buffer.writeln('- Multiple examples showing variations');
      buffer.writeln('- Compare/contrast similar concepts');
    }
    buffer.writeln('');

    buffer.writeln('**DESIGN PRINCIPLES (NxtWave Style):**');
    buffer.writeln('- Clean, minimalist design with white background');
    buffer.writeln('- Clear typography hierarchy: # (H1) → ## (H2) → ### (H3)');
    buffer.writeln('- Explanation-first: Define concept before showing examples');
    buffer.writeln('- Use horizontal rules (---) between major sections');
    buffer.writeln('- Code blocks with language labels above: **PYTHON** then ```python');
    buffer.writeln('- Note boxes using blockquotes: > **📝 Note**');
    buffer.writeln('- Bullet lists for examples: **Examples:** followed by • items');
    buffer.writeln('- Inline code for values: `variable_name`');
    buffer.writeln('- Bold for key terms: **Important Term**');
    buffer.writeln('- Chunking: No paragraph longer than 3-4 lines');
    buffer.writeln('- Scannable: Find any section in 5 seconds');
    buffer.writeln('- Professional appearance: Like published educational content');
    buffer.writeln('- Mobile-optimized: Single column, readable on small screens');
    buffer.writeln('');

    buffer.writeln('**EMOJI USAGE (Minimal, Strategic):**');
    buffer.writeln('- 📝 = Note boxes only (> **📝 Note**)');
    buffer.writeln('- 💡 = Tips if needed (> **💡 Tip**)');
    buffer.writeln('- ⚠️ = Warnings if needed (> **⚠️ Warning**)');
    buffer.writeln('- NO emojis in headings or titles');
    buffer.writeln('- NO emoji circles (🟡🔵🔴)');
    buffer.writeln('- NO excessive emojis anywhere');
    buffer.writeln('');
    buffer.writeln('**ABSOLUTELY FORBIDDEN:**');
    buffer.writeln('- HTML tags (<span>, <div>, <p>, etc.)');
    buffer.writeln('- Inline styles (style="background-color", etc.)');
    buffer.writeln('- Emoji circles after formulas or code');
    buffer.writeln('- Complex tables (use simple bullet lists instead)');
    buffer.writeln('- Multiple columns or complex layouts');
    buffer.writeln('- Decorative elements or visual clutter');
    buffer.writeln('');

    buffer.writeln('**CRITICAL FORMATTING RULES (NxtWave Style):**');
    buffer.writeln('');
    buffer.writeln('1. **ONLY pure markdown** - NO HTML tags, NO inline styles');
    buffer.writeln('');
    buffer.writeln('2. **Code Examples Format:**');
    buffer.writeln('   **PYTHON**');
    buffer.writeln('   ```python');
    buffer.writeln('   age = 10');
    buffer.writeln('   ```');
    buffer.writeln('   [Explanation below code]');
    buffer.writeln('');
    buffer.writeln('3. **Note Boxes Format:**');
    buffer.writeln('   > **📝 Note**');
    buffer.writeln('   >');
    buffer.writeln('   > [Important information]');
    buffer.writeln('   >');
    buffer.writeln('   > **Bold terms** and explanations.');
    buffer.writeln('   >');
    buffer.writeln('   > • Bullet point 1');
    buffer.writeln('   > • Bullet point 2');
    buffer.writeln('');
    buffer.writeln('4. **Examples Format:**');
    buffer.writeln('   **Examples:**');
    buffer.writeln('   • `"Hello World!"`');
    buffer.writeln('   • `"some@example.com"`');
    buffer.writeln('   • `"1234"`');
    buffer.writeln('');
    buffer.writeln('5. **Section Separators:**');
    buffer.writeln('   Use --- (three dashes) between major sections');
    buffer.writeln('');
    buffer.writeln('**EXAMPLE OUTPUT STRUCTURE:**');
    buffer.writeln('```markdown');
    buffer.writeln('# Variables and Data Types');
    buffer.writeln('');
    buffer.writeln('## Variables');
    buffer.writeln('');
    buffer.writeln('Variables are like containers for storing values. Values in the variables can be changed.');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('## String');
    buffer.writeln('');
    buffer.writeln('A String is a stream of characters enclosed within quotes.');
    buffer.writeln('');
    buffer.writeln('**Examples:**');
    buffer.writeln('');
    buffer.writeln('• `"Hello World!"`');
    buffer.writeln('• `"some@example.com"`');
    buffer.writeln('');
    buffer.writeln('> **📝 Note**');
    buffer.writeln('>');
    buffer.writeln('> Both single quotes and double quotes are considered as strings.');
    buffer.writeln('>');
    buffer.writeln('> • \'hello\'');
    buffer.writeln('> • "hello"');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('## Assigning Value to Variable');
    buffer.writeln('');
    buffer.writeln('The following is the syntax for assigning an integer value `10` to a variable `age`:');
    buffer.writeln('');
    buffer.writeln('**PYTHON**');
    buffer.writeln('```python');
    buffer.writeln('age = 10');
    buffer.writeln('```');
    buffer.writeln('');
    buffer.writeln('Here the equals to `=` sign is called as **Assignment Operator** as it is used to assign values to variables.');
    buffer.writeln('```');
    buffer.writeln('');
    buffer.writeln('**KEY POINTS:**');
    buffer.writeln('- Start with definition/explanation BEFORE examples');
    buffer.writeln('- Use simple, clear language');
    buffer.writeln('- Keep code examples short (1-5 lines)');
    buffer.writeln('- Use note boxes for important clarifications');
    buffer.writeln('- NO HTML, NO inline styles, NO emoji circles');
    buffer.writeln('- Clean, professional, minimalist style');
    buffer.writeln('');
    buffer.writeln('**OUTPUT REQUIREMENTS:**');
    buffer.writeln('1. Generate ONLY pure markdown content (no HTML, no meta-commentary)');
    buffer.writeln('2. Start directly with the main topic heading: # [Topic Name]');
    buffer.writeln('3. Follow the NxtWave style: clean, minimalist, explanation-first');
    buffer.writeln('4. Use proper markdown syntax only');
    buffer.writeln('5. Ensure all content is scannable and professional');
    buffer.writeln('');
    buffer.writeln('**FINAL CHECKLIST:**');
    buffer.writeln('- [ ] Main topic has single H1 heading (no emoji in title)');
    buffer.writeln('- [ ] Each major concept starts with clear definition');
    buffer.writeln('- [ ] Code examples have language label above: **PYTHON**');
    buffer.writeln('- [ ] Note boxes use blockquote format: > **📝 Note**');
    buffer.writeln('- [ ] Examples use bullet format: **Examples:** followed by • items');
    buffer.writeln('- [ ] Sections separated by --- horizontal rules');
    buffer.writeln('- [ ] NO HTML tags whatsoever');
    buffer.writeln('- [ ] NO inline styles');
    buffer.writeln('- [ ] NO emoji circles (🟡🔵🔴)');
    buffer.writeln('- [ ] Clean, professional, minimalist appearance');
    buffer.writeln('');
    buffer.writeln('Generate the cheat sheet now following the NxtWave professional style:');

    return buffer.toString();
  }

  /// Clean HTML tags from markdown content
  static String _cleanHtmlTags(String content) {
    // Remove HTML tags but preserve their text content
    String cleaned = content;
    
    // Remove span tags but keep content
    cleaned = cleaned.replaceAll(RegExp(r'<span[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</span>', caseSensitive: false), '');
    
    // Remove other common HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</div>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</p>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    
    // Remove style attributes that might be in other tags
    cleaned = cleaned.replaceAll(RegExp(r'style="[^"]*"', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r"style='[^']*'", caseSensitive: false), '');
    
    // Clean up any remaining HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), '');
    
    // Clean up extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    return cleaned.trim();
  }
}

