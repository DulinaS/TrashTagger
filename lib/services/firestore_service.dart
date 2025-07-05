// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trash_tagger/models/trash_report_model.dart';
import 'package:trash_tagger/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User operations
  Future<UserModel?> getUser(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  // Report operations
  Future<String> createReport(TrashReportModel report) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('trashReports')
          .add(report.toMap());
      return docRef.id;
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  Stream<List<TrashReportModel>> getNearbyReports(
    GeoPoint center,
    double radiusKm,
  ) {
    // Using GeoFlutterFire for location-based queries
    // This is a simplified version - you'll need to implement proper geo queries
    return _firestore
        .collection('trashReports')
        .where('status', whereIn: ['verified', 'cleaning'])
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    TrashReportModel.fromMap({'id': doc.id, ...doc.data()}),
              )
              .toList(),
        );
  }

  Future<void> acceptChallenge(String reportId, String userId) async {
    try {
      await _firestore.collection('trashReports').doc(reportId).update({
        'acceptedBy': userId,
        'acceptedAt': FieldValue.serverTimestamp(),
        'status': 'cleaning',
      });
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  Future<void> submitProof(String reportId, String proofURL) async {
    try {
      await _firestore.collection('trashReports').doc(reportId).update({
        'proofURL': proofURL,
        'proofTimestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  // Voting system
  Future<void> voteOnReport(
    String reportId,
    String userId,
    bool isUpvote,
  ) async {
    try {
      DocumentReference reportRef = _firestore
          .collection('trashReports')
          .doc(reportId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(reportRef);

        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          ReportVotes votes = ReportVotes.fromMap(data['votes'] ?? {});

          if (!votes.voters.contains(userId)) {
            List<String> newVoters = [...votes.voters, userId];
            int newUpvotes = votes.upvotes + (isUpvote ? 1 : 0);
            int newDownvotes = votes.downvotes + (isUpvote ? 0 : 1);

            transaction.update(reportRef, {
              'votes': {
                'upvotes': newUpvotes,
                'downvotes': newDownvotes,
                'voters': newVoters,
              },
            });
          }
        }
      });
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  // Safety reporting
  Future<void> flagReport(
    String reportId,
    String reason,
    String reporterId,
  ) async {
    try {
      await _firestore.collection('trashReports').doc(reportId).update({
        'flagged': true,
        'flagReasons': FieldValue.arrayUnion([reason]),
      });

      // Also create a separate flag document for admin review
      await _firestore.collection('flags').add({
        'reportId': reportId,
        'reason': reason,
        'reporterId': reporterId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }

  // Leaderboard
  Future<List<UserModel>> getLeaderboard(String period) async {
    try {
      Query query = _firestore.collection('users');

      if (period == 'monthly') {
        query = query.orderBy('stats.monthlyPoints', descending: true);
      } else {
        query = query.orderBy('totalPoints', descending: true);
      }

      QuerySnapshot snapshot = await query.limit(50).get();

      return snapshot.docs
          .map(
            (doc) => UserModel.fromMap({
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            }),
          )
          .toList();
    } catch (e) {
      throw FirestoreException(e.toString());
    }
  }
}

class FirestoreException implements Exception {
  final String message;
  FirestoreException(this.message);
}
