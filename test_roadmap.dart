import 'package:eduai/models/roadmap_backend.dart';
import 'package:firebase_core/firebase_core.dart';

/// Quick test to debug roadmap generation
/// Run with: flutter run test_roadmap.dart
void main() async {
  print('🧪 Testing Roadmap Generation...\n');
  
  // Test data
  final testCourse = 'GATE (Graduate Aptitude Test in Engineering)';
  final testMindset = {
    'directionClarity': 'Confused',
    'confusionFactors': 'Too many topics, not sure where to start',
    'forgettingFrequency': 'Often',
    'examEmotionalState': 'Fear/Anxiety',
  };
  
  print('📋 Test Input:');
  print('Course: $testCourse');
  print('Mindset: $testMindset\n');
  
  try {
    // Note: This will fail without Firebase initialization
    // Use this to understand the flow and debug print statements
    final result = await RoadmapBackend.generateRoadmap(
      courseName: testCourse,
      mindsetProfile: testMindset,
    );
    
    print('\n✅ Result:');
    print('Success: ${result['success']}');
    if (result['success']) {
      final roadmap = result['roadmap'] as List;
      print('Roadmap items: ${roadmap.length}');
      print('\nFirst 3 items:');
      for (var i = 0; i < (roadmap.length < 3 ? roadmap.length : 3); i++) {
        print('${i + 1}. ${roadmap[i]['topic']} (${roadmap[i]['difficulty']})');
        if (roadmap[i]['whyNow'] != null) {
          print('   Why: ${roadmap[i]['whyNow']}');
        }
      }
    } else {
      print('Error: ${result['message']}');
    }
  } catch (e) {
    print('\n❌ Test failed: $e');
  }
}
