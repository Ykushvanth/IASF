import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduai/models/roadmap_backend.dart';
import 'package:eduai/models/video_backend.dart';

class TopicDetailsScreen extends StatefulWidget {
  final String courseName;
  final String subjectName;
  final List<Map<String, dynamic>> topics;

  const TopicDetailsScreen({
    super.key,
    required this.courseName,
    required this.subjectName,
    required this.topics,
  });

  @override
  State<TopicDetailsScreen> createState() => _TopicDetailsScreenState();
}

class _TopicDetailsScreenState extends State<TopicDetailsScreen> {
  int _selectedTopicIndex = 0;
  Map<String, dynamic>? _currentTopicData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTopicData();
  }

  Future<void> _loadTopicData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final topic = widget.topics[_selectedTopicIndex];
      final topicName = (topic['name'] ?? 'Unknown Topic').toString();

      // Check if data exists in Firebase
      final user = FirebaseAuth.instance.currentUser;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('topicData')
          .doc('${widget.courseName}_${widget.subjectName}_$topicName');

      final docSnap = await docRef.get();

      if (docSnap.exists && docSnap.data() != null) {
        // Load from Firebase
        setState(() {
          _currentTopicData = docSnap.data();
          _isLoading = false;
        });
      } else {
        // Generate new data
        final mindsetDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get();
        
        final rawAnswers = mindsetDoc.data()?['mindsetAnswers'] ?? {};
        final mindsetAnswers = <String, String>{};
        
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

        final result = await RoadmapBackend.generateTopicContent(
          topicName: topicName,
          courseName: widget.courseName,
          subjectName: widget.subjectName,
          difficulty: (topic['difficulty'] ?? 'medium').toString(),
          mindsetProfile: mindsetAnswers,
        );

        if (result['success'] == true) {
          final topicData = result['data'] as Map<String, dynamic>;
          
          // Save to Firebase
          await docRef.set(topicData);

          setState(() {
            _currentTopicData = topicData;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to load topic'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading topic: $e');
      setState(() {
        _isLoading = false;
      });
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

  void _switchTopic(int index) {
    setState(() {
      _selectedTopicIndex = index;
      _currentTopicData = null;
    });
    _loadTopicData();
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topics[_selectedTopicIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        title: Text(
          widget.subjectName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading topic content...'),
                ],
              ),
            )
          : Column(
              children: [
                // Topic Navigation Tabs
                Container(
                  height: 60,
                  color: Colors.white,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.topics.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedTopicIndex;
                      return GestureDetector(
                        onTap: () => _switchTopic(index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.topics[index]['name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Content Area
                Expanded(
                  child: _currentTopicData == null
                      ? const Center(child: Text('No data available'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Topic Header
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      topic['name'],
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  _buildDifficultyBadge(topic['difficulty']),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Video Section
                              _buildVideoList(),
                              const SizedBox(height: 32),
                              
                              // Practice Section
                              const Text(
                                'Practice & Assessments',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.quiz,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Test your knowledge',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Take a practice test to assess your understanding',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Practice test coming soon!'),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF6366F1),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'Start Practice Test',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildVideoList() {
    final videos = _currentTopicData!['videos'] as List<dynamic>? ?? [];
    if (videos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: Color(0xFF64748B),
            ),
            SizedBox(height: 12),
            Text(
              'No videos available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Videos will be available soon',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Lectures',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(videos.length, (index) {
          final video = videos[index];
          return VideoBackend.buildVideoCard(
            context: context,
            video: video as Map<String, dynamic>,
            relatedVideos: videos.cast<Map<String, dynamic>>(),
          );
        }),
      ],
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    final color = _getDifficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
