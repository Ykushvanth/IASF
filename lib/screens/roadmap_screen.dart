import 'package:flutter/material.dart';
import 'package:eduai/screens/topic_learning_screen.dart';

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

class _RoadmapScreenState extends State<RoadmapScreen> {

  @override
  Widget build(BuildContext context) {
    // Handle null or empty roadmap
    if (widget.roadmap.isEmpty) {
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
    print('📊 DEBUG: Total roadmap items: ${widget.roadmap.length}');
    final Map<int, List<Map<String, dynamic>>> weekGroups = {};
    for (var item in widget.roadmap) {
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
                  '${widget.roadmap.length} days of learning • ${weekGroups.length} weeks',
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: weekGroups.length,
              itemBuilder: (context, weekIndex) {
                final sortedWeeks = weekGroups.keys.toList()..sort();
                final weekNumber = sortedWeeks[weekIndex];
                final weekDays = weekGroups[weekNumber]!;
                final weekTheme = weekDays.isNotEmpty ? weekDays[0]['weekTheme'] ?? '' : '';
                print('📋 Rendering Week $weekNumber with ${weekDays.length} days');
                
                return _buildWeekSection(weekNumber, weekTheme, weekDays);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final completed = widget.roadmap.where((t) => t['completed'] == true).length;
    final total = widget.roadmap.length;
    final progress = total > 0 ? completed / total : 0.0;
    
    // Calculate average test score
    final completedTopics = widget.roadmap.where((t) => t['completed'] == true && t['testScore'] != null).toList();
    final averageScore = completedTopics.isNotEmpty
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
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekSection(int weekNumber, String weekTheme, List<Map<String, dynamic>> days) {
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
                Color(0xFF6366F1).withOpacity(0.1),
                Color(0xFF8B5CF6).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Week $weekNumber',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
              if (weekTheme.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                              videos.isEmpty ? 'Loading videos...' : '${videos.length} videos',
                              style: TextStyle(
                                fontSize: 12,
                                color: videos.isEmpty ? Colors.grey : const Color(0xFF64748B),
                                fontStyle: videos.isEmpty ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            if (completed) ...[
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
                          ],
                        ),
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

}
