import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BackendTestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, String>> runAllTests() async {
    Map<String, String> results = {};

    // Test 1: Anonymous Authentication
    try {
      UserCredential? result = await FirebaseAuth.instance.signInAnonymously();
      if (result.user != null) {
        results['auth'] = '✅ Authentication working';
      } else {
        results['auth'] = '❌ Authentication failed';
      }
    } catch (e) {
      results['auth'] = '❌ Auth error: $e';
    }

    // Test 2: Database Read
    try {
      DocumentSnapshot config = await _firestore
          .collection('config')
          .doc('app')
          .get();
      if (config.exists) {
        results['database'] = '✅ Database initialized and readable';
      } else {
        results['database'] =
            '⚠️ Database not initialized - run initializeDatabase';
      }
    } catch (e) {
      results['database'] = '❌ Database error: $e';
    }

    // Test 3: Badges Collection
    try {
      QuerySnapshot badges = await _firestore
          .collection('badges')
          .limit(1)
          .get();
      if (badges.docs.isNotEmpty) {
        results['badges'] =
            '✅ Badges system ready (${badges.docs.length} found)';
      } else {
        results['badges'] = '⚠️ No badges found - run initializeDatabase';
      }
    } catch (e) {
      results['badges'] = '❌ Badges error: $e';
    }

    // Test 4: Security Rules
    try {
      await _firestore.collection('testWrite').add({
        'timestamp': FieldValue.serverTimestamp(),
        'uid': FirebaseAuth.instance.currentUser?.uid,
      });

      results['security'] = '⚠️ Security rules may be too permissive';
    } catch (e) {
      if (e.toString().contains('PERMISSION_DENIED')) {
        results['security'] = '✅ Security rules working correctly';
      } else {
        results['security'] = '❌ Security error: $e';
      }
    }

    return results;
  }
}
