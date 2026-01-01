import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpBackend {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign up a new user with email or phone
  static Future<Map<String, dynamic>> signUpUser({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required String preferredLanguage,
  }) async {
    try {
      // Determine if input is email or phone
      final isEmail = emailOrPhone.contains('@');
      
      UserCredential userCredential;
      
      if (isEmail) {
        // Email-based signup
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailOrPhone,
          password: password,
        );
      } else {
        // For phone authentication, we'll use email with a domain
        // In production, you'd implement proper phone auth with OTP
        // For now, creating a dummy email from phone number
        final dummyEmail = '$emailOrPhone@eduai.app';
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: dummyEmail,
          password: password,
        );
      }

      // Update display name
      await userCredential.user?.updateDisplayName(fullName);

      print('✅ Firebase Auth user created: ${userCredential.user!.uid}');
      print('📝 Creating Firestore user document...');

      try {
        // Save user data to Firestore with all required fields
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'fullName': fullName,
          'emailOrPhone': emailOrPhone,
          'isEmail': isEmail,
          'preferredLanguage': preferredLanguage,
          'createdAt': FieldValue.serverTimestamp(),
          'academicContextCompleted': false,
          'mindsetAnalysisCompleted': false,
          // Initialize empty data structures
          'academicContext': {},
          'mindsetAnswers': {},
          'courseAnswers': {},
          'selectedCourse': null,
          'roadmap': [],
          'teacherNote': '',
          'studyTips': [],
        });

        print('✅ Firestore user document created successfully!');
        print('📊 User ID: ${userCredential.user!.uid}');
        
        // Verify the document was created
        final verifyDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (!verifyDoc.exists) {
          throw Exception('Firestore document creation verification failed');
        }
        print('✅ Firestore document verified!');
      } catch (firestoreError) {
        print('❌ Firestore error: $firestoreError');
        // Delete the auth user if Firestore fails
        await userCredential.user?.delete();
        throw Exception('Failed to create user profile: $firestoreError');
      }

      return {
        'success': true,
        'message': 'Account created successfully',
        'userId': userCredential.user!.uid,
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password is too weak';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for this email/phone';
          break;
        case 'invalid-email':
          message = 'The email address is invalid';
          break;
        default:
          message = 'Signup failed: ${e.message}';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('❌ Unexpected signup error: $e');
      print('Error type: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'Signup error: $e',
      };
    }
  }

  /// Check if user is logged in
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }
}
