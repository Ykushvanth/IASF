import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduai/models/gamification_backend.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _scoresLeaderboard = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    
    try {
      final allLeaderboard = await GamificationBackend.getLeaderboard(
        sortBy: 'tests', 
        limit: 100,
      );

      // Filter to show only students with scores > 0
      final scoresLeaderboard = allLeaderboard
          .where((user) => (user['averageTestScore'] as num? ?? 0) > 0)
          .toList();

      setState(() {
        _scoresLeaderboard = scoresLeaderboard;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading leaderboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLeaderboardList(_scoresLeaderboard),
    );
  }

  Widget _buildLeaderboardList(List<Map<String, dynamic>> leaderboard) {
    if (leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No leaderboard data yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete tests to appear on the leaderboard!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leaderboard.length,
      itemBuilder: (context, index) {
        final user = leaderboard[index];
        final isCurrentUser = user['userId'] == _currentUserId;
        final rank = index + 1;
        final isTopThree = rank <= 3;
        final averageScore = user['averageTestScore'] as num? ?? 0.0;

        return Card(
          margin: EdgeInsets.only(bottom: isTopThree ? 16 : 12),
          elevation: isTopThree ? 6 : (isCurrentUser ? 4 : 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isTopThree
                ? BorderSide(
                    color: rank == 1 
                        ? Colors.amber 
                        : rank == 2 
                            ? Colors.grey[400]! 
                            : Colors.brown[400]!,
                    width: 3,
                  )
                : isCurrentUser
                    ? const BorderSide(color: Color(0xFF6366F1), width: 2)
                    : BorderSide.none,
          ),
          child: Container(
            decoration: isTopThree
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: rank == 1
                          ? [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.05)]
                          : rank == 2
                              ? [Colors.grey[200]!, Colors.grey[100]!]
                              : [Colors.brown[100]!, Colors.brown[50]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: _buildRankBadge(rank, isTopThree),
              title: Text(
                user['name'],
                style: TextStyle(
                  fontWeight: isTopThree ? FontWeight.bold : (isCurrentUser ? FontWeight.bold : FontWeight.w600),
                  fontSize: isTopThree ? 18 : 16,
                  color: isCurrentUser && !isTopThree 
                      ? const Color(0xFF6366F1) 
                      : (isTopThree ? Colors.black87 : null),
                ),
              ),
              subtitle: Text(
                'Tests taken: ${user['totalTestsTaken'] ?? 0}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              trailing: _buildScoreValue(averageScore, rank),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank, bool isTopThree) {
    Color color;
    IconData? icon;
    double size = 48;

    if (rank == 1) {
      color = Colors.amber;
      icon = Icons.emoji_events;
      size = 56;
    } else if (rank == 2) {
      color = Colors.grey[700]!;
      icon = Icons.workspace_premium;
      size = 54;
    } else if (rank == 3) {
      color = Colors.brown[700]!;
      icon = Icons.military_tech;
      size = 52;
    } else {
      color = const Color(0xFF6366F1);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isTopThree
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.1),
                ],
              )
            : null,
        color: !isTopThree ? color.withOpacity(0.2) : null,
        borderRadius: BorderRadius.circular(isTopThree ? 16 : 12),
        border: isTopThree
            ? Border.all(
                color: color,
                width: 2.5,
              )
            : null,
        boxShadow: isTopThree
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: color, size: isTopThree ? 32 : 28)
            : Text(
                '$rank',
                style: TextStyle(
                  fontSize: isTopThree ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
      ),
    );
  }

  Widget _buildScoreValue(num averageScore, int rank) {
    final isTopThree = rank <= 3;
    final scoreColor = isTopThree
        ? (rank == 1 ? Colors.amber : rank == 2 ? Colors.grey[800]! : Colors.brown[800]!)
        : Colors.green;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${averageScore.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: isTopThree ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: scoreColor,
          ),
        ),
        Text(
          'Score',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: isTopThree ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
