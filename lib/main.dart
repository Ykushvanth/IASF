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
import 'package:eduai/screens/leaderboard_screen.dart';
import 'package:eduai/screens/rewards_shop_screen.dart';
import 'package:eduai/models/gamification_backend.dart';
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

// Production-Level Home Screen with Gamification
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _gamificationStats;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeGamification();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeGamification() async {
    await GamificationBackend.initializeUserGamification();
    final streakResult = await GamificationBackend.updateDailyStreak();
    final stats = await GamificationBackend.getGamificationStats();
    
    setState(() {
      _gamificationStats = stats;
      _isLoading = false;
    });

    // Show streak notification
    if (streakResult['success'] == true && mounted) {
      if (streakResult['earnedCoin'] == true) {
        _showStreakNotification(
          '🎉 Weekly Goal Complete!',
          'You earned 1 Gold Coin for maintaining a 7-day streak!',
          Colors.amber,
        );
      } else if (streakResult['streakBroken'] == true) {
        _showStreakNotification(
          '💔 Streak Broken',
          'Don\'t worry! Start fresh today.',
          Colors.orange,
        );
      } else if (streakResult['currentStreak'] > 1) {
        _showStreakNotification(
          '🔥 Streak Active!',
          '${streakResult['currentStreak']} days and counting!',
          Colors.deepOrange,
        );
      }
    }
  }

  void _showStreakNotification(String title, String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.celebration, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏠 HomeScreen userData: ${widget.userData.keys}');
    
    final hasSelectedCourse = widget.userData['selectedCourse'] != null;
    final hasRoadmap = widget.userData['roadmap'] != null && 
                       (widget.userData['roadmap'] as List?)?.isNotEmpty == true;
    
    final currentStreak = _gamificationStats?['currentStreak'] ?? 0;
    final goldCoins = _gamificationStats?['goldCoins'] ?? 0;
    final weeklyConsistency = _gamificationStats?['weeklyConsistency'] ?? 0;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Modern App Bar
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      (widget.userData['fullName'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Welcome back,',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          widget.userData['fullName'] ?? 'Student',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                ),

                // Content
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gamification Stats Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.local_fire_department,
                                  label: 'Streak',
                                  value: '$currentStreak',
                                  subtitle: '$weeklyConsistency/7 this week',
                                  color: Colors.deepOrange,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LeaderboardScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.stars,
                                  label: 'Gold Coins',
                                  value: '$goldCoins',
                                  subtitle: 'Tap to shop',
                                  color: Colors.amber,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RewardsShopScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Quick Actions Section
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
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

                          if (hasRoadmap)
                            _buildActionCard(
                              context,
                              icon: Icons.map,
                              title: 'Continue Learning',
                              description: 'Your personalized roadmap awaits',
                              color: const Color(0xFF6366F1),
                              onTap: () async {
                                final roadmap = List<Map<String, dynamic>>.from(
                                  widget.userData['roadmap'] ?? [],
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RoadmapScreen(
                                      courseName: widget.userData['selectedCourse'] ?? 'Course',
                                      roadmap: roadmap,
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          _buildActionCard(
                            context,
                            icon: Icons.leaderboard,
                            title: 'Leaderboard',
                            description: 'See how you rank among peers',
                            color: const Color(0xFF6366F1),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LeaderboardScreen(),
                                ),
                              );
                            },
                          ),
                          
                          _buildActionCard(
                            context,
                            icon: Icons.groups,
                            title: 'Study Groups',
                            description: 'Join or create study groups',
                            color: const Color(0xFF6366F1),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const StudyGroupsScreen(),
                                ),
                              );
                            },
                          ),
                          
                          _buildActionCard(
                            context,
                            icon: Icons.smart_toy,
                            title: 'AI Profile',
                            description: 'See how AI understands your learning style',
                            color: const Color(0xFF6366F1),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AIUnderstandingProfileScreen(),
                                ),
                              );
                            },
                          ),

                          if (hasSelectedCourse && !hasRoadmap)
                            Card(
                              margin: const EdgeInsets.only(top: 12),
                              color: Colors.orange[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
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
                                      'Complete the course questionnaire',
                                      style: TextStyle(fontSize: 14, color: Colors.orange[800]),
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
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (hasSelectedCourse)
                            Card(
                              margin: const EdgeInsets.only(top: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.settings, color: Color(0xFF6366F1)),
                                    title: const Text('Course Settings'),
                                    subtitle: Text(widget.userData['selectedCourse']?.split('(')[0] ?? 'Unknown'),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
                                    title: const Text('Regenerate Roadmap'),
                                    subtitle: const Text('Update with latest features'),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Regenerate Roadmap?'),
                                          content: const Text(
                                            'This will create a NEW personalized roadmap.',
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
                                        final user = FirebaseAuth.instance.currentUser;
                                        if (user != null) {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user.uid)
                                              .update({
                                            'roadmap': [],
                                            'roadmapGeneratedAt': FieldValue.serverTimestamp(),
                                          });
                                          
                                          if (context.mounted) {
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
              ],
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
