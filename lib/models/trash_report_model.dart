// lib/models/trash_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TrashReportModel {
  final String id;
  final String imageURL;
  final GeoPoint location;
  final String address;
  final String reporterId;
  final DateTime timestamp;
  final String status;
  final bool visionVerified;
  final List<String> visionLabels;
  final double visionConfidence;
  final bool moderatorReviewed;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final String? proofURL;
  final DateTime? proofTimestamp;
  final String trashType;
  final String severity;
  final List<String> safetyWarnings;
  final String estimatedEffort;
  final ReportVotes votes;
  final bool flagged;
  final List<String> flagReasons;
  final ProofVerification? proofVerification;

  TrashReportModel({
    required this.id,
    required this.imageURL,
    required this.location,
    required this.address,
    required this.reporterId,
    required this.timestamp,
    required this.status,
    required this.visionVerified,
    required this.visionLabels,
    required this.visionConfidence,
    required this.moderatorReviewed,
    this.acceptedBy,
    this.acceptedAt,
    this.proofURL,
    this.proofTimestamp,
    required this.trashType,
    required this.severity,
    required this.safetyWarnings,
    required this.estimatedEffort,
    required this.votes,
    required this.flagged,
    required this.flagReasons,
    this.proofVerification,
  });

  // lib/models/trash_report_model.dart - Fix the fromMap method
  factory TrashReportModel.fromMap(Map<String, dynamic> map) {
    return TrashReportModel(
      // Use the document ID passed in, NOT the id field from the document
      id: map['_documentId'] ?? map['id'] ?? '', // Use _documentId if available
      imageURL: map['imageURL'] ?? '',
      location: map['location'] ?? GeoPoint(0, 0),
      address: map['address'] ?? '',
      reporterId: map['reporterId'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      visionVerified: map['visionVerified'] ?? false,
      visionLabels: List<String>.from(map['visionLabels'] ?? []),
      visionConfidence: (map['visionConfidence'] ?? 0.0).toDouble(),
      moderatorReviewed: map['moderatorReviewed'] ?? false,
      acceptedBy: map['acceptedBy'],
      acceptedAt: map['acceptedAt'] != null
          ? (map['acceptedAt'] as Timestamp).toDate()
          : null,
      proofURL: map['proofURL'],
      proofTimestamp: map['proofTimestamp'] != null
          ? (map['proofTimestamp'] as Timestamp).toDate()
          : null,
      trashType: map['trashType'] ?? 'general',
      severity: map['severity'] ?? 'low',
      safetyWarnings: List<String>.from(map['safetyWarnings'] ?? []),
      estimatedEffort: map['estimatedEffort'] ?? '15min',
      votes: ReportVotes.fromMap(map['votes'] ?? {}),
      flagged: map['flagged'] ?? false,
      flagReasons: List<String>.from(map['flagReasons'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageURL': imageURL,
      'location': location,
      'address': address,
      'reporterId': reporterId,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'visionVerified': visionVerified,
      'visionLabels': visionLabels,
      'visionConfidence': visionConfidence,
      'moderatorReviewed': moderatorReviewed,
      'acceptedBy': acceptedBy,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'proofURL': proofURL,
      'proofTimestamp': proofTimestamp != null
          ? Timestamp.fromDate(proofTimestamp!)
          : null,
      'trashType': trashType,
      'severity': severity,
      'safetyWarnings': safetyWarnings,
      'estimatedEffort': estimatedEffort,
      'votes': votes.toMap(),
      'flagged': flagged,
      'flagReasons': flagReasons,
    };
  }
}

class ReportVotes {
  final int upvotes;
  final int downvotes;
  final List<String> voters;

  ReportVotes({
    required this.upvotes,
    required this.downvotes,
    required this.voters,
  });

  factory ReportVotes.fromMap(Map<String, dynamic> map) {
    return ReportVotes(
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      voters: List<String>.from(map['voters'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {'upvotes': upvotes, 'downvotes': downvotes, 'voters': voters};
  }
}

class ProofVerification {
  final bool verified;
  final int confidence;
  final List<String> reasons;
  final DateTime? analyzedAt;
  final bool? needsManualReview;

  ProofVerification({
    required this.verified,
    required this.confidence,
    required this.reasons,
    this.analyzedAt,
    this.needsManualReview,
  });

  factory ProofVerification.fromMap(Map<String, dynamic> map) {
    return ProofVerification(
      verified: map['verified'] ?? false,
      confidence: map['confidence'] ?? 0,
      reasons: List<String>.from(map['reasons'] ?? []),
      analyzedAt: map['analyzedAt'] != null
          ? (map['analyzedAt'] as Timestamp).toDate()
          : null,
      needsManualReview: map['needsManualReview'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'verified': verified,
      'confidence': confidence,
      'reasons': reasons,
      'analyzedAt': analyzedAt != null ? Timestamp.fromDate(analyzedAt!) : null,
      'needsManualReview': needsManualReview,
    };
  }
}
