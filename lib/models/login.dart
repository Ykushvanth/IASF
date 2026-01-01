import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginBackend {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Login user with email or phone
  static Future<Map<String, dynamic>> loginUser({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      // Determine if input is email or phone
      final isEmail = emailOrPhone.contains('@');
      
      String loginEmail = emailOrPhone;
      if (!isEmail) {
        // For phone, use the dummy email format
        loginEmail = '$emailOrPhone@eduai.app';
      }

      // Sign in with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // User document doesn't exist - sign out and return error
        await _auth.signOut();
        return {
          'success': false,
          'message': 'User data not found. Please sign up again.',
        };
      }

      final userData = userDoc.data() ?? {};
      print('🔐 Login successful for user: ${userData['fullName']}');
      print('📊 Academic context completed: ${userData['academicContextCompleted']}');
      print('🧠 Mindset analysis completed: ${userData['mindsetAnalysisCompleted']}');

      return {
        'success': true,
        'message': 'Login successful',
        'userId': userCredential.user!.uid,
        'userData': userData,
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email/phone';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Check if user is logged in
  static User? getCurrentUser() {
    return _auth.currentUser;
  }
}
