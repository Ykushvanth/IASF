import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduai/screens/mindset_analysis.dart';

class AcademicContextScreen extends StatefulWidget {
  const AcademicContextScreen({super.key});

  @override
  State<AcademicContextScreen> createState() => _AcademicContextScreenState();
}

class _AcademicContextScreenState extends State<AcademicContextScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _educationLevel;
  String? _fieldStream;
  bool _isLoading = false;

  final Map<String, List<String>> _fieldOptions = {
    'School': ['Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12'],
    'College / University': [
      'CSE (Computer Science)',
      'ECE (Electronics)',
      'ME (Mechanical)',
      'CE (Civil)',
      'EEE (Electrical)',
      'IT (Information Technology)',
      'Other Engineering',
      'Medicine',
      'Arts',
      'Commerce',
      'Science',
    ],
    'Graduate': [
      'Master\'s Degree',
      'PhD',
      'Post Graduate Diploma',
    ],
    'Working professional': [
      'IT Industry',
      'Core Engineering',
      'Government Preparation',
      'Medical Field',
      'Finance',
      'Education',
      'Business',
      'Other',
    ],
  };

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        // Save academic context to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'educationLevel': _educationLevel,
          'fieldStream': _fieldStream,
          'academicContextCompleted': true,
          'academicContextUpdatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        // Navigate to mindset analysis
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MindsetAnalysisScreen(),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[700]!,
              Colors.purple[700]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Academic Context',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tell us about your education',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Education Level
                        Text(
                          'What is your current education level?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _fieldOptions.keys.map((level) {
                            final isSelected = _educationLevel == level;
                            return ChoiceChip(
                              label: Text(level),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _educationLevel = selected ? level : null;
                                  _fieldStream = null; // Reset field when level changes
                                });
                              },
                              selectedColor: Colors.purple[700],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        
                        if (_educationLevel != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Select your field/stream:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _fieldOptions[_educationLevel]!.map((field) {
                              final isSelected = _fieldStream == field;
                              return ChoiceChip(
                                label: Text(field),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _fieldStream = selected ? field : null;
                                  });
                                },
                                selectedColor: Colors.purple[700],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_educationLevel != null && _fieldStream != null && !_isLoading)
                                ? _handleSubmit
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
