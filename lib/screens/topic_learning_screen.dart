import 'package:flutter/material.dart';
import 'package:eduai/models/video_backend.dart';
import 'package:eduai/screens/cheat_sheet.dart';
import 'package:eduai/screens/summarize_screen.dart';
import 'package:eduai/screens/practice_screen.dart';
import 'package:eduai/screens/test_screen.dart';

/// TopicLearningScreen - Main screen for a single topic
/// Shows: Videos, Summarize, Cheat Sheet, Practice, Test
class TopicLearningScreen extends StatefulWidget {
  final String courseName;
  final String topicName;
  final String difficulty;
  final List<Map<String, dynamic>> videos;
  final Map<String, dynamic>? topicData;

  const TopicLearningScreen({
    super.key,
    required this.courseName,
    required this.topicName,
    required this.difficulty,
    required this.videos,
    this.topicData,
  });

  @override
  State<TopicLearningScreen> createState() => _TopicLearningScreenState();
}

class _TopicLearningScreenState extends State<TopicLearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        title: Text(
          widget.topicName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Videos'),
            Tab(icon: Icon(Icons.summarize), text: 'Summarize'),
            Tab(icon: Icon(Icons.article), text: 'Cheat Sheet'),
            Tab(icon: Icon(Icons.quiz), text: 'Practice'),
            Tab(icon: Icon(Icons.assignment), text: 'Test'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideosTab(),
          _buildSummarizeTab(),
          _buildCheatSheetTab(),
          _buildPracticeTab(),
          _buildTestTab(),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    if (widget.videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No videos available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Videos will be available soon',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Video Lectures',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        ...widget.videos.map((video) {
          return VideoBackend.buildVideoCard(
            context: context,
            video: video,
            relatedVideos: widget.videos,
          );
        }),
      ],
    );
  }

  Widget _buildSummarizeTab() {
    return SummarizeScreen(
      courseName: widget.courseName,
      topicName: widget.topicName,
      difficulty: widget.difficulty,
      videos: widget.videos,
    );
  }

  Widget _buildCheatSheetTab() {
    return CheatSheetScreen(
      courseName: widget.courseName,
      topicName: widget.topicName,
      difficulty: widget.difficulty,
    );
  }

  Widget _buildPracticeTab() {
    return PracticeScreen(
      courseName: widget.courseName,
      topicName: widget.topicName,
      difficulty: widget.difficulty,
    );
  }

  Widget _buildTestTab() {
    return TestScreen(
      courseName: widget.courseName,
      topicName: widget.topicName,
      difficulty: widget.difficulty,
    );
  }
}

