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
      
      // Reload user to ensure auth token is fresh
      await userCredential.user?.reload();
      final currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        throw Exception('User authentication failed after creation');
      }
      
      // Get fresh ID token to ensure Firestore recognizes the auth
      await currentUser.getIdToken(true);
      
      print('📝 Creating Firestore user document...');
      print('🔐 Current auth user: ${currentUser.uid}');

      try {
        // Retry mechanism for Firestore write (in case of auth token propagation delay)
        int retries = 3;
        bool success = false;
        Exception? lastError;
        
        while (retries > 0 && !success) {
          try {
            // Save user data to Firestore with all required fields
            await _firestore.collection('users').doc(currentUser.uid).set({
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
            success = true;
            print('✅ Firestore user document created successfully!');
            print('📊 User ID: ${currentUser.uid}');
          } catch (e) {
            lastError = e is Exception ? e : Exception(e.toString());
            retries--;
            if (retries > 0) {
              print('⚠️ Firestore write failed, retrying... (${3 - retries}/3)');
              // Refresh token before retry
              await currentUser.getIdToken(true);
              await Future.delayed(const Duration(milliseconds: 500));
            } else {
              print('❌ Firestore error after all retries: $lastError');
            }
          }
        }
        
        if (!success) {
          // Delete the auth user if Firestore fails
          await userCredential.user?.delete();
          throw lastError ?? Exception('Failed to create Firestore document after retries');
        }
        
        // Verify the document was created
        final verifyDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (!verifyDoc.exists) {
          await userCredential.user?.delete();
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
        'userId': currentUser.uid,
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
