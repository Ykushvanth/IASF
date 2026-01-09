import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// StudyGroupBackend - Manages study groups with real-time collaboration
///
/// FEATURES:
/// - Create and join study groups by subject
/// - Multi-level support (Advanced, Intermediate, Beginner in same group)
/// - Real-time chat with text and emoji reactions
/// - Shared progress tracking and group goals
/// - Study sessions with live participants
/// - Group challenges and leaderboards
/// - Resource sharing (notes, videos, tips)
/// - Peer mentoring system
class StudyGroupBackend {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new study group
  static Future<Map<String, dynamic>> createGroup({
    required String groupName,
    required String subject,
    required String description,
    int maxMembers = 20,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      // Get user data for creator info
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'Unknown';

      // Get user's level for this subject
      String? userLevel;
      try {
        final assessmentDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('assessments')
            .doc(subject)
            .get();
        if (assessmentDoc.exists) {
          userLevel = assessmentDoc.data()?['level'] as String?;
        }
      } catch (e) {
        print('No assessment found for subject: $e');
      }

      // Create unique group code
      final groupCode = _generateGroupCode();

      final groupData = {
        'groupName': groupName,
        'subject': subject,
        'description': description,
        'groupCode': groupCode,
        'creatorId': user.uid,
        'creatorName': userName,
        'maxMembers': maxMembers,
        'memberCount': 1,
        'members': [
          {
            'userId': user.uid,
            'name': userName,
            'level': userLevel ?? 'Not assessed',
            'role': 'admin',
            'joinedAt': Timestamp.now(), // Use Timestamp.now() for nested fields
            'points': 0,
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'groupGoals': {
          'weeklyStudyHours': 0,
          'completedTopics': 0,
          'averageProgress': 0,
        },
        'currentSession': null,
        'totalMessages': 0,
        'totalStudyHours': 0,
      };

      final docRef = await _firestore.collection('study_groups').add(groupData);

      // Add group to user's groups list
      await _firestore.collection('users').doc(user.uid).update({
        'studyGroups': FieldValue.arrayUnion([docRef.id]),
      });

      return {
        'success': true,
        'message': 'Group created successfully!',
        'groupId': docRef.id,
        'groupCode': groupCode,
      };
    } catch (e) {
      print('Error creating group: $e');
      return {'success': false, 'message': 'Failed to create group: $e'};
    }
  }

  /// Join an existing group using group code
  static Future<Map<String, dynamic>> joinGroup({
    required String groupCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      // Find group by code
      final querySnapshot = await _firestore
          .collection('study_groups')
          .where('groupCode', isEqualTo: groupCode.toUpperCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {'success': false, 'message': 'Group not found or inactive'};
      }

      final groupDoc = querySnapshot.docs.first;
      final groupData = groupDoc.data();
      final groupId = groupDoc.id;

      // Check if already a member
      final members = groupData['members'] as List;
      if (members.any((m) => m['userId'] == user.uid)) {
        return {'success': false, 'message': 'You are already a member'};
      }

      // Check if group is full
      if (members.length >= (groupData['maxMembers'] ?? 20)) {
        return {'success': false, 'message': 'Group is full'};
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'Unknown';

      // Get user's level for this subject
      String? userLevel;
      try {
        final subject = groupData['subject'];
        final assessmentDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('assessments')
            .doc(subject)
            .get();
        if (assessmentDoc.exists) {
          userLevel = assessmentDoc.data()?['level'] as String?;
        }
      } catch (e) {
        print('No assessment found: $e');
      }

      // Add member to group
      await _firestore.collection('study_groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([
          {
            'userId': user.uid,
            'name': userName,
            'level': userLevel ?? 'Not assessed',
            'role': 'member',
            'joinedAt': Timestamp.now(),
            'points': 0,
          },
        ]),
        'memberCount': FieldValue.increment(1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      // Add group to user's groups list
      await _firestore.collection('users').doc(user.uid).update({
        'studyGroups': FieldValue.arrayUnion([groupId]),
      });

      // Send welcome message
      await sendMessage(
        groupId: groupId,
        message: '$userName joined the group!',
        isSystemMessage: true,
      );

      return {
        'success': true,
        'message': 'Joined group successfully!',
        'groupId': groupId,
      };
    } catch (e) {
      print('Error joining group: $e');
      return {'success': false, 'message': 'Failed to join group: $e'};
    }
  }

  /// Send a message to the group chat
  static Future<bool> sendMessage({
    required String groupId,
    required String message,
    bool isSystemMessage = false,
    String? replyToMessageId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null && !isSystemMessage) return false;

      final userDoc = await _firestore.collection('users').doc(user?.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      final messageData = {
        'senderId': isSystemMessage ? 'system' : user!.uid,
        'senderName': isSystemMessage ? 'System' : userName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': isSystemMessage,
        'reactions': {},
        'replyTo': replyToMessageId,
        'isDeleted': false,
      };

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);

      // Update group's last activity and message count
      await _firestore.collection('study_groups').doc(groupId).update({
        'lastActivityAt': FieldValue.serverTimestamp(),
        'totalMessages': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Start a study session
  static Future<Map<String, dynamic>> startStudySession({
    required String groupId,
    required String topic,
    int durationMinutes = 60,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      final sessionData = {
        'topic': topic,
        'startedBy': user.uid,
        'starterName': userName,
        'startTime': Timestamp.now(), // Use Timestamp.now() for nested fields
        'plannedDuration': durationMinutes,
        'participants': [user.uid],
        'isActive': true,
      };

      // Update group with current session
      await _firestore.collection('study_groups').doc(groupId).update({
        'currentSession': sessionData,
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      // Send announcement
      await sendMessage(
        groupId: groupId,
        message:
            '$userName started a study session on "$topic" (${durationMinutes}min)',
        isSystemMessage: true,
      );

      return {'success': true, 'message': 'Study session started!'};
    } catch (e) {
      print('Error starting session: $e');
      return {'success': false, 'message': 'Failed to start session: $e'};
    }
  }

  /// Join an active study session
  static Future<bool> joinStudySession(String groupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('study_groups').doc(groupId).update({
        'currentSession.participants': FieldValue.arrayUnion([user.uid]),
      });

      return true;
    } catch (e) {
      print('Error joining session: $e');
      return false;
    }
  }

  /// End study session
  static Future<bool> endStudySession(String groupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final currentSession = groupDoc.data()?['currentSession'] as Map?;

      if (currentSession == null) return false;

      // Calculate session duration
      final startTime = currentSession['startTime'] as Timestamp?;
      final participants = currentSession['participants'] as List? ?? [];
      final duration = startTime != null
          ? DateTime.now().difference(startTime.toDate()).inMinutes
          : 0;

      // Save session to history
      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('sessions')
          .add({
            ...currentSession,
            'endTime': FieldValue.serverTimestamp(),
            'actualDuration': duration,
            'isActive': false,
          });

      // Award points to participants
      for (final participantId in participants) {
        await _updateMemberPoints(
          groupId,
          participantId as String,
          duration ~/ 10,
        ); // 1 point per 10 minutes
      }

      // Clear current session
      await _firestore.collection('study_groups').doc(groupId).update({
        'currentSession': null,
        'totalStudyHours': FieldValue.increment(duration / 60),
      });

      return true;
    } catch (e) {
      print('Error ending session: $e');
      return false;
    }
  }

  /// Update member points
  static Future<void> _updateMemberPoints(
    String groupId,
    String userId,
    int pointsToAdd,
  ) async {
    try {
      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final members = List<Map<String, dynamic>>.from(
        groupDoc.data()?['members'] as List? ?? [],
      );

      final memberIndex = members.indexWhere((m) => m['userId'] == userId);
      if (memberIndex != -1) {
        members[memberIndex]['points'] =
            (members[memberIndex]['points'] as int? ?? 0) + pointsToAdd;

        await _firestore.collection('study_groups').doc(groupId).update({
          'members': members,
        });
      }
    } catch (e) {
      print('Error updating points: $e');
    }
  }

  /// Leave a group
  static Future<bool> leaveGroup(String groupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final members = List<Map<String, dynamic>>.from(
        groupDoc.data()?['members'] as List? ?? [],
      );

      // Remove member
      members.removeWhere((m) => m['userId'] == user.uid);

      if (members.isEmpty) {
        // Delete group if no members left
        await _firestore.collection('study_groups').doc(groupId).update({
          'isActive': false,
        });
      } else {
        await _firestore.collection('study_groups').doc(groupId).update({
          'members': members,
          'memberCount': FieldValue.increment(-1),
        });
      }

      // Remove from user's groups list
      await _firestore.collection('users').doc(user.uid).update({
        'studyGroups': FieldValue.arrayRemove([groupId]),
      });

      return true;
    } catch (e) {
      print('Error leaving group: $e');
      return false;
    }
  }

  /// Generate unique group code
  static String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    var temp = random;

    for (var i = 0; i < 6; i++) {
      code += chars[temp % chars.length];
      temp = temp ~/ chars.length;
    }

    return code;
  }

  /// Get user's groups
  static Stream<QuerySnapshot> getUserGroups() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('study_groups')
        .where('members', arrayContains: {'userId': user.uid})
        .orderBy('lastActivityAt', descending: true)
        .snapshots();
  }

  /// Get group messages
  static Stream<QuerySnapshot> getGroupMessages(String groupId) {
    return _firestore
        .collection('study_groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Add reaction to message
  static Future<bool> addReaction({
    required String groupId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .update({
            'reactions.$emoji': FieldValue.arrayUnion([user.uid]),
          });

      return true;
    } catch (e) {
      print('Error adding reaction: $e');
      return false;
    }
  }

  /// Share a resource (note, video link, tip)
  static Future<bool> shareResource({
    required String groupId,
    required String title,
    required String content,
    required String type, // 'note', 'video', 'tip', 'document'
    String? url,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('resources')
          .add({
            'title': title,
            'content': content,
            'type': type,
            'url': url,
            'sharedBy': user.uid,
            'sharerName': userName,
            'timestamp': FieldValue.serverTimestamp(),
            'likes': [],
            'comments': [],
          });

      // Send notification message
      await sendMessage(
        groupId: groupId,
        message: '$userName shared a $type: "$title"',
        isSystemMessage: true,
      );

      return true;
    } catch (e) {
      print('Error sharing resource: $e');
      return false;
    }
  }

  /// Post a question to the group
  static Future<Map<String, dynamic>> postQuestion({
    required String groupId,
    required String title,
    required String description,
    required String topic,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'Unknown';

      // Get user level
      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final groupData = groupDoc.data() ?? {};
      final members = groupData['members'] as List? ?? [];
      final userMember = members.firstWhere(
        (m) => m['userId'] == user.uid,
        orElse: () => {'level': 'Not assessed'},
      );
      final userLevel = userMember['level'] ?? 'Not assessed';

      final questionRef = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('questions')
          .add({
            'title': title,
            'description': description,
            'topic': topic,
            'authorId': user.uid,
            'authorName': userName,
            'authorLevel': userLevel,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'answerCount': 0,
            'isResolved': false,
            'votes': 0,
          });

      // Update group stats
      await _firestore.collection('study_groups').doc(groupId).update({
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Question posted successfully!',
        'questionId': questionRef.id,
      };
    } catch (e) {
      print('Error posting question: $e');
      return {'success': false, 'message': 'Failed to post question: $e'};
    }
  }

  /// Post an answer to a question
  static Future<Map<String, dynamic>> postAnswer({
    required String groupId,
    required String questionId,
    required String answerText,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'Unknown';

      // Get user level
      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final groupData = groupDoc.data() ?? {};
      final members = groupData['members'] as List? ?? [];
      final userMember = members.firstWhere(
        (m) => m['userId'] == user.uid,
        orElse: () => {'level': 'Not assessed'},
      );
      final userLevel = userMember['level'] ?? 'Not assessed';

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('questions')
          .doc(questionId)
          .collection('answers')
          .add({
            'text': answerText,
            'authorId': user.uid,
            'authorName': userName,
            'authorLevel': userLevel,
            'levelRank': _getLevelRank(userLevel),
            'createdAt': FieldValue.serverTimestamp(),
            'votes': 0,
            'isAccepted': false,
          });

      // Increment answer count
      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('questions')
          .doc(questionId)
          .update({
            'answerCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return {'success': true, 'message': 'Answer posted successfully!'};
    } catch (e) {
      print('Error posting answer: $e');
      return {'success': false, 'message': 'Failed to post answer: $e'};
    }
  }

  /// Vote on an answer (helpful/not helpful)
  static Future<bool> voteOnAnswer({
    required String groupId,
    required String questionId,
    required String answerId,
    required bool helpful,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final votePath = helpful ? 'helpfulVotes' : 'unhelpfulVotes';

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('questions')
          .doc(questionId)
          .collection('answers')
          .doc(answerId)
          .update({
            'votes': FieldValue.increment(helpful ? 1 : -1),
            votePath: FieldValue.arrayUnion([user.uid]),
          });

      return true;
    } catch (e) {
      print('Error voting on answer: $e');
      return false;
    }
  }

  /// Update user's shared roadmap progress in group
  static Future<bool> updateRoadmapProgress({
    required String groupId,
    required int weekNumber,
    required List<String> completedTopics,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final progressDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('memberProgress')
          .doc(user.uid)
          .get();

      if (!progressDoc.exists) {
        await _firestore
            .collection('study_groups')
            .doc(groupId)
            .collection('memberProgress')
            .doc(user.uid)
            .set({
              'userId': user.uid,
              'currentWeek': weekNumber,
              'completedWeeks': [weekNumber],
              'topicsByWeek': {weekNumber.toString(): completedTopics},
              'lastUpdated': FieldValue.serverTimestamp(),
              'totalTopicsCompleted': completedTopics.length,
            });
      } else {
        final data = progressDoc.data() ?? {};
        final completedWeeks = List<int>.from(data['completedWeeks'] ?? []);
        if (!completedWeeks.contains(weekNumber)) {
          completedWeeks.add(weekNumber);
        }

        final topicsByWeek = Map<String, dynamic>.from(
          data['topicsByWeek'] ?? {},
        );
        topicsByWeek[weekNumber.toString()] = completedTopics;

        await progressDoc.reference.update({
          'currentWeek': weekNumber,
          'completedWeeks': completedWeeks,
          'topicsByWeek': topicsByWeek,
          'lastUpdated': FieldValue.serverTimestamp(),
          'totalTopicsCompleted': FieldValue.increment(completedTopics.length),
        });
      }

      return true;
    } catch (e) {
      print('Error updating roadmap progress: $e');
      return false;
    }
  }

  /// Create a group challenge
  static Future<Map<String, dynamic>> createGroupChallenge({
    required String groupId,
    required String title,
    required String description,
    required List<String> targetTopics,
    required DateTime dueDate,
    int rewardPoints = 50,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      // Check if user is group admin
      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final groupData = groupDoc.data() ?? {};
      if (groupData['creatorId'] != user.uid) {
        return {
          'success': false,
          'message': 'Only group admin can create challenges',
        };
      }

      final challengeRef = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('challenges')
          .add({
            'title': title,
            'description': description,
            'targetTopics': targetTopics,
            'dueDate': Timestamp.fromDate(dueDate),
            'rewardPoints': rewardPoints,
            'createdAt': FieldValue.serverTimestamp(),
            'completedBy': [],
            'isActive': true,
          });

      return {
        'success': true,
        'message': 'Challenge created!',
        'challengeId': challengeRef.id,
      };
    } catch (e) {
      print('Error creating challenge: $e');
      return {'success': false, 'message': 'Failed to create challenge: $e'};
    }
  }

  /// Complete a group challenge
  static Future<bool> completeChallenge({
    required String groupId,
    required String challengeId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .update({
            'completedBy': FieldValue.arrayUnion([user.uid]),
          });

      // Award points
      final challengeDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId)
          .get();
      final rewardPoints = challengeDoc.data()?['rewardPoints'] ?? 0;

      // Update member points in group
      final groupDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .get();
      final members = groupDoc.data()?['members'] as List? ?? [];
      final memberIndex = members.indexWhere((m) => m['userId'] == user.uid);
      if (memberIndex >= 0) {
        members[memberIndex]['points'] =
            (members[memberIndex]['points'] ?? 0) + rewardPoints;
        await _firestore.collection('study_groups').doc(groupId).update({
          'members': members,
        });
      }

      return true;
    } catch (e) {
      print('Error completing challenge: $e');
      return false;
    }
  }

  /// Start a group study session (motivational group study)
  static Future<Map<String, dynamic>> startGroupStudySession({
    required String groupId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      // Get user's current roadmap topic
      String? currentTopic = 'General Study';
      try {
        final userRoadmap = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('roadmap')
            .orderBy('weekNumber')
            .limit(1)
            .get();
        if (userRoadmap.docs.isNotEmpty) {
          final roadmapData = userRoadmap.docs.first.data();
          final weekTopics = roadmapData['topics'] as List? ?? [];
          if (weekTopics.isNotEmpty) {
            currentTopic = weekTopics.first.toString();
          }
        }
      } catch (e) {
        print('Could not fetch user roadmap: $e');
      }

      final sessionData = {
        'startedBy': user.uid,
        'starterName': userName,
        'startTime': Timestamp.now(),
        'participants': [
          {
            'userId': user.uid,
            'name': userName,
            'topic': currentTopic,
            'joinedAt': Timestamp.now(), // Use Timestamp.now() for nested fields in arrays
          },
        ],
        'isActive': true,
        'participantCount': 1,
      };

      // Create session in group
      final sessionRef = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('activeSessions')
          .add(sessionData);

      // Update group with active session reference
      await _firestore.collection('study_groups').doc(groupId).update({
        'currentSessionId': sessionRef.id,
        'lastActivityAt': FieldValue.serverTimestamp(),
      });

      // Send announcement
      await sendMessage(
        groupId: groupId,
        message: '$userName started a group study session! 📚 Join now!',
        isSystemMessage: true,
      );

      return {
        'success': true,
        'message': 'Study session started!',
        'sessionId': sessionRef.id,
      };
    } catch (e) {
      print('Error starting session: $e');
      return {'success': false, 'message': 'Failed to start session: $e'};
    }
  }

  /// Join active group study session
  static Future<Map<String, dynamic>> joinGroupStudySession({
    required String groupId,
    required String sessionId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      // Get user's current roadmap topic
      String? currentTopic = 'General Study';
      try {
        final userRoadmap = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('roadmap')
            .orderBy('weekNumber')
            .limit(1)
            .get();
        if (userRoadmap.docs.isNotEmpty) {
          final roadmapData = userRoadmap.docs.first.data();
          final weekTopics = roadmapData['topics'] as List? ?? [];
          if (weekTopics.isNotEmpty) {
            currentTopic = weekTopics.first.toString();
          }
        }
      } catch (e) {
        print('Could not fetch user roadmap: $e');
      }

      // Add user to session participants
      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('activeSessions')
          .doc(sessionId)
          .update({
            'participants': FieldValue.arrayUnion([
              {
                'userId': user.uid,
                'name': userName,
                'topic': currentTopic,
                'joinedAt': Timestamp.now(), // Use Timestamp.now() for nested fields in arrays
              },
            ]),
            'participantCount': FieldValue.increment(1),
          });

      // Send message
      await sendMessage(
        groupId: groupId,
        message: '$userName joined the study session! 🎉',
        isSystemMessage: true,
      );

      return {'success': true, 'message': 'Joined study session!'};
    } catch (e) {
      print('Error joining session: $e');
      return {'success': false, 'message': 'Failed to join: $e'};
    }
  }

  /// Leave active study session
  static Future<bool> leaveGroupStudySession({
    required String groupId,
    required String sessionId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      // Get current participants
      final sessionSnapshot = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('activeSessions')
          .doc(sessionId)
          .get();

      final participants =
          sessionSnapshot.data()?['participants'] as List? ?? [];
      final updatedParticipants = participants
          .where((p) => p['userId'] != user.uid)
          .toList();

      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('activeSessions')
          .doc(sessionId)
          .update({
            'participants': updatedParticipants,
            'participantCount': updatedParticipants.length,
          });

      // Send message
      await sendMessage(
        groupId: groupId,
        message: '$userName left the study session.',
        isSystemMessage: true,
      );

      return true;
    } catch (e) {
      print('Error leaving session: $e');
      return false;
    }
  }

  /// End group study session and award points
  static Future<bool> endGroupStudySession({
    required String groupId,
    required String sessionId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final sessionDoc = await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('activeSessions')
          .doc(sessionId)
          .get();

      final sessionData = sessionDoc.data() ?? {};
      final startTime = sessionData['startTime'] as Timestamp?;
      final participants = sessionData['participants'] as List? ?? [];

      // Calculate duration
      final duration = startTime != null
          ? DateTime.now().difference(startTime.toDate()).inMinutes
          : 0;

      // Save to history
      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('sessionHistory')
          .add({
            ...sessionData,
            'endTime': FieldValue.serverTimestamp(),
            'duration': duration,
            'isActive': false,
          });

      // Award points to participants
      final pointsPerParticipant =
          (duration ~/ 10) * 5; // 5 points per 10 minutes
      for (final participant in participants) {
        final participantId = participant['userId'];
        await _updateMemberPoints(groupId, participantId, pointsPerParticipant);
      }

      // Mark session as inactive
      await _firestore
          .collection('study_groups')
          .doc(groupId)
          .collection('activeSessions')
          .doc(sessionId)
          .update({'isActive': false, 'endTime': FieldValue.serverTimestamp()});

      // Clear current session from group
      await _firestore.collection('study_groups').doc(groupId).update({
        'currentSessionId': null,
      });

      // Send completion message
      await sendMessage(
        groupId: groupId,
        message:
            'Study session ended! 🎊 ${participants.length} members studied together for $duration minutes. Great work! 💪',
        isSystemMessage: true,
      );

      return true;
    } catch (e) {
      print('Error ending session: $e');
      return false;
    }
  }

  /// Helper: Get level rank for sorting (Advanced=3, Intermediate=2, Beginner=1)
  static int _getLevelRank(String level) {
    switch (level.toLowerCase()) {
      case 'advanced':
        return 3;
      case 'intermediate':
        return 2;
      case 'beginner':
        return 1;
      default:
        return 0;
    }
  }
}
