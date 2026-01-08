import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:eduai/screens/singup.dart';
import 'package:eduai/screens/academic_context.dart';
import 'package:eduai/screens/mindset_analysis.dart';
import 'package:eduai/screens/course_selection.dart';
import 'package:eduai/screens/roadmap_screen.dart';
import 'package:eduai/screens/ai_understanding_profile.dart';
import 'package:eduai/screens/study_groups_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: "config/.env");
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduAi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is not logged in - show signup screen
        if (!snapshot.hasData || snapshot.data == null) {
          return const SignUpScreen();
        }

        // User is logged in - check their progress
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User data doesn't exist, logout and go to signup
              FirebaseAuth.instance.signOut();
              return const SignUpScreen();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;

            // FLOW: Academic Context → Mindset Analysis (ONE TIME) → Home Dashboard
            // Mindset analysis happens only once during initial setup
            // The mindset data is then used to personalize the roadmap
            
            // Check if academic context is completed
            if (userData['academicContextCompleted'] != true) {
              return const AcademicContextScreen();
            }

            // Check if mindset analysis is completed (ONE TIME ONLY)
            if (userData['mindsetAnalysisCompleted'] != true) {
              return const MindsetAnalysisScreen();
            }

            // All setup complete - show home screen
            return HomeScreen(userData: userData);
          },
        );
      },
    );
  }
}

// Temporary Home Screen (you can expand this later)
class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    print('🏠 HomeScreen userData: ${userData.keys}');
    print('📚 selectedCourse: ${userData['selectedCourse']}');
    print('🗺️ roadmap exists: ${userData['roadmap'] != null}');
    if (userData['roadmap'] != null) {
      print('🗺️ roadmap length: ${(userData['roadmap'] as List).length}');
    }
    
    final hasSelectedCourse = userData['selectedCourse'] != null;
    final hasRoadmap = userData['roadmap'] != null && 
                       (userData['roadmap'] as List?)?.isNotEmpty == true;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduAi Dashboard'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 32,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    userData['fullName'] ?? 'Student',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                        _buildStatusItem(
                          Icons.check_circle,
                          'Mindset Analysis',
                          'Completed',
                          Colors.green,
                        ),
                        if (hasSelectedCourse)
                          _buildStatusItem(
                            Icons.school,
                            'Selected Course',
                            userData['selectedCourse']?.split('(')[0] ?? 'Unknown',
                            const Color(0xFF6366F1),
                          ),
                        if (hasRoadmap)
                          _buildStatusItem(
                            Icons.map,
                            'Learning Roadmap',
                            'Ready to explore',
                            const Color(0xFF8B5CF6),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // AI Understanding Button - Always visible
                _buildActionCard(
                  context,
                  icon: Icons.smart_toy,
                  title: 'AI Understanding Profile',
                  description: 'See how AI understands your learning style',
                  color: Colors.cyan,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AIUnderstandingProfileScreen(),
                      ),
                    );
                  },
                ),
                
                // Study Groups Button - Always visible
                _buildActionCard(
                  context,
                  icon: Icons.groups,
                  title: 'Study Groups',
                  description: 'Join or create study groups to learn together',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudyGroupsScreen(),
                      ),
                    );
                  },
                ),
                
                if (!hasSelectedCourse)
                  _buildActionCard(
                    context,
                    icon: Icons.school,
                    title: 'Choose Your Course',
                    description: 'Select the exam you want to prepare for',
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CourseSelectionScreen(),
                        ),
                      );
                    },
                  ),
                
                // Show roadmap button if roadmap exists
                if (hasRoadmap)
                  _buildActionCard(
                    context,
                    icon: Icons.map,
                    title: 'View Learning Roadmap',
                    description: 'Continue your personalized learning journey',
                    color: const Color(0xFF8B5CF6),
                    onTap: () async {
                      final roadmap = List<Map<String, dynamic>>.from(
                        userData['roadmap'] ?? [],
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoadmapScreen(
                            courseName: userData['selectedCourse'] ?? 'Course',
                            roadmap: roadmap,
                          ),
                        ),
                      );
                    },
                  ),
                
                // Show message if course selected but no roadmap yet
                if (hasSelectedCourse && !hasRoadmap)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.orange[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 40,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Roadmap Not Generated Yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete the course questionnaire to generate your personalized learning roadmap',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CourseSelectionScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Complete Setup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Settings/Options Card - Always show for course management
                if (hasSelectedCourse)
                  Card(
                    margin: const EdgeInsets.only(top: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.settings, color: Color(0xFF6366F1)),
                          title: const Text('Course Settings'),
                          subtitle: Text(userData['selectedCourse']?.split('(')[0] ?? 'Unknown'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
                          title: const Text('Regenerate Roadmap'),
                          subtitle: const Text('Update with latest features'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            // Show confirmation dialog
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Regenerate Roadmap?'),
                                content: const Text(
                                  'This will create a NEW personalized roadmap with AI. Your current roadmap will be replaced with a fresh one tailored to your learning profile.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                    ),
                                    child: const Text('Regenerate'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              // Clear old roadmap data (fix any database structure issues)
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                // Clear roadmap completely to fix null errors
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                  'roadmap': [],
                                  'roadmapGeneratedAt': FieldValue.serverTimestamp(),
                                });
                                
                                if (context.mounted) {
                                  // Navigate to course selection to generate new roadmap
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CourseSelectionScreen(),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
