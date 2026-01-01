# 🔧 New User Signup Fix - Firestore Rules Issue

## Problem Found
New user signup is failing because the Firestore security rules require authentication BEFORE allowing document creation. This creates a chicken-and-egg problem:
- During signup, Firebase Auth creates the user account first
- Then the code tries to create the Firestore user document
- But Firestore rules block this because the user isn't "fully authenticated" yet

## Solution Applied
Updated `firestore.rules` to allow users to create their own document during signup.

## Deploy the Fix

### Option 1: Firebase Console (EASIEST - DO THIS!)
1. Go to: https://console.firebase.google.com/
2. Select your project: **learnco-ffe77**
3. Click **Firestore Database** in the left sidebar
4. Click the **Rules** tab at the top
5. Copy and paste these rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can create their own document during signup
    match /users/{userId} {
      // Allow user creation during signup
      allow create: if request.auth != null && request.auth.uid == userId;
      // Allow users to read/write only their own document  
      allow read, update, delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

6. Click **Publish**
7. Wait for "Rules published successfully" message

### Option 2: Firebase CLI
If you have Firebase CLI installed:
```powershell
npm install -g firebase-tools  # If not installed
firebase login
firebase init firestore  # Select existing project: learnco-ffe77
firebase deploy --only firestore:rules
```

## Testing After Fix
1. Restart your Flutter app: `flutter run`
2. Try creating a new account with:
   - Email: test@example.com
   - Password: test123456 (at least 6 characters)
   - Full Name: Test User
   - Language: English
3. Check the console for these logs:
   - ✅ Firebase Auth user created
   - ✅ Firestore user document created successfully
   - ✅ Firestore document verified!

## Why This Happened
Your previous rules (`allow read, write: if request.auth != null;`) required authentication to write to Firestore. During signup:
1. Firebase Auth creates the user ✅
2. Code tries to write user document to Firestore
3. Firestore checks: "Is request.auth != null?" → YES
4. But the auth session might not be fully established yet → FAILS

The new rules specifically allow document creation if the userId matches the auth uid, which works during signup.

## Security Notes
✅ These rules are **SECURE**:
- Users can only create their OWN document (userId must match auth.uid)
- Users can only read/write their OWN data
- All other access is denied

This is production-ready security for user documents.

## If Still Not Working
Check Firebase Console → Authentication → Sign-in method:
- Make sure **Email/Password** is enabled
- Click "Email/Password" and toggle it ON if disabled
