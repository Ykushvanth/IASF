import 'package:flutter/material.dart';
import 'package:eduai/screens/topic_learning_screen.dart';
import 'package:eduai/models/roadmap_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoadmapScreen extends StatefulWidget {
  final String courseName;
  final List<Map<String, dynamic>> roadmap;

  const RoadmapScreen({
    super.key,
    required this.courseName,
    required this.roadmap,
  });

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> with SingleTickerProviderStateMixin {
  bool _isGeneratingWeek = false;
  List<Map<String, dynamic>> _roadmap = [];
  late AnimationController _coinAnimationController;
  late Animation<double> _coinPulseAnimation;

  @override
  void initState() {
    super.initState();
    _roadmap = widget.roadmap;
    
    // Animation for gold coin pulse effect
    _coinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _coinPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _coinAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _coinAnimationController.dispose();
    super.dispose();
  }

  Future<void> _generateNextWeek() async {
    setState(() => _isGeneratingWeek = true);
    
    try {
      final result = await RoadmapBackend.generateNextWeek(
        courseName: widget.courseName,
      );
      
      if (result['success'] == true) {
        // Reload roadmap from Firebase
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          final updatedRoadmap = (userDoc.data()?['roadmap'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ?? [];
          
          setState(() {
            _roadmap = updatedRoadmap;
            _isGeneratingWeek = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Next week generated!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        setState(() => _isGeneratingWeek = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to generate week'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isGeneratingWeek = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _canGenerateNextWeek() {
    if (_roadmap.isEmpty) return false;
    
    // Get current week number
    final weeks = _roadmap.map((item) => item['week'] ?? 1).toList();
    if (weeks.isEmpty) return false; // Safety check before reduce
    final currentWeek = weeks.reduce((a, b) => a > b ? a : b);
    
    // Check if all days in current week are completed
    final currentWeekDays = _roadmap.where((item) => item['week'] == currentWeek).toList();
    final allCompleted = currentWeekDays.every((day) => day['completed'] == true);
    
    return allCompleted;
  }

  @override
  Widget build(BuildContext context) {
    // Handle null or empty roadmap
    if (_roadmap.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF6366F1),
          title: const Text('Your Learning Roadmap'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No roadmap data found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please regenerate your roadmap'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Group roadmap by weeks
    print('📊 DEBUG: Total roadmap items: ${_roadmap.length}');
    final Map<int, List<Map<String, dynamic>>> weekGroups = {};
    for (var item in _roadmap) {
      final week = item['week'] ?? 1;
      final day = item['day'] ?? 0;
      final videos = item['videos'] as List? ?? [];
      print('📅 Day $day, Week $week, Videos: ${videos.length}');
      if (!weekGroups.containsKey(week)) {
        weekGroups[week] = [];
      }
      weekGroups[week]!.add(item);
    }
    print('📊 Total weeks grouped: ${weekGroups.length}');
    print('📊 Weeks: ${weekGroups.keys.toList()}');
    
    final canGenerateNext = _canGenerateNextWeek();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        title: const Text(
          'Your Learning Roadmap',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.courseName.split('(')[0].trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_roadmap.length} days of learning • ${weekGroups.length} weeks',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProgressBar(),
              ],
            ),
          ),
          // Week-by-week list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Build all week sections
                ...() {
                  final sortedWeeks = weekGroups.keys.toList()..sort();
                  return sortedWeeks.map((weekNumber) {
                    final weekDays = weekGroups[weekNumber]!;
                    final weekTheme = weekDays.isNotEmpty ? weekDays[0]['weekTheme'] ?? '' : '';
                    print('📋 Rendering Week $weekNumber with ${weekDays.length} days');
                    return _buildWeekSection(weekNumber, weekTheme, weekDays);
                  }).toList();
                }(),
                
                // Generate Next Week button
                if (_isGeneratingWeek)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Generating next week...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (canGenerateNext)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _generateNextWeek,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                        label: const Text(
                          'Generate Next Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Complete all days in the current week to unlock the next week!',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final completed = _roadmap.where((t) => t['completed'] == true).length;
    final total = _roadmap.length;
    final progress = total > 0 ? completed / total : 0.0;
    
    // Calculate average test score
    final completedTopics = _roadmap.where((t) => t['completed'] == true && t['testScore'] != null).toList();
    final averageScore = (completedTopics.isNotEmpty && completedTopics.length > 0)
        ? (completedTopics.map((t) => t['testScore'] as int).reduce((a, b) => a + b) / completedTopics.length).round()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress: $completed/$total topics',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (averageScore != null)
              Text(
                'Avg Score: $averageScore%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 40, // Add height to accommodate coin above progress bar
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Progress bar
                  Positioned(
                    top: 20, // Position progress bar below coin
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  // Gold coin at the end of progress - motivational reward (above the progress line)
                  Positioned(
                    left: (constraints.maxWidth - 20) * progress.clamp(0.0, 1.0),
                    top: 0, // Position above the progress bar
                    child: AnimatedBuilder(
                      animation: _coinPulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _coinPulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.6 * _coinPulseAnimation.value),
                                  blurRadius: 10 * _coinPulseAnimation.value,
                                  spreadRadius: 2 * _coinPulseAnimation.value,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.monetization_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekSection(int weekNumber, String weekTheme, List<Map<String, dynamic>> days) {
    final completedDays = days.where((day) => day['completed'] == true).length;
    final totalDays = days.length;
    final isCurrentWeek = weekNumber == (_roadmap.isNotEmpty ? _roadmap.last['week'] : 1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF6366F1).withOpacity(isCurrentWeek ? 0.2 : 0.1),
                Color(0xFF8B5CF6).withOpacity(isCurrentWeek ? 0.2 : 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(isCurrentWeek ? 0.5 : 0.3),
              width: isCurrentWeek ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Week $weekNumber',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      if (isCurrentWeek) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedDays == totalDays
                          ? Colors.green.withOpacity(0.2)
                          : const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: completedDays == totalDays
                            ? Colors.green
                            : const Color(0xFF6366F1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          completedDays == totalDays
                              ? Icons.check_circle
                              : Icons.schedule,
                          size: 14,
                          color: completedDays == totalDays
                              ? Colors.green
                              : const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedDays/$totalDays days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: completedDays == totalDays
                                ? Colors.green
                                : const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (weekTheme.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  weekTheme,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Days in this week
        ...days.map((day) => _buildDayCard(day)).toList(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final dayNumber = day['day'] ?? 0;
    final topic = day['topic'] ?? 'No topic';
    final difficulty = day['difficulty'] ?? 'medium';
    final whyNow = day['whyNow'] ?? '';
    final videos = (day['videos'] as List?) ?? [];
    final completed = day['completed'] == true;
    final testScore = day['testScore'] as int?;
    print('🎬 Day $dayNumber has ${videos.length} videos');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to topic learning screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TopicLearningScreen(
                courseName: widget.courseName,
                topicName: topic,
                difficulty: difficulty,
                videos: videos.cast<Map<String, dynamic>>(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: completed
                          ? Colors.green.withOpacity(0.2)
                          : _getDifficultyColor(difficulty).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Day',
                            style: TextStyle(
                              color: completed
                                  ? Colors.green
                                  : _getDifficultyColor(difficulty),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: completed
                                  ? Colors.green
                                  : _getDifficultyColor(difficulty),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (completed)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (whyNow.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              whyNow,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6366F1),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDifficultyBadge(difficulty),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.play_circle_outline,
                          size: 14,
                          color: videos.isEmpty ? Colors.grey : const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          videos.isEmpty ? 'Loading...' : '${videos.length} videos',
                          style: TextStyle(
                            fontSize: 12,
                            color: videos.isEmpty ? Colors.grey : const Color(0xFF64748B),
                            fontStyle: videos.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress indicators
                    Row(
                      children: [
                        // Videos: 1 is enough (show completed if at least 1 video watched)
                        _buildProgressChip(
                          icon: Icons.videocam,
                          label: 'Videos',
                          value: (day['videosWatched'] ?? 0) >= 1 ? 1 : 0,
                          total: 1,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        // Practice: completed or not
                        _buildProgressChip(
                          icon: Icons.edit_note,
                          label: 'Practice',
                          value: day['practiceCompleted'] == true ? 1 : 0,
                          total: 1,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        // Test: completed (if testScore exists) or not
                        _buildProgressChip(
                          icon: Icons.quiz,
                          label: 'Test',
                          value: testScore != null ? 1 : 0,
                          total: 1,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    if (completed) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  testScore != null ? 'Test: $testScore%' : 'Completed',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Show recommended channels if available
                    if (day['recommendedChannels'] != null && 
                        (day['recommendedChannels'] as List).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: (day['recommendedChannels'] as List).take(3).map((channel) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_circle,
                                  size: 12,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  channel.toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6366F1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    final color = _getDifficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildProgressChip({
    required IconData icon,
    required String label,
    required int value,
    required int total,
    required Color color,
    bool isPercentage = false,
  }) {
    final bool isComplete = isPercentage ? value >= 70 : value >= total;
    // For binary completion (1/1), show checkmark when complete, else show the label
    final String displayValue = isComplete 
        ? (isPercentage ? '$value%' : '') 
        : (isPercentage ? '$value%' : '');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isComplete ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle : icon,
            size: 12,
            color: isComplete ? color : Colors.grey,
          ),
          if (displayValue.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isComplete ? color : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

}
