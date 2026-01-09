import 'package:flutter/material.dart';
import 'package:eduai/screens/video.dart';

class VideoBackend {
  /// Navigate to video player screen
  static void playVideo(
    BuildContext context, {
    required String videoId,
    required String videoTitle,
    required String channelName,
    String? description,
    List<Map<String, dynamic>>? relatedVideos,
    VoidCallback? onVideoClosed,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoId: videoId,
          videoTitle: videoTitle,
          channelName: channelName,
          description: description,
          relatedVideos: relatedVideos,
        ),
      ),
    ).then((_) {
      // Show options after video is closed
      if (onVideoClosed != null) {
        onVideoClosed();
      }
    });
  }

  /// Extract video ID from various YouTube URL formats
  static String? extractVideoId(String url) {
    // Handle youtube.com/watch?v=VIDEO_ID
    if (url.contains('youtube.com/watch?v=')) {
      final uri = Uri.parse(url);
      return uri.queryParameters['v'];
    }
    
    // Handle youtu.be/VIDEO_ID
    if (url.contains('youtu.be/')) {
      return url.split('youtu.be/').last.split('?').first;
    }
    
    // Handle youtube.com/embed/VIDEO_ID
    if (url.contains('youtube.com/embed/')) {
      return url.split('youtube.com/embed/').last.split('?').first;
    }
    
    // If already a video ID
    if (url.length == 11 && !url.contains('/')) {
      return url;
    }
    
    return null;
  }

  /// Generate thumbnail URL from video ID
  static String getThumbnailUrl(String videoId, {String quality = 'medium'}) {
    final qualityMap = {
      'default': 'default.jpg',
      'medium': 'mqdefault.jpg',
      'high': 'hqdefault.jpg',
      'standard': 'sddefault.jpg',
      'maxres': 'maxresdefault.jpg',
    };
    
    final file = qualityMap[quality] ?? 'mqdefault.jpg';
    return 'https://img.youtube.com/vi/$videoId/$file';
  }

  /// Create a video card widget for displaying in lists
  static Widget buildVideoCard({
    required BuildContext context,
    required Map<String, dynamic> video,
    VoidCallback? onTap,
    List<Map<String, dynamic>>? relatedVideos,
    VoidCallback? onVideoClosed,
  }) {
    final videoId = video['videoId'] as String? ?? '';
    final title = video['title'] as String? ?? 'Untitled Video';
    final channelName = video['channelName'] as String? ?? 'Unknown Channel';
    final thumbnail = video['thumbnail'] as String? ?? getThumbnailUrl(videoId);
    final description = video['description'] as String?;
    final viewCount = video['viewCount'] as int?;

    return InkWell(
      onTap: onTap ?? () {
        playVideo(
          context,
          videoId: videoId,
          videoTitle: title,
          channelName: channelName,
          description: description,
          relatedVideos: relatedVideos,
          onVideoClosed: onVideoClosed,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Play Button
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    thumbnail,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.play_circle_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            
            // Video Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF6366F1),
                        child: Text(
                          channelName.isNotEmpty ? channelName[0].toUpperCase() : 'V',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channelName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (viewCount != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.remove_red_eye,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(viewCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M views';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K views';
    }
    return '$number views';
  }

  /// Build a compact video list item
  static Widget buildCompactVideoItem({
    required BuildContext context,
    required Map<String, dynamic> video,
    VoidCallback? onTap,
    List<Map<String, dynamic>>? relatedVideos,
    VoidCallback? onVideoClosed,
  }) {
    final videoId = video['videoId'] as String? ?? '';
    final title = video['title'] as String? ?? 'Untitled Video';
    final channelName = video['channelName'] as String? ?? 'Unknown Channel';
    final thumbnail = video['thumbnail'] as String? ?? getThumbnailUrl(videoId);
    final viewCount = video['viewCount'] as int?;

    return InkWell(
      onTap: onTap ?? () {
        playVideo(
          context,
          videoId: videoId,
          videoTitle: title,
          channelName: channelName,
          description: video['description'],
          relatedVideos: relatedVideos,
          onVideoClosed: onVideoClosed,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    thumbnail,
                    width: 120,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 68,
                        color: Colors.grey[300],
                        child: const Icon(Icons.play_circle_outline),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Video Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    channelName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (viewCount != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.remove_red_eye,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatNumber(viewCount),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.play_circle_filled,
              color: Color(0xFF6366F1),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}
