import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gamification system backend
/// Handles daily streaks, gold coins, rewards, and leaderboard
class GamificationBackend {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize gamification data for user
  static Future<void> initializeUserGamification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      
      if (!doc.exists || doc.data()?['gamification'] == null) {
        await userRef.set({
          'gamification': {
            'currentStreak': 0,
            'longestStreak': 0,
            'goldCoins': 0,
            'lastActivityDate': null,
            'totalPracticeQuestions': 0,
            'totalTestsTaken': 0,
            'totalTestScore': 0,
            'weeklyConsistency': 0, // Days active this week
            'totalRewards': 0,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error initializing gamification: $e');
    }
  }

  /// Update daily streak
  static Future<Map<String, dynamic>> updateDailyStreak() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      final data = doc.data() ?? {};
      final gamification = data['gamification'] ?? {};

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final lastActivityTimestamp = gamification['lastActivityDate'] as Timestamp?;
      final lastActivity = lastActivityTimestamp?.toDate();
      final lastActivityDay = lastActivity != null 
          ? DateTime(lastActivity.year, lastActivity.month, lastActivity.day)
          : null;

      int currentStreak = gamification['currentStreak'] ?? 0;
      int longestStreak = gamification['longestStreak'] ?? 0;
      int goldCoins = gamification['goldCoins'] ?? 0;
      int weeklyConsistency = gamification['weeklyConsistency'] ?? 0;
      bool streakBroken = false;
      bool earnedCoin = false;

      // Check if today is different from last activity
      if (lastActivityDay == null || today.isAfter(lastActivityDay)) {
        // Check if yesterday was the last activity (continuation)
        final yesterday = today.subtract(const Duration(days: 1));
        
        if (lastActivityDay == yesterday) {
          // Continue streak
          currentStreak++;
          weeklyConsistency++;
          
          // Check if weekly goal reached (7 days)
          if (weeklyConsistency >= 7) {
            goldCoins++;
            weeklyConsistency = 0; // Reset weekly counter
            earnedCoin = true;
          }
        } else if (lastActivityDay != today) {
          // Streak broken (missed a day)
          streakBroken = currentStreak > 0;
          currentStreak = 1; // Start new streak
          weeklyConsistency = 1;
        }

        // Update longest streak
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        // Update Firestore
        await userRef.update({
          'gamification.currentStreak': currentStreak,
          'gamification.longestStreak': longestStreak,
          'gamification.goldCoins': goldCoins,
          'gamification.lastActivityDate': Timestamp.fromDate(now),
          'gamification.weeklyConsistency': weeklyConsistency,
        });

        return {
          'success': true,
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'goldCoins': goldCoins,
          'earnedCoin': earnedCoin,
          'streakBroken': streakBroken,
          'weeklyConsistency': weeklyConsistency,
        };
      }

      // Same day, no update needed
      return {
        'success': true,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'goldCoins': goldCoins,
        'earnedCoin': false,
        'streakBroken': false,
        'weeklyConsistency': weeklyConsistency,
      };
    } catch (e) {
      print('Error updating streak: $e');
      return {'success': false, 'message': 'Failed to update streak: $e'};
    }
  }

  /// Get user's gamification stats
  static Future<Map<String, dynamic>?> getGamificationStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      return data['gamification'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting gamification stats: $e');
      return null;
    }
  }

  /// Update practice activity
  static Future<void> updatePracticeActivity(int questionsAnswered) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'gamification.totalPracticeQuestions': FieldValue.increment(questionsAnswered),
      });

      // Update daily streak
      await updateDailyStreak();
    } catch (e) {
      print('Error updating practice activity: $e');
    }
  }

  /// Update test activity
  static Future<void> updateTestActivity(int score, int totalQuestions) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'gamification.totalTestsTaken': FieldValue.increment(1),
        'gamification.totalTestScore': FieldValue.increment(score),
      });

      // Update daily streak
      await updateDailyStreak();
    } catch (e) {
      print('Error updating test activity: $e');
    }
  }

  /// Purchase reward with gold coins
  static Future<Map<String, dynamic>> purchaseReward({
    required String rewardId,
    required int cost,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      final data = doc.data() ?? {};
      final gamification = data['gamification'] ?? {};
      final currentCoins = gamification['goldCoins'] ?? 0;

      if (currentCoins < cost) {
        return {'success': false, 'message': 'Insufficient gold coins'};
      }

      // Deduct coins and add reward
      await userRef.update({
        'gamification.goldCoins': currentCoins - cost,
        'gamification.totalRewards': FieldValue.increment(1),
      });

      // Store purchase record
      await userRef.collection('purchases').add({
        'rewardId': rewardId,
        'cost': cost,
        'purchasedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Reward purchased successfully!',
        'remainingCoins': currentCoins - cost,
      };
    } catch (e) {
      print('Error purchasing reward: $e');
      return {'success': false, 'message': 'Failed to purchase reward: $e'};
    }
  }

  /// Get leaderboard data
  static Future<List<Map<String, dynamic>>> getLeaderboard({
    String sortBy = 'streak', // 'streak', 'coins', 'tests', 'practice'
    int limit = 50,
  }) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      
      List<Map<String, dynamic>> leaderboard = [];
      
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final gamification = data['gamification'] as Map<String, dynamic>?;
        
        if (gamification != null) {
          leaderboard.add({
            'userId': doc.id,
            'name': data['fullName'] ?? data['name'] ?? 'Unknown',
            'currentStreak': gamification['currentStreak'] ?? 0,
            'longestStreak': gamification['longestStreak'] ?? 0,
            'goldCoins': gamification['goldCoins'] ?? 0,
            'totalPracticeQuestions': gamification['totalPracticeQuestions'] ?? 0,
            'totalTestsTaken': gamification['totalTestsTaken'] ?? 0,
            'totalTestScore': gamification['totalTestScore'] ?? 0,
            'averageTestScore': (gamification['totalTestsTaken'] ?? 0) > 0
                ? (gamification['totalTestScore'] ?? 0) / (gamification['totalTestsTaken'] ?? 1)
                : 0,
          });
        }
      }

      // Sort based on criteria
      switch (sortBy) {
        case 'streak':
          leaderboard.sort((a, b) => (b['currentStreak'] as int).compareTo(a['currentStreak'] as int));
          break;
        case 'coins':
          leaderboard.sort((a, b) => (b['goldCoins'] as int).compareTo(a['goldCoins'] as int));
          break;
        case 'tests':
          leaderboard.sort((a, b) => (b['averageTestScore'] as num).compareTo(a['averageTestScore'] as num));
          break;
        case 'practice':
          leaderboard.sort((a, b) => (b['totalPracticeQuestions'] as int).compareTo(a['totalPracticeQuestions'] as int));
          break;
      }

      return leaderboard.take(limit).toList();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get available rewards
  static List<Map<String, dynamic>> getAvailableRewards() {
    return [
      {
        'id': 'hint_pack_5',
        'name': '5 Hints Pack',
        'description': 'Get 5 hints for difficult questions',
        'cost': 10,
        'icon': '💡',
        'category': 'Learning',
      },
      {
        'id': 'custom_avatar',
        'name': 'Custom Avatar Border',
        'description': 'Unlock a golden avatar border',
        'cost': 15,
        'icon': '👤',
        'category': 'Cosmetic',
      },
      {
        'id': 'roadmap_unlock',
        'name': 'Extra Roadmap Topic',
        'description': 'Unlock an additional topic in your roadmap',
        'cost': 20,
        'icon': '🗺️',
        'category': 'Learning',
      },
      {
        'id': 'priority_support',
        'name': '24h Priority Support',
        'description': 'Get priority responses to your questions',
        'cost': 25,
        'icon': '⚡',
        'category': 'Support',
      },
      {
        'id': 'certificate_basic',
        'name': 'Achievement Certificate',
        'description': 'Earn a certificate for your progress',
        'cost': 30,
        'icon': '🏆',
        'category': 'Achievement',
      },
      {
        'id': 'study_group_boost',
        'name': 'Study Group Boost',
        'description': 'Create unlimited study groups for a week',
        'cost': 35,
        'icon': '👥',
        'category': 'Social',
      },
      {
        'id': 'practice_unlimited',
        'name': 'Unlimited Practice',
        'description': 'Unlimited practice questions for 7 days',
        'cost': 40,
        'icon': '📝',
        'category': 'Learning',
      },
      {
        'id': 'ai_tutor_session',
        'name': 'AI Tutor Session',
        'description': 'One-on-one AI tutoring session',
        'cost': 50,
        'icon': '🤖',
        'category': 'Premium',
      },
    ];
  }
}
