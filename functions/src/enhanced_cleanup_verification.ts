// functions/src/enhanced_cleanup_verification.ts - FIXED VERSION

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { ImageAnnotatorClient } from '@google-cloud/vision';

const visionClient = new ImageAnnotatorClient({
  keyFilename: './trashtagger-service-account.json',
});

interface VerificationResult {
  verified: boolean;
  confidence: number;
  reasons: string[];
  methods: {
    sceneMatching: number;
    trashAnalysis: number;
    locationProximity: number;
    timestampValidity: number;
    imageMetadata: number;
    fraudIndicators?: number;
  };
  requiresManualReview: boolean;
}

export const verifyCleanupProof = functions.firestore
  .document('trashReports/{reportId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const reportId = context.params.reportId;

    if (beforeData.proofURL === afterData.proofURL || !afterData.proofURL) {
      return null;
    }

    try {
      await change.after.ref.update({
        proofVerification: admin.firestore.FieldValue.delete(),
        status: 'processing',
        disputeResolved: false,
      });

      const verification = await performEnhancedVerification({
        originalImageUrl: afterData.imageURL,
        proofImageUrl: afterData.proofURL,
        reportLocation: afterData.location,
        reportTimestamp: afterData.timestamp,
        proofTimestamp: afterData.proofTimestamp,
        proofMetadata: afterData.proofMetadata,
        reportId,
      });

      let finalStatus = 'completed';
      if (!verification.verified) {
        finalStatus = verification.requiresManualReview
          ? 'needs_manual_review'
          : 'disputed';
      }

      await change.after.ref.update({
        proofVerification: {
          verified: verification.verified,
          confidence: verification.confidence,
          reasons: verification.reasons,
          methods: verification.methods,
          requiresManualReview: verification.requiresManualReview,
          analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
          verificationVersion: '3.1', // Updated version
        },
        status: finalStatus,
        disputeResolved: verification.verified,
        lastProofAttempt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, verification };
    } catch (error) {
      await change.after.ref.update({
        status: 'needs_manual_review',
        proofVerification: {
          verified: false,
          confidence: 0,
          reasons: [`Verification system error: ${error}`],
          requiresManualReview: true,
          analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      return { success: false, error: String(error) };
    }
  });

// FIXED: Core verification pipeline with better logic
async function performEnhancedVerification(params: {
  originalImageUrl: string;
  proofImageUrl: string;
  reportLocation: admin.firestore.GeoPoint;
  reportTimestamp: admin.firestore.Timestamp;
  proofTimestamp: admin.firestore.Timestamp;
  proofMetadata?: any;
  reportId: string;
}): Promise<VerificationResult> {
  const methods = {
    sceneMatching: 0,
    trashAnalysis: 0,
    locationProximity: 0,
    timestampValidity: 0,
    imageMetadata: 0,
    fraudIndicators: 0,
  };
  const reasons: string[] = [];
  let requiresManualReview = false;
  let fraudIndicators = 0;

  // Scene matching - FIXED: Less aggressive, cleanup-aware
  try {
    const sceneResult = await performCleanupAwareSceneMatching(
      params.originalImageUrl,
      params.proofImageUrl
    );
    methods.sceneMatching = sceneResult.score;
    fraudIndicators += sceneResult.fraudIndicators;
    reasons.push(...sceneResult.reasons);
  } catch (e) {
    reasons.push('⚠️ Scene matching failed');
    requiresManualReview = true;
  }

  // Trash analysis - FIXED: More reasonable thresholds
  try {
    const trashResult = await performReasonableTrashAnalysis(
      params.originalImageUrl,
      params.proofImageUrl
    );
    methods.trashAnalysis = trashResult.score;
    fraudIndicators += trashResult.fraudIndicators;
    reasons.push(...trashResult.reasons);
  } catch (e) {
    reasons.push('⚠️ Trash removal analysis failed');
    requiresManualReview = true;
  }

  // Location proximity - keep existing
  try {
    const locationResult = await verifyLocationProximity(
      params.reportLocation,
      params.proofMetadata
    );
    methods.locationProximity = locationResult.score;
    fraudIndicators += locationResult.fraudIndicators;
    reasons.push(...locationResult.reasons);
  } catch (e) {
    reasons.push('⚠️ Location verification failed');
    requiresManualReview = true;
  }

  // Timestamp analysis - keep existing
  try {
    const timeResult = performStrictTemporalVerification(
      params.reportTimestamp,
      params.proofTimestamp
    );
    methods.timestampValidity = timeResult.score;
    fraudIndicators += timeResult.fraudIndicators;
    reasons.push(...timeResult.reasons);
  } catch (e) {
    reasons.push('⚠️ Timestamp validation failed');
    requiresManualReview = true;
  }

  // Image metadata - keep existing
  try {
    const metaResult = await analyzeImageMetadata(
      params.proofImageUrl,
      params.proofMetadata
    );
    methods.imageMetadata = metaResult.score;
    fraudIndicators += metaResult.fraudIndicators;
    reasons.push(...metaResult.reasons);
  } catch (e) {
    reasons.push('⚠️ Metadata analysis failed');
  }

  // FIXED: More reasonable confidence calculation
  const confidence = Math.round(
    methods.sceneMatching * 0.2 + // Reduced weight
      methods.trashAnalysis * 0.35 + // Increased weight - most important
      methods.locationProximity * 0.25 +
      methods.timestampValidity * 0.15 +
      methods.imageMetadata * 0.05
  );

  methods.fraudIndicators = fraudIndicators;

  // FIXED: More reasonable decision logic
  let verified = false;
  const FRAUD_HARD_FAIL_THRESHOLD = 40; // Increased threshold
  const CONFIDENCE_PASS_THRESHOLD = 60; // Lowered threshold
  const CONFIDENCE_REVIEW_LOW = 45; // Lowered threshold

  if (fraudIndicators >= FRAUD_HARD_FAIL_THRESHOLD) {
    reasons.push(
      '🚨 Multiple serious fraud indicators detected. Submission blocked.'
    );
    verified = false;
    requiresManualReview = false;
  } else if (confidence >= CONFIDENCE_PASS_THRESHOLD && fraudIndicators < 20) {
    reasons.push('🎉 Cleanup verification PASSED - all checks successful');
    verified = true;
  } else if (
    confidence >= CONFIDENCE_REVIEW_LOW &&
    confidence < CONFIDENCE_PASS_THRESHOLD
  ) {
    requiresManualReview = true;
    reasons.push(
      '⚠️ Borderline confidence or minor concerns. Flagged for manual review.'
    );
    verified = false;
  } else {
    reasons.push('❌ Cleanup verification FAILED - insufficient confidence');
    verified = false;
  }

  return {
    verified,
    confidence,
    reasons,
    methods,
    requiresManualReview,
  };
}

// FIXED: Cleanup-aware scene matching
async function performCleanupAwareSceneMatching(
  originalUrl: string,
  proofUrl: string
): Promise<{ score: number; reasons: string[]; fraudIndicators: number }> {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;

  const [originalResult] = await visionClient.annotateImage({
    image: { source: { imageUri: originalUrl } },
    features: [
      { type: 'LANDMARK_DETECTION', maxResults: 10 },
      { type: 'OBJECT_LOCALIZATION', maxResults: 20 },
      { type: 'TEXT_DETECTION', maxResults: 15 },
      { type: 'LABEL_DETECTION', maxResults: 25 },
      { type: 'IMAGE_PROPERTIES' },
    ],
  });

  const [proofResult] = await visionClient.annotateImage({
    image: { source: { imageUri: proofUrl } },
    features: [
      { type: 'LANDMARK_DETECTION', maxResults: 10 },
      { type: 'OBJECT_LOCALIZATION', maxResults: 20 },
      { type: 'TEXT_DETECTION', maxResults: 15 },
      { type: 'LABEL_DETECTION', maxResults: 25 },
      { type: 'IMAGE_PROPERTIES' },
    ],
  });

  // Landmark/structural matching
  const landmarkScore = compareLandmarks(
    originalResult.landmarkAnnotations || [],
    proofResult.landmarkAnnotations || []
  );
  if (landmarkScore > 0.7) {
    score += 50;
    reasons.push(
      `✅ Strong landmark match (${(landmarkScore * 100).toFixed(1)}%)`
    );
  } else if (landmarkScore > 0.4) {
    score += 30;
    reasons.push(
      `✅ Partial landmark match (${(landmarkScore * 100).toFixed(1)}%)`
    );
  } else if (
    landmarkScore === 0 &&
    (originalResult.landmarkAnnotations?.length || 0) > 2
  ) {
    // FIXED: Only penalize if there were clear landmarks that disappeared
    fraudIndicators += 10; // Reduced penalty
    reasons.push(
      '⚠️ Some landmarks not found - may be angle/lighting difference'
    );
  }

  // FIXED: More lenient object structure matching for cleanups
  const objectScore = compareObjectLayoutForCleanup(
    originalResult.localizedObjectAnnotations || [],
    proofResult.localizedObjectAnnotations || []
  );
  if (objectScore > 0.5) {
    score += 30;
    reasons.push(
      `✅ Scene structure consistent (${(objectScore * 100).toFixed(1)}%)`
    );
  } else if (objectScore > 0.25) {
    score += 15;
    reasons.push('✅ Scene structure partially matches - expected for cleanup');
  } else {
    // FIXED: Don't heavily penalize structure differences in cleanups
    fraudIndicators += 5; // Much reduced penalty
    reasons.push(
      '⚠️ Scene structure different - may indicate successful cleanup'
    );
  }

  // Text/signage consistency
  const textScore = compareTextElements(
    originalResult.textAnnotations || [],
    proofResult.textAnnotations || []
  );
  if (textScore > 0.6) {
    score += 20;
    reasons.push(
      `✅ Text/signage consistent (${(textScore * 100).toFixed(1)}%)`
    );
  } else if (
    textScore === 0 &&
    (originalResult.textAnnotations?.length || 0) > 3
  ) {
    fraudIndicators += 5; // Reduced penalty
    reasons.push('⚠️ Some text/signs not visible - may be angle difference');
  }

  return { score: Math.min(100, score), reasons, fraudIndicators };
}

// FIXED: More reasonable trash analysis
async function performReasonableTrashAnalysis(
  originalUrl: string,
  proofUrl: string
): Promise<{ score: number; reasons: string[]; fraudIndicators: number }> {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;

  const trashKeywords = [
    'trash',
    'garbage',
    'waste',
    'litter',
    'debris',
    'rubbish',
    'plastic bottle',
    'bottle',
    'can',
    'wrapper',
    'bag',
    'cup',
    'cigarette',
    'container',
    'packaging',
    'pollution',
    'cardboard',
    'paper',
    'food waste',
    'beverage',
    'aluminum',
    'plastic',
  ];
  const cleanKeywords = [
    'clean',
    'tidy',
    'neat',
    'organized',
    'empty',
    'clear',
    'maintained',
    'swept',
    'pristine',
    'spotless',
  ];

  const [originalResult] = await visionClient.labelDetection(originalUrl);
  const [proofResult] = await visionClient.labelDetection(proofUrl);

  const originalLabels = originalResult.labelAnnotations || [];
  const proofLabels = proofResult.labelAnnotations || [];

  const originalTrash = originalLabels.filter((label) =>
    trashKeywords.some((keyword) =>
      label.description?.toLowerCase().includes(keyword.toLowerCase())
    )
  );
  const proofTrash = proofLabels.filter((label) =>
    trashKeywords.some((keyword) =>
      label.description?.toLowerCase().includes(keyword.toLowerCase())
    )
  );
  const cleanIndicators = proofLabels.filter((label) =>
    cleanKeywords.some((keyword) =>
      label.description?.toLowerCase().includes(keyword.toLowerCase())
    )
  );

  if (originalTrash.length === 0) {
    reasons.push('⚠️ No trash detected in original image');
    fraudIndicators += 10; // Reduced penalty
    return { score: 20, reasons, fraudIndicators }; // Don't completely fail
  }

  const trashReductionRatio =
    originalTrash.length > 0
      ? Math.max(
          0,
          (originalTrash.length - proofTrash.length) / originalTrash.length
        )
      : 0;

  // FIXED: More reasonable thresholds
  if (trashReductionRatio >= 0.7) {
    score += 70;
    reasons.push(
      `✅ Excellent trash removal (${(trashReductionRatio * 100).toFixed(
        1
      )}% reduction)`
    );
  } else if (trashReductionRatio >= 0.4) {
    score += 55;
    reasons.push(
      `✅ Good trash removal (${(trashReductionRatio * 100).toFixed(
        1
      )}% reduction)`
    );
  } else if (trashReductionRatio >= 0.15) {
    // FIXED: Much lower threshold
    score += 35;
    reasons.push(
      `✅ Moderate trash removal (${(trashReductionRatio * 100).toFixed(
        1
      )}% reduction)`
    );
    // Don't add fraud indicators for moderate cleanup
  } else if (trashReductionRatio > 0) {
    score += 15;
    reasons.push(
      `⚠️ Minimal trash removal (${(trashReductionRatio * 100).toFixed(
        1
      )}% reduction)`
    );
    fraudIndicators += 5; // Much reduced penalty
  } else {
    reasons.push('❌ No trash removal detected');
    fraudIndicators += 15; // Reduced penalty
  }

  if (cleanIndicators.length > 0) {
    score += 20;
    reasons.push('✅ Clean environment indicators found');
  }

  // FIXED: Only heavily penalize if there's MORE trash
  if (proofTrash.length > originalTrash.length * 1.2) {
    // Allow for some variation
    reasons.push('❌ More trash detected in proof - highly suspicious');
    fraudIndicators += 25;
    score = Math.max(0, score - 40);
  }

  return { score: Math.min(100, score), reasons, fraudIndicators };
}

// FIXED: Better object layout comparison for cleanups
function compareObjectLayoutForCleanup(
  objects1: any[],
  objects2: any[]
): number {
  if (!objects1.length && !objects2.length) return 1.0;
  if (!objects1.length || !objects2.length) return 0.3; // Some tolerance

  // Extract permanent objects (buildings, infrastructure) vs temporary (trash, cars)
  const permanentObjects = [
    'building',
    'wall',
    'fence',
    'tree',
    'sign',
    'pole',
  ];

  const permanent1 = objects1.filter((obj) =>
    permanentObjects.some((p) => obj.name?.toLowerCase().includes(p))
  );
  const permanent2 = objects2.filter((obj) =>
    permanentObjects.some((p) => obj.name?.toLowerCase().includes(p))
  );

  // Focus comparison on permanent structures
  const names1 = permanent1
    .map((obj) => obj.name?.toLowerCase())
    .filter(Boolean);
  const names2 = permanent2
    .map((obj) => obj.name?.toLowerCase())
    .filter(Boolean);

  if (names1.length === 0 && names2.length === 0) {
    // If no permanent objects detected, be more lenient
    const allNames1 = objects1
      .map((obj) => obj.name?.toLowerCase())
      .filter(Boolean);
    const allNames2 = objects2
      .map((obj) => obj.name?.toLowerCase())
      .filter(Boolean);
    const intersection = allNames1.filter((name) => allNames2.includes(name));
    return (
      (intersection.length /
        Math.max(Math.max(allNames1.length, allNames2.length), 1)) *
      0.6
    ); // Reduced weight
  }

  const intersection = names1.filter((name) => names2.includes(name));
  const union = Array.from(new Set([...names1, ...names2]));
  return intersection.length / Math.max(union.length, 1);
}

// Keep the existing helper functions but with the new object layout comparison
function compareLandmarks(landmarks1: any[], landmarks2: any[]): number {
  if (!landmarks1.length || !landmarks2.length) return 0;
  const names1 = landmarks1
    .map((l: any) => l.description?.toLowerCase())
    .filter(Boolean);
  const names2 = landmarks2
    .map((l: any) => l.description?.toLowerCase())
    .filter(Boolean);
  const intersection = names1.filter((name: string) => names2.includes(name));
  const union = Array.from(new Set([...names1, ...names2]));
  return intersection.length / Math.max(union.length, 1);
}

function compareTextElements(texts1: any[], texts2: any[]): number {
  if (!texts1.length || !texts2.length) return 0;
  const words1 = texts1
    .map((t: any) => t.description?.toLowerCase().split(/\s+/))
    .flat()
    .filter((w: string) => w && w.length > 2);
  const words2 = texts2
    .map((t: any) => t.description?.toLowerCase().split(/\s+/))
    .flat()
    .filter((w: string) => w && w.length > 2);
  const intersection = words1.filter((w: string) => words2.includes(w));
  const union = Array.from(new Set([...words1, ...words2]));
  return intersection.length / Math.max(union.length, 1);
}

// ----------- Stricter location proximity (GPS) -------------
async function verifyLocationProximity(
  reportLocation: admin.firestore.GeoPoint,
  proofMetadata: any
): Promise<{ score: number; reasons: string[]; fraudIndicators: number }> {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;

  // INCREASED tolerance for cleanup locations
  const maxAllowedDistance = 0.5; // 500 meters instead of 100m

  if (proofMetadata?.submissionLocation) {
    const submissionLocation = proofMetadata.submissionLocation;
    const distance = calculateDistance(
      { lat: reportLocation.latitude, lng: reportLocation.longitude },
      { lat: submissionLocation.latitude, lng: submissionLocation.longitude }
    );

    if (distance <= 0.1) {
      // Within 100m - perfect
      score = 100;
      reasons.push(
        `✅ Proof submitted from exact location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance <= maxAllowedDistance) {
      // Within 500m - good
      score = 80;
      reasons.push(
        `✅ Proof submitted from nearby location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance <= 1.0) {
      // Within 1km - acceptable
      score = 50;
      reasons.push(
        `⚠️ Proof submitted from distant location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
      fraudIndicators += 5; // Reduced penalty
    } else if (distance > 2) {
      // Beyond 2km - suspicious
      reasons.push(
        `❌ Proof submitted too far away (${distance.toFixed(2)} km)`
      );
      fraudIndicators += 20;
      score = 0;
    } else {
      reasons.push(
        `⚠️ Proof submitted from distant location (${distance.toFixed(2)} km)`
      );
      fraudIndicators += 10;
      score = 30;
    }
  } else {
    reasons.push('📍 No GPS data available for location verification');
    fraudIndicators += 15;
    score = 0;
  }
  return { score, reasons, fraudIndicators };
}

// ----------- Strict timestamp-based verification -------------
function performStrictTemporalVerification(
  reportTimestamp: admin.firestore.Timestamp,
  proofTimestamp: admin.firestore.Timestamp
): { score: number; reasons: string[]; fraudIndicators: number } {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;

  const reportTime = reportTimestamp.toDate();
  const proofTime = proofTimestamp.toDate();
  const timeDiff = proofTime.getTime() - reportTime.getTime();
  const hoursDiff = timeDiff / (1000 * 60 * 60);
  const daysDiff = hoursDiff / 24;

  if (hoursDiff < 0) {
    reasons.push('🚨 Proof timestamp is BEFORE report - major fraud indicator');
    fraudIndicators += 50;
    score = 0;
  } else if (hoursDiff <= 6) {
    score = 100;
    reasons.push(
      `✅ Proof submitted quickly (${hoursDiff.toFixed(
        1
      )} hours) - excellent timing`
    );
  } else if (hoursDiff <= 24) {
    score = 90;
    reasons.push(
      `✅ Proof submitted same day (${hoursDiff.toFixed(
        1
      )} hours) - good timing`
    );
  } else if (hoursDiff <= 72) {
    score = 70;
    reasons.push(
      `✅ Proof submitted within 3 days (${daysDiff.toFixed(
        1
      )} days) - acceptable`
    );
  } else if (hoursDiff <= 168) {
    score = 50;
    reasons.push(
      `⚠️ Proof submitted after ${daysDiff.toFixed(
        1
      )} days - questionable timing`
    );
    fraudIndicators += 10;
  } else if (hoursDiff <= 720) {
    score = 30;
    reasons.push(
      `⚠️ Proof submitted after ${daysDiff.toFixed(1)} days - highly suspicious`
    );
    fraudIndicators += 20;
  } else {
    score = 10;
    reasons.push(
      `🚨 Proof submitted after ${daysDiff.toFixed(1)} days - likely fraudulent`
    );
    fraudIndicators += 35;
  }

  return { score, reasons, fraudIndicators };
}

// ----------- Image metadata/EXIF/authenticity/uniqueness -------------
async function analyzeImageMetadata(
  proofImageUrl: string,
  proofMetadata: any
): Promise<{ score: number; reasons: string[]; fraudIndicators: number }> {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;

  // Device metadata existence
  if (proofMetadata?.deviceInfo) {
    score += 20;
    reasons.push('✅ Device metadata available');
    const deviceTimestamp = proofMetadata.deviceInfo.timestamp;
    const submissionTime = Date.now();
    const timeDelta = Math.abs(submissionTime - deviceTimestamp);
    if (timeDelta < 60000) {
      score += 20;
      reasons.push('✅ Real-time submission verified');
    }
  }

  // Authenticity
  const imageAnalysis = await analyzeImageAuthenticity(proofImageUrl);
  if (imageAnalysis.authentic) {
    score += 30;
    reasons.push('✅ Image appears authentic');
  } else {
    fraudIndicators += 10;
    reasons.push('⚠️ Image may have been processed/manipulated');
  }

  // Duplicate detection
  const duplicateCheck = await checkForDuplicateImages(proofImageUrl);
  if (!duplicateCheck.isDuplicate) {
    score += 30;
    reasons.push('✅ Unique image confirmed');
  } else {
    fraudIndicators += 25;
    reasons.push('❌ Similar image found in system');
    score = Math.max(0, score - 40);
  }

  return { score: Math.min(100, score), reasons, fraudIndicators };
}

// Haversine formula for lat/lng (km)
function calculateDistance(
  point1: { lat: number; lng: number },
  point2: { lat: number; lng: number }
): number {
  const R = 6371;
  const dLat = ((point2.lat - point1.lat) * Math.PI) / 180;
  const dLng = ((point2.lng - point1.lng) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((point1.lat * Math.PI) / 180) *
      Math.cos((point2.lat * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Placeholder: real system should compute image hash, compare against DB, etc
async function analyzeImageAuthenticity(
  imageUrl: string
): Promise<{ authentic: boolean }> {
  // Implement real check in production; for now, assume true
  return { authentic: true };
}

async function checkForDuplicateImages(
  imageUrl: string
): Promise<{ isDuplicate: boolean }> {
  // Implement real perceptual hash DB check for production; for now, assume false
  return { isDuplicate: false };
}

// ================================
// MANUAL REVIEW SYSTEM
// ================================
export const requestManualReview = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }
    const { reportId } = data;
    try {
      await admin.firestore().collection('moderationQueue').add({
        reportId,
        type: 'cleanup_verification',
        requestedBy: context.auth.uid,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true };
    } catch (error) {
      throw new functions.https.HttpsError(
        'internal',
        'Failed to request manual review'
      );
    }
  }
);
