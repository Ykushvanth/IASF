import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eduai/models/cheat_sheet_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// CheatSheetScreen - Displays and generates cheat sheets for topics
class CheatSheetScreen extends StatefulWidget {
  final String courseName;
  final String topicName;
  final String difficulty;

  const CheatSheetScreen({
    super.key,
    required this.courseName,
    required this.topicName,
    required this.difficulty,
  });

  @override
  State<CheatSheetScreen> createState() => _CheatSheetScreenState();
}

class _CheatSheetScreenState extends State<CheatSheetScreen> {
  String? _cheatSheetMarkdown;
  bool _isLoading = false;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCheatSheet();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCheatSheet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check Firebase first
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cheatSheets')
            .doc('${widget.courseName}_${widget.topicName}');

        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          final data = docSnap.data()!;
          setState(() {
            _cheatSheetMarkdown = data['markdown'] as String?;
            _isLoading = false;
          });
          return;
        }
      }

      // Generate new cheat sheet
      final result = await CheatSheetBackend.generateCheatSheet(
        topicName: widget.topicName,
        courseName: widget.courseName,
        difficulty: widget.difficulty,
        userLevel: 'intermediate', // Can be made dynamic based on user profile
      );

      if (result['success'] == true) {
        setState(() {
          _cheatSheetMarkdown = result['cheatSheet'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to generate cheat sheet';
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

  Future<void> _regenerateCheatSheet() async {
    // Delete existing cheat sheet
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cheatSheets')
          .doc('${widget.courseName}_${widget.topicName}')
          .delete();
    }

    await _loadCheatSheet();
  }

  Future<void> _copyToClipboard() async {
    if (_cheatSheetMarkdown != null) {
      await Clipboard.setData(ClipboardData(text: _cheatSheetMarkdown!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cheat sheet copied to clipboard!'),
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
              'Generating cheat sheet...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
                onPressed: _loadCheatSheet,
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

    if (_cheatSheetMarkdown == null || _cheatSheetMarkdown!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No cheat sheet available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCheatSheet,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate Cheat Sheet'),
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
                onPressed: _regenerateCheatSheet,
                color: const Color(0xFF6366F1),
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Copy',
                onPressed: _copyToClipboard,
                color: const Color(0xFF10B981),
              ),
              _buildActionButton(
                icon: Icons.share,
                label: 'Share',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share feature coming soon!'),
                    ),
                  );
                },
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
        // Cheat sheet content
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: _buildMarkdownContent(_cheatSheetMarkdown!),
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

  Widget _buildMarkdownContent(String markdown) {
    // Parse and render markdown with custom styling
    // Since we don't have flutter_markdown, we'll create a simple parser
    return _parseMarkdown(markdown);
  }

  Widget _parseMarkdown(String markdown) {
    final lines = markdown.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Headers
      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: SelectableText(
              line.substring(2),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: SelectableText(
              line.substring(3),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: SelectableText(
              line.substring(4),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        );
      }
      // Bold text
      else if (line.contains('**') && line.startsWith('**') && line.endsWith('**')) {
        final text = line.replaceAll('**', '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        );
      }
      // Blockquotes (note boxes) - handle multi-line
      else if (line.startsWith('> ')) {
        final noteLines = <String>[];
        noteLines.add(line.substring(2));
        // Collect all blockquote lines
        int j = i + 1;
        while (j < lines.length && lines[j].trim().startsWith('> ')) {
          noteLines.add(lines[j].substring(2));
          j++;
        }
        i = j - 1; // Skip processed lines
        
        final noteContent = noteLines.join('\n');
        final isNote = noteContent.contains('📝 Note') || 
                      noteContent.contains('💡 Tip') || 
                      noteContent.contains('⚠️ Warning');
        
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isNote 
                  ? Colors.blue.withOpacity(0.08)
                  : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isNote
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: _buildRichSelectableText(noteContent),
          ),
        );
      }
      // Horizontal rules
      else if (line.startsWith('---') || line == '---') {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            height: 1,
            color: Colors.grey[300],
          ),
        );
      }
      // Tables
      else if (line.contains('|') && line.split('|').length >= 3) {
        final tableRows = <String>[];
        tableRows.add(line);
        // Collect all table rows until we hit a non-table line
        int j = i + 1;
        while (j < lines.length && 
               lines[j].trim().isNotEmpty && 
               lines[j].contains('|') && 
               lines[j].split('|').length >= 3) {
          tableRows.add(lines[j]);
          j++;
        }
        i = j - 1; // Skip processed rows
        
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: _buildTable(tableRows),
          ),
        );
      }
      // Language label before code block (e.g., **PYTHON**)
      else if (line.startsWith('**') && 
               line.endsWith('**') && 
               (line.contains('PYTHON') || 
                line.contains('JAVASCRIPT') || 
                line.contains('JAVA') || 
                line.contains('C++') ||
                line.contains('C#') ||
                line.contains('RUBY') ||
                line.contains('GO') ||
                line.contains('RUST') ||
                line.contains('SWIFT') ||
                line.contains('KOTLIN'))) {
        final language = line.replaceAll('**', '');
        // Check if next line is a code block
        if (i + 1 < lines.length && lines[i + 1].trim().startsWith('```')) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  language,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          );
        } else {
          // Just a bold text, render normally
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                line,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          );
        }
      }
      // Code blocks
      else if (line.startsWith('```')) {
        final codeLines = <String>[];
        final language = line.length > 3 ? line.substring(3).trim() : '';
        i++; // Skip the opening ```
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        
        final codeText = codeLines.join('\n');
        final isFormula = language.isEmpty || codeText.contains('=') && !codeText.contains('def');
        
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isFormula
                  ? Colors.grey[900]
                  : const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              codeText,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.grey[100],
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        );
      }
      // "Examples:" heading
      else if (line.trim() == '**Examples:**' || line.trim() == '**Some Examples:**') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: SelectableText(
              line.replaceAll('**', ''),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        );
      }
      // Bullet points
      else if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ')) {
        final bulletText = line.startsWith('• ') 
            ? line.substring(2) 
            : line.substring(2);
        
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: _buildRichSelectableText(bulletText),
                ),
              ],
            ),
          ),
        );
      }
      // Regular text
      else {
        // Handle inline bold, code, and formatting
        if (line.contains('**') || 
            line.contains('`') ||
            line.contains('📝') || 
            line.contains('💡') || 
            line.contains('⚠️')) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildRichSelectableText(line),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                line,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  height: 1.6,
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Build rich selectable text with formatting (bold, inline code, emoji prefixes)
  Widget _buildRichSelectableText(String text) {
    // Parser for **bold**, `inline code`, and emoji prefixes
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    bool inBold = false;
    bool inCode = false;
    
    for (int i = 0; i < text.length; i++) {
      // Check for **bold**
      if (i < text.length - 1 && text.substring(i, i + 2) == '**') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF1E293B),
              fontWeight: inBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: inCode ? 'monospace' : null,
              backgroundColor: inCode ? Colors.grey[200] : null,
            ),
          ));
          buffer.clear();
        }
        inBold = !inBold;
        i++; // Skip next *
      }
      // Check for `inline code`
      else if (text[i] == '`' && !inCode) {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF1E293B),
              fontWeight: inBold ? FontWeight.bold : FontWeight.normal,
            ),
          ));
          buffer.clear();
        }
        inCode = true;
      } else if (text[i] == '`' && inCode) {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: const Color(0xFF1E293B),
              backgroundColor: Colors.grey[200],
              fontWeight: inBold ? FontWeight.bold : FontWeight.normal,
            ),
          ));
          buffer.clear();
        }
        inCode = false;
      } else {
        buffer.write(text[i]);
      }
    }
    
    // Add remaining text
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(
        text: buffer.toString(),
        style: TextStyle(
          fontSize: 15,
          color: const Color(0xFF1E293B),
          fontWeight: inBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: inCode ? 'monospace' : null,
          backgroundColor: inCode ? Colors.grey[200] : null,
        ),
      ));
    }
    
    return SelectableText.rich(
      TextSpan(children: spans.isEmpty ? [TextSpan(text: text)] : spans),
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1E293B),
        height: 1.6,
      ),
    );
  }

  /// Build a table widget from markdown table rows
  Widget _buildTable(List<String> rows) {
    if (rows.isEmpty) return const SizedBox();
    
    // Parse table rows
    final tableData = rows.map((row) {
      final cells = row.split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList();
      return cells;
    }).toList();
    
    if (tableData.isEmpty) return const SizedBox();
    
    // Check if first row is a separator (contains dashes)
    final hasHeader = tableData.isNotEmpty && 
                      !tableData[0].any((cell) => cell.contains('---'));
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.grey[300]!, width: 1),
        children: tableData.asMap().entries.map((entry) {
          final index = entry.key;
          final cells = entry.value;
          
          // Skip separator rows
          if (cells.any((cell) => cell.contains('---'))) {
            return const TableRow(children: []);
          }
          
          final isHeader = hasHeader && index == 0;
          
          return TableRow(
            children: cells.map((cell) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelectableText(
                  cell,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              );
            }).toList(),
          );
        }).where((row) => row.children.isNotEmpty).toList(),
      ),
    );
  }
}

