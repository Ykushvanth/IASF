import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eduai/models/summarizer_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// SummarizeScreen - Displays and generates topic or video summaries
class SummarizeScreen extends StatefulWidget {
  final String courseName;
  final String topicName;
  final String difficulty;
  final List<Map<String, dynamic>>? videos;
  final VoidCallback? onSummaryGenerated;

  const SummarizeScreen({
    super.key,
    required this.courseName,
    required this.topicName,
    required this.difficulty,
    this.videos,
    this.onSummaryGenerated,
  });

  @override
  State<SummarizeScreen> createState() => _SummarizeScreenState();
}

class _SummarizeScreenState extends State<SummarizeScreen> {
  String? _summary;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _selectedVideo;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Determine document ID
      final docId = _selectedVideo != null 
          ? '${widget.courseName}_${widget.topicName}_${_selectedVideo!['videoId'] ?? _selectedVideo!['title']}'
          : '${widget.courseName}_${widget.topicName}';
      
      // Check Firebase first
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('summaries')
            .doc(docId);

        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          final data = docSnap.data()!;
          setState(() {
            _summary = data['summary'] as String?;
            _isLoading = false;
          });
          return;
        }
      }

      // Generate new summary
      final result = await SummarizerBackend.generateSummary(
        topicName: widget.topicName,
        courseName: widget.courseName,
        difficulty: widget.difficulty,
        userLevel: 'intermediate',
        videoData: _selectedVideo,
      );

      if (result['success'] == true) {
        setState(() {
          _summary = result['summary'] as String?;
          _isLoading = false;
        });
        // Call callback after summary is generated
        if (widget.onSummaryGenerated != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            widget.onSummaryGenerated!();
          });
        }
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to generate summary';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerateSummary() async {
    // Delete existing summary
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docId = _selectedVideo != null 
          ? '${widget.courseName}_${widget.topicName}_${_selectedVideo!['videoId'] ?? _selectedVideo!['title']}'
          : '${widget.courseName}_${widget.topicName}';
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('summaries')
          .doc(docId)
          .delete();
    }

    // Clear summary to force regeneration
    setState(() {
      _summary = null;
    });

    await _loadSummary();
  }

  void _selectVideo(Map<String, dynamic> video) {
    setState(() {
      _selectedVideo = video;
      _summary = null; // Clear current summary
    });
    _loadSummary();
  }

  void _clearVideoSelection() {
    setState(() {
      _selectedVideo = null;
      _summary = null; // Clear current summary
    });
    _loadSummary();
  }

  Future<void> _copyToClipboard() async {
    if (_summary != null) {
      await Clipboard.setData(ClipboardData(text: _summary!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary copied to clipboard!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Generating summary...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
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
      );
    }

    if (_summary == null || _summary!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.summarize_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No summary available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate Summary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Video selection (if videos are available)
        if (widget.videos != null && widget.videos!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.video_library, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Video to Summarize',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    if (_selectedVideo != null)
                      TextButton.icon(
                        onPressed: _clearVideoSelection,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.videos!.length,
                    itemBuilder: (context, index) {
                      final video = widget.videos![index];
                      final isSelected = _selectedVideo?['videoId'] == video['videoId'];
                      return GestureDetector(
                        onTap: () => _selectVideo(video),
                        child: Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFF6366F1) 
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected 
                                ? const Color(0xFF6366F1).withOpacity(0.05)
                                : Colors.grey[50],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video['title'] ?? 'Video',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected 
                                      ? FontWeight.w600 
                                      : FontWeight.normal,
                                  color: const Color(0xFF1E293B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: const Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Selected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        // Action buttons
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Regenerate',
                onPressed: _regenerateSummary,
                color: const Color(0xFF6366F1),
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Copy',
                onPressed: _copyToClipboard,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ),
        // Summary content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _summary!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1E293B),
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

