// Example Usage of VideoBackend in your app

import 'package:flutter/material.dart';
import 'package:eduai/models/video_backend.dart';

// EXAMPLE 1: Open a video player directly
void playVideoExample(BuildContext context) {
  VideoBackend.playVideo(
    context,
    videoId: 'dQw4w9WgXcQ',
    videoTitle: 'Introduction to Flutter',
    channelName: 'Flutter Channel',
    description: 'Learn the basics of Flutter development',
    relatedVideos: [
      {
        'videoId': 'abc123',
        'title': 'Advanced Flutter',
        'channelName': 'Flutter Channel',
        'thumbnail': 'https://img.youtube.com/vi/abc123/mqdefault.jpg',
      },
    ],
  );
}

// EXAMPLE 2: Build a video card in a list
Widget buildVideoListExample(BuildContext context, List<Map<String, dynamic>> videos) {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: videos.length,
    itemBuilder: (context, index) {
      return VideoBackend.buildVideoCard(
        context: context,
        video: videos[index],
        relatedVideos: videos,
      );
    },
  );
}

// EXAMPLE 3: Build compact video items (for smaller lists)
Widget buildCompactVideoListExample(BuildContext context, List<Map<String, dynamic>> videos) {
  return Column(
    children: videos.map((video) {
      return VideoBackend.buildCompactVideoItem(
        context: context,
        video: video,
        relatedVideos: videos,
      );
    }).toList(),
  );
}

// EXAMPLE 4: Extract video ID from YouTube URL
void extractVideoIdExample() {
  // From watch URL
  String? videoId1 = VideoBackend.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
  print('Video ID: $videoId1'); // Output: dQw4w9WgXcQ
  
  // From short URL
  String? videoId2 = VideoBackend.extractVideoId('https://youtu.be/dQw4w9WgXcQ');
  print('Video ID: $videoId2'); // Output: dQw4w9WgXcQ
  
  // From embed URL
  String? videoId3 = VideoBackend.extractVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ');
  print('Video ID: $videoId3'); // Output: dQw4w9WgXcQ
}

// EXAMPLE 5: Get thumbnail URL
void getThumbnailExample() {
  String thumbnail = VideoBackend.getThumbnailUrl('dQw4w9WgXcQ', quality: 'high');
  print('Thumbnail URL: $thumbnail');
  // Output: https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg
}

// EXAMPLE 6: Full implementation in a screen
class VideoListScreen extends StatelessWidget {
  const VideoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample video data (this would come from your backend/Firebase)
    final videos = [
      {
        'videoId': 'dQw4w9WgXcQ',
        'title': 'Introduction to Flutter Development',
        'channelName': 'Flutter Official',
        'description': 'Learn the basics of Flutter',
        'thumbnail': 'https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg',
        'viewCount': 1500000,
      },
      {
        'videoId': 'abc123def',
        'title': 'Advanced State Management in Flutter',
        'channelName': 'Tech Masters',
        'description': 'Deep dive into state management',
        'thumbnail': 'https://img.youtube.com/vi/abc123def/mqdefault.jpg',
        'viewCount': 750000,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Tutorials'),
        backgroundColor: const Color(0xFF6366F1),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return VideoBackend.buildVideoCard(
            context: context,
            video: videos[index],
            relatedVideos: videos,
          );
        },
      ),
    );
  }
}
