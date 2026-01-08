import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduai/models/study_group_backend.dart';
import 'package:eduai/screens/group_detail_screen.dart';

class StudyGroupsScreen extends StatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  State<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends State<StudyGroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        title: const Text(
          'Study Groups',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _showCreateGroupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: _showJoinGroupDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Groups'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'Search groups by name or subject...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMyGroupsTab(), _buildDiscoverTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Group',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to see your groups'));
    }

    // Get user's group IDs first
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final groupIds = (userData?['studyGroups'] as List<dynamic>?) ?? [];

        if (groupIds.isEmpty) {
          return _buildEmptyState(
            icon: Icons.groups,
            title: 'No Groups Yet',
            message: 'Create a new group or join an existing one!',
            actionLabel: 'Create Group',
            onAction: _showCreateGroupDialog,
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('study_groups')
              .where(FieldPath.documentId, whereIn: groupIds)
              .orderBy('lastActivityAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                icon: Icons.groups,
                title: 'No Groups Yet',
                message: 'Create a new group or join an existing one!',
                actionLabel: 'Create Group',
                onAction: _showCreateGroupDialog,
              );
            }

            final groups = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final groupName = (data['groupName'] ?? '')
                  .toString()
                  .toLowerCase();
              final subject = (data['subject'] ?? '').toString().toLowerCase();
              return _searchQuery.isEmpty ||
                  groupName.contains(_searchQuery) ||
                  subject.contains(_searchQuery);
            }).toList();

            if (groups.isEmpty) {
              return Center(
                child: Text(
                  'No groups match "$_searchQuery"',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final groupDoc = groups[index];
                final groupData = groupDoc.data() as Map<String, dynamic>;
                return _buildGroupCard(groupDoc.id, groupData);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('study_groups')
          .where('isActive', isEqualTo: true)
          .orderBy('memberCount', descending: false)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.explore,
            title: 'No Groups Available',
            message: 'Be the first to create a study group!',
            actionLabel: 'Create Group',
            onAction: _showCreateGroupDialog,
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        final groups = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final members = data['members'] as List? ?? [];
          final isAlreadyMember = members.any((m) => m['userId'] == user?.uid);

          if (isAlreadyMember) return false;

          final groupName = (data['groupName'] ?? '').toString().toLowerCase();
          final subject = (data['subject'] ?? '').toString().toLowerCase();
          return _searchQuery.isEmpty ||
              groupName.contains(_searchQuery) ||
              subject.contains(_searchQuery);
        }).toList();

        if (groups.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'You\'re already in all available groups!'
                  : 'No groups match "$_searchQuery"',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final groupDoc = groups[index];
            final groupData = groupDoc.data() as Map<String, dynamic>;
            return _buildDiscoverGroupCard(groupDoc.id, groupData);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(String groupId, Map<String, dynamic> groupData) {
    final memberCount = groupData['memberCount'] ?? 0;
    final maxMembers = groupData['maxMembers'] ?? 20;
    final subject = groupData['subject'] ?? '';
    final groupName = groupData['groupName'] ?? '';
    final totalMessages = groupData['totalMessages'] ?? 0;
    final currentSession = groupData['currentSession'] as Map?;
    final isSessionActive = currentSession?['isActive'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  GroupDetailScreen(groupId: groupId, groupName: groupName),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subject,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isSessionActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Live',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.people,
                    '$memberCount/$maxMembers',
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.message, '$totalMessages', Colors.green),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverGroupCard(
    String groupId,
    Map<String, dynamic> groupData,
  ) {
    final memberCount = groupData['memberCount'] ?? 0;
    final maxMembers = groupData['maxMembers'] ?? 20;
    final subject = groupData['subject'] ?? '';
    final groupName = groupData['groupName'] ?? '';
    final description = groupData['description'] ?? '';
    final isFull = memberCount >= maxMembers;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  Icons.people,
                  '$memberCount/$maxMembers',
                  isFull ? Colors.orange : Colors.blue,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: isFull
                      ? null
                      : () async {
                          final groupCode = groupData['groupCode'] ?? '';
                          final result = await StudyGroupBackend.joinGroup(
                            groupCode: groupCode,
                          );

                          if (!mounted) return;

                          if (result['success'] ?? false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['message'] ?? 'Joined successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            if (mounted) _tabController.animateTo(0);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['message'] ?? 'Failed to join',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: Icon(
                    isFull ? Icons.block : Icons.login,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    isFull ? 'Full' : 'Join',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFull
                        ? Colors.grey
                        : const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
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
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: const Color(0xFF6366F1)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final mainContext = context; // Capture parent context before dialog
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    int maxMembers = 20;

    showDialog(
      context: mainContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Create Study Group',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Group Name *',
                    hintText: 'e.g., JEE 2026 Warriors',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'e.g., Mathematics (JEE)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.book),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'What\'s this group about?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Max Members: $maxMembers',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: maxMembers.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: maxMembers.toString(),
                  onChanged: (value) {
                    setState(() => maxMembers = value.toInt());
                  },
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
                if (nameController.text.isEmpty ||
                    subjectController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill required fields'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final code = nameController.text.trim();
                final subject = subjectController.text.trim();
                final desc = descriptionController.text.trim();

                Navigator.pop(context);

                final result = await StudyGroupBackend.createGroup(
                  groupName: code,
                  subject: subject,
                  description: desc,
                  maxMembers: maxMembers,
                );

                if (!mounted) return;

                // Use mainContext (parent context) instead of dialog context
                Future.microtask(() {
                  if (!mounted) return;

                  if (result['success']) {
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Group created! Code: ${result['groupCode']}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Copy',
                          textColor: Colors.white,
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: result['groupCode'] ?? ''),
                            );
                          },
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message'] ?? 'Failed to create group',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupDialog() {
    final mainContext = context; // Capture parent context before dialog
    final codeController = TextEditingController();

    showDialog(
      context: mainContext,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Join Study Group',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-character group code to join',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Group Code',
                hintText: 'ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid 6-character code'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final code = codeController.text.trim();
              Navigator.pop(context);

              final result = await StudyGroupBackend.joinGroup(groupCode: code);

              if (!mounted) return;

              Future.microtask(() {
                if (!mounted) return;

                if (result['success'] ?? false) {
                  ScaffoldMessenger.of(mainContext).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Joined successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  if (mounted) _tabController.animateTo(0);
                } else {
                  ScaffoldMessenger.of(mainContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message'] ?? 'Failed to join group',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
