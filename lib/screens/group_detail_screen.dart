import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduai/models/study_group_backend.dart';
import 'package:timeago/timeago.dart' as timeago;

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
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
          widget.groupName,
          style: const TextStyle(
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
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showGroupInfo,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'leave') {
                _leaveGroup();
              } else if (value == 'share') {
                _shareGroupCode();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share Group Code'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Leave Group', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
            Tab(icon: Icon(Icons.question_answer), text: 'Q&A'),
            Tab(icon: Icon(Icons.people), text: 'Members'),
            Tab(icon: Icon(Icons.local_fire_department), text: 'Sessions'),
            Tab(icon: Icon(Icons.folder), text: 'Resources'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildQATab(),
          _buildMembersTab(),
          _buildSessionsTab(),
          _buildResourcesTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        // Active session banner
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('study_groups')
              .doc(widget.groupId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final groupData = snapshot.data!.data() as Map<String, dynamic>?;
            final currentSession = groupData?['currentSession'] as Map?;

            if (currentSession == null || currentSession['isActive'] != true) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.green, Colors.teal]),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Study Session Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          currentSession['topic'] ?? 'Unknown Topic',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await StudyGroupBackend.joinStudySession(widget.groupId);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Joined study session!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Join'),
                  ),
                ],
              ),
            );
          },
        ),

        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_groups')
                .doc(widget.groupId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start the conversation!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final messageDoc = messages[index];
                  final messageData = messageDoc.data() as Map<String, dynamic>;
                  return _buildMessageBubble(messageDoc.id, messageData);
                },
              );
            },
          ),
        ),

        // Input area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1),
                child: IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = data['senderId'] == currentUserId;
    final isSystemMessage = data['isSystemMessage'] == true;
    final message = data['message'] ?? '';
    final senderName = data['senderName'] ?? 'Unknown';
    final timestamp = data['timestamp'] as Timestamp?;
    final timeText = timestamp != null
        ? timeago.format(timestamp.toDate())
        : 'Just now';

    if (isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isCurrentUser
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      )
                    : null,
                color: isCurrentUser ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
              child: Text(
                timeText,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('study_groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        final groupData = snapshot.data!.data() as Map<String, dynamic>?;
        final members = List<Map<String, dynamic>>.from(
          groupData?['members'] ?? [],
        );

        // Sort by points descending
        members.sort(
          (a, b) =>
              (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0),
        );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isAdmin = member['role'] == 'admin';
            final name = member['name'] ?? 'Unknown';
            final level = member['level'] ?? 'Not assessed';
            final points = member['points'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (index < 3)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: index == 0
                                ? Colors.amber
                                : index == 1
                                ? Colors.grey[400]
                                : Colors.brown[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.emoji_events,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getLevelColor(level).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getLevelColor(level),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          '$points pts',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionsTab() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        // Active Session Banner
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('study_groups')
              .doc(widget.groupId)
              .snapshots(),
          builder: (context, groupSnapshot) {
            if (!groupSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final groupData =
                groupSnapshot.data!.data() as Map<String, dynamic>?;
            final currentSessionId = groupData?['currentSessionId'] as String?;

            if (currentSessionId == null) {
              // No active session, show start button
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _startGroupStudySession(),
                      icon: const Icon(Icons.play_circle),
                      label: const Text('Start Study Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a study session to motivate your group! 📚',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            // Active session exists - show participants
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('study_groups')
                  .doc(widget.groupId)
                  .collection('activeSessions')
                  .doc(currentSessionId)
                  .snapshots(),
              builder: (context, sessionSnapshot) {
                if (!sessionSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final sessionData =
                    sessionSnapshot.data!.data() as Map<String, dynamic>?;
                final participants =
                    sessionData?['participants'] as List? ?? [];
                final startTime = sessionData?['startTime'] as Timestamp?;
                final startedBy = sessionData?['starterName'] ?? 'Unknown';

                // Calculate elapsed time
                final elapsed = startTime != null
                    ? DateTime.now().difference(startTime.toDate()).inMinutes
                    : 0;

                return Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Active Study Session',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Started by $startedBy • ${elapsed}m ago',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Participants Grid
                      Text(
                        '${participants.length} members studying together right now 💪',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...participants.map((p) {
                              final name = (p['name'] ?? '').toString();
                              final topic = (p['topic'] ?? 'General')
                                  .toString();
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 8,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        topic,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          if (user != null &&
                              !participants.any((p) => p['userId'] == user.uid))
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _joinGroupStudySession(currentSessionId),
                                icon: const Icon(Icons.add),
                                label: const Text('Join Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF10B981),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _leaveGroupStudySession(currentSessionId),
                                icon: const Icon(Icons.exit_to_app),
                                label: const Text('Leave Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.9),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _endGroupStudySession(
                              currentSessionId,
                              participants.length,
                              elapsed,
                            ),
                            icon: const Icon(Icons.stop_circle),
                            label: const Text('End'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.7),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        // Session History
        const Padding(
          padding: EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Session History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_groups')
                .doc(widget.groupId)
                .collection('sessionHistory')
                .orderBy('startTime', descending: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No sessions yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final session = doc.data() as Map<String, dynamic>;
                  final participants = session['participants'] as List? ?? [];
                  final duration = session['duration'] ?? 0;
                  final startTime = session['startTime'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF10B981),
                                      Color(0xFF059669),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.done_all,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Study Session Completed',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      startTime != null
                                          ? timeago.format(startTime.toDate())
                                          : 'Unknown time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.timer, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '$duration minutes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.people, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                '${participants.length} members',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResourcesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _shareResource,
            icon: const Icon(Icons.upload, color: Colors.white),
            label: const Text(
              'Share Resource',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_groups')
                .doc(widget.groupId)
                .collection('resources')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No resources yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final resourceDoc = snapshot.data!.docs[index];
                  final resource = resourceDoc.data() as Map<String, dynamic>;
                  return _buildResourceCard(resource);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    final title = resource['title'] ?? 'Untitled';
    final content = resource['content'] ?? '';
    final type = resource['type'] ?? 'note';
    final sharerName = resource['sharerName'] ?? 'Unknown';
    final timestamp = resource['timestamp'] as Timestamp?;
    final timeText = timestamp != null
        ? timeago.format(timestamp.toDate())
        : 'Unknown';

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'video':
        icon = Icons.play_circle;
        iconColor = Colors.red;
        break;
      case 'document':
        icon = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'tip':
        icon = Icons.lightbulb;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.note;
        iconColor = const Color(0xFF6366F1);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Shared by $sharerName • $timeText',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isLoading = true);

    final success = await StudyGroupBackend.sendMessage(
      groupId: widget.groupId,
      message: message,
    );

    setState(() => _isLoading = false);

    if (success) {
      _messageController.clear();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startGroupStudySession() async {
    final result = await StudyGroupBackend.startGroupStudySession(
      groupId: widget.groupId,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Study session started! Your groupmates can join now 🔥',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to start session'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _joinGroupStudySession(String sessionId) async {
    final result = await StudyGroupBackend.joinGroupStudySession(
      groupId: widget.groupId,
      sessionId: sessionId,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You joined the study session! Study together! 💪'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to join'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _leaveGroupStudySession(String sessionId) async {
    final result = await StudyGroupBackend.leaveGroupStudySession(
      groupId: widget.groupId,
      sessionId: sessionId,
    );

    if (mounted) {
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the study session'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _endGroupStudySession(
    String sessionId,
    int participantCount,
    int elapsedMinutes,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    // Check if user is session starter
    final sessionDoc = await FirebaseFirestore.instance
        .collection('study_groups')
        .doc(widget.groupId)
        .collection('activeSessions')
        .doc(sessionId)
        .get();

    final sessionData = sessionDoc.data() ?? {};
    if (sessionData['startedBy'] != user?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the session starter can end the session'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await StudyGroupBackend.endGroupStudySession(
      groupId: widget.groupId,
      sessionId: sessionId,
    );

    if (mounted) {
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Great session! $participantCount members studied for $elapsedMinutes minutes 🎉',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _shareResource() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String resourceType = 'note';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Share Resource'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: resourceType,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'note', child: Text('📝 Note')),
                    DropdownMenuItem(
                      value: 'video',
                      child: Text('🎥 Video Link'),
                    ),
                    DropdownMenuItem(value: 'tip', child: Text('💡 Study Tip')),
                    DropdownMenuItem(
                      value: 'document',
                      child: Text('📄 Document'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => resourceType = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: 'Content',
                    hintText: 'Add description or link...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }

                Navigator.pop(context);

                final success = await StudyGroupBackend.shareResource(
                  groupId: widget.groupId,
                  title: titleController.text,
                  content: contentController.text,
                  type: resourceType,
                );

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Resource shared!' : 'Failed to share resource',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Share', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo() async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('study_groups')
        .doc(widget.groupId)
        .get();

    final groupData = groupDoc.data();
    if (groupData == null || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Group Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Group Code', groupData['groupCode'] ?? 'N/A'),
            const SizedBox(height: 12),
            _buildInfoRow('Subject', groupData['subject'] ?? 'N/A'),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Members',
              '${groupData['memberCount']}/${groupData['maxMembers']}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Total Messages',
              '${groupData['totalMessages'] ?? 0}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Study Hours',
              '${(groupData['totalStudyHours'] ?? 0).toStringAsFixed(1)}',
            ),
            if (groupData['description']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(groupData['description'] ?? ''),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  void _shareGroupCode() async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('study_groups')
        .doc(widget.groupId)
        .get();

    final groupCode = groupDoc.data()?['groupCode'] ?? 'N/A';

    Clipboard.setData(ClipboardData(text: groupCode));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group code "$groupCode" copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await StudyGroupBackend.leaveGroup(
                widget.groupId,
              );

              if (!mounted) return;

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Left group successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to leave group'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'advanced':
        return Colors.green;
      case 'intermediate':
        return Colors.blue;
      case 'beginner':
        return Colors.orange;
      case 'foundation':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// Q&A Tab - Members ask questions, others answer
  Widget _buildQATab() {
    return Column(
      children: [
        // Add Question Button
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: () => _showAskQuestionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Ask Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Questions List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_groups')
                .doc(widget.groupId)
                .collection('questions')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final questionDoc = snapshot.data!.docs[index];
                  final questionData =
                      questionDoc.data() as Map<String, dynamic>;
                  return _buildQuestionCard(questionDoc.id, questionData);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(String questionId, Map<String, dynamic> data) {
    final levelColor = _getLevelColor(data['authorLevel'] ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data['authorLevel'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: levelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['authorName'] ?? 'Anonymous',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (data['isResolved'] == true)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['title'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    data['topic'] ?? 'General',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                  side: BorderSide.none,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${data['answerCount'] ?? 0} answers',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Asked ${timeago.format(DateTime.fromMillisecondsSinceEpoch((data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch))}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  void _showAskQuestionDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedTopic = 'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask a Question'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Question title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  hintText: 'Detailed description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTopic,
                items: ['General', 'Concept', 'Problem', 'Resource']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => selectedTopic = value ?? 'General',
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await StudyGroupBackend.postQuestion(
                groupId: widget.groupId,
                title: titleController.text,
                description: descriptionController.text,
                topic: selectedTopic,
              );
              if (mounted && result['success'] == true) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(result['message'])));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Post Question'),
          ),
        ],
      ),
    );
  }

  /// Progress Tab - Group members see each other's roadmap progress
}
