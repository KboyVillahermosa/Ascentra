import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart' as app_user;
import 'database_helper.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<app_user.User?> signInWithGoogle() async {
    try {
      // Show detailed debug info
      print('Starting Google Sign-In process...');
      
      // Begin interactive sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Sign-in canceled by user');
        return null;
      }
      
      print('Google Sign-In successful for: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create credentials
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase
      print('Authenticating with Firebase...');
      final UserCredential authResult = await _auth.signInWithCredential(credential);
      final User? firebaseUser = authResult.user;
      
      if (firebaseUser == null) {
        print('Firebase authentication failed');
        return null;
      }
      
      print('Firebase authentication successful');
      
      // Create local user
      final appUser = app_user.User(
        username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Google User',
        email: firebaseUser.email!,
        photoUrl: firebaseUser.photoURL,
        authProvider: 'google',
      );
      
      // Save to database
      print('Saving user to local database...');
      await _databaseHelper.insertOrUpdateGoogleUser(appUser);
      
      // Get complete user with ID
      final savedUser = await _databaseHelper.getUserByEmail(appUser.email);
      return savedUser;
    } catch (e) {
      print('Error signing in with Google: $e');
      
      // More detailed error diagnostics
      if (e.toString().contains('ApiException: 10')) {
        print('Error 10 indicates a configuration issue. Check your SHA fingerprint in Firebase.');
      }
      
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}