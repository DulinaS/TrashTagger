// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trash_tagger/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  //final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _updateLastActive(result.user!.uid);
      return result;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document
      await _createUserDocument(result.user!, name);

      return result;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /* Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      
      // Create user document if new user
      await _createUserDocument(result.user!, result.user!.displayName ?? 'User');
      
      return result;
    } catch (e) {
      throw AuthException(e.toString());
    }
  } */

  Future<void> signOut() async {
    //await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> _createUserDocument(User user, String name) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      final userData = UserModel(
        id: user.uid,
        name: name,
        email: user.email!,
        photoURL: user.photoURL,
        totalPoints: 0,
        badges: [],
        level: 1,
        joinDate: DateTime.now(),
        lastActive: DateTime.now(),
        settings: UserSettings(
          notificationsEnabled: true,
          radius: 5.0,
          safetyWarningsEnabled: true,
        ),
        stats: UserStats(
          reportsSubmitted: 0,
          challengesCompleted: 0,
          weeklyStreak: 0,
          monthlyPoints: 0,
        ),
      );

      await _firestore.collection('users').doc(user.uid).set(userData.toMap());
    }
  }

  Future<void> _updateLastActive(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}
