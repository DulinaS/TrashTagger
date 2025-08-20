// functions/src/enhanced_cleanup_verification.ts

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
      // Reset verification state
      await change.after.ref.update({
        proofVerification: admin.firestore.FieldValue.delete(),
        status: 'processing',
        disputeResolved: false,
      });

      // Run comprehensive verification
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
          verificationVersion: '3.0',
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

// Core verification pipeline
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

  // ----------- Scene matching analysis ------------
  try {
    const sceneResult = await performAdvancedSceneMatching(
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

  // ----------- Trash analysis ------------
  try {
    const trashResult = await performStrictTrashAnalysis(
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

  // ----------- Location proximity analysis ------------
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

  // ----------- Time/timestamp analysis ------------
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

  // ----------- Image metadata/uniqueness/authenticity ------------
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

  // Aggregate scoring with weights
  const confidence = Math.round(
    methods.sceneMatching * 0.25 +
      methods.trashAnalysis * 0.25 +
      methods.locationProximity * 0.2 +
      methods.timestampValidity * 0.2 +
      methods.imageMetadata * 0.1
  );

  methods.fraudIndicators = fraudIndicators;

  // ----------- Decision -----------
  let verified = false;
  // Hard block if fraudIndicators is too high or any fatal reason is found
  const FRAUD_HARD_FAIL_THRESHOLD = 25;
  const CONFIDENCE_PASS_THRESHOLD = 75;
  const CONFIDENCE_REVIEW_LOW = 55;

  if (fraudIndicators >= FRAUD_HARD_FAIL_THRESHOLD) {
    reasons.push('🚨 Multiple fraud indicators detected. Submission blocked.');
    verified = false;
    requiresManualReview = false;
  } else if (confidence >= CONFIDENCE_PASS_THRESHOLD && fraudIndicators < 10) {
    reasons.push('🎉 Cleanup verification PASSED - all checks successful');
    verified = true;
  } else if (
    confidence >= CONFIDENCE_REVIEW_LOW &&
    confidence < CONFIDENCE_PASS_THRESHOLD
  ) {
    requiresManualReview = true;
    reasons.push(
      '⚠️ Borderline confidence or minor fraud risk. Flagged for manual review.'
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

// ----------- Scene matching -------------
async function performAdvancedSceneMatching(
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
      { type: 'FACE_DETECTION', maxResults: 5 },
      { type: 'LABEL_DETECTION', maxResults: 25 },
      { type: 'IMAGE_PROPERTIES' },
      { type: 'LOGO_DETECTION', maxResults: 10 },
    ],
  });

  const [proofResult] = await visionClient.annotateImage({
    image: { source: { imageUri: proofUrl } },
    features: [
      { type: 'LANDMARK_DETECTION', maxResults: 10 },
      { type: 'OBJECT_LOCALIZATION', maxResults: 20 },
      { type: 'TEXT_DETECTION', maxResults: 15 },
      { type: 'FACE_DETECTION', maxResults: 5 },
      { type: 'LABEL_DETECTION', maxResults: 25 },
      { type: 'IMAGE_PROPERTIES' },
      { type: 'LOGO_DETECTION', maxResults: 10 },
    ],
  });

  // Landmark/structural matching
  const landmarkScore = compareLandmarks(
    originalResult.landmarkAnnotations || [],
    proofResult.landmarkAnnotations || []
  );
  if (landmarkScore > 0.8) {
    score += 40;
    reasons.push(
      `✅ Strong landmark/building match (${(landmarkScore * 100).toFixed(1)}%)`
    );
  } else if (landmarkScore > 0.5) {
    score += 25;
    reasons.push(
      `✅ Partial landmark match (${(landmarkScore * 100).toFixed(1)}%)`
    );
  } else if (
    landmarkScore === 0 &&
    (originalResult.landmarkAnnotations?.length || 0) > 0
  ) {
    fraudIndicators += 20;
    reasons.push('⚠️ No landmark matches found - possibly different location');
  }

  // Scene structure/object matching
  const objectScore = compareObjectLayout(
    originalResult.localizedObjectAnnotations || [],
    proofResult.localizedObjectAnnotations || []
  );
  if (objectScore > 0.6) {
    score += 30;
    reasons.push(
      `✅ Scene structure matches (${(objectScore * 100).toFixed(1)}%)`
    );
  } else if (objectScore < 0.3) {
    fraudIndicators += 15;
    reasons.push('⚠️ Scene structure significantly different');
  }

  // Text/signage consistency
  const textScore = compareTextElements(
    originalResult.textAnnotations || [],
    proofResult.textAnnotations || []
  );
  if (textScore > 0.7) {
    score += 20;
    reasons.push(`✅ Text/signage matches (${(textScore * 100).toFixed(1)}%)`);
  } else if (
    textScore === 0 &&
    (originalResult.textAnnotations?.length || 0) > 3
  ) {
    fraudIndicators += 10;
    reasons.push('⚠️ Expected text/signs not found in proof image');
  }

  // Color palette (environmental match)
  const colorScore = compareColorPalettes(
    originalResult.imagePropertiesAnnotation,
    proofResult.imagePropertiesAnnotation
  );
  if (colorScore > 0.8) {
    score += 10;
    reasons.push('✅ Environmental colors consistent');
  } else if (colorScore < 0.4) {
    fraudIndicators += 5;
    reasons.push('⚠️ Significant color differences detected');
  }

  return { score: Math.min(100, score), reasons, fraudIndicators };
}

// ----------- Trash reduction/cleanliness -------------
async function performStrictTrashAnalysis(
  originalUrl: string,
  proofUrl: string
): Promise<{ score: number; reasons: string[]; fraudIndicators: number }> {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;

  // Trash & clean keywords
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

  // Analyze both images
  const [originalResult] = await visionClient.labelDetection(originalUrl);
  const [proofResult] = await visionClient.labelDetection(proofUrl);

  const originalLabels = originalResult.labelAnnotations || [];
  const proofLabels = proofResult.labelAnnotations || [];

  // Trash/clean object extraction
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

  // Trash reduction
  if (originalTrash.length === 0) {
    reasons.push('⚠️ No trash detected in original image - suspicious');
    fraudIndicators += 20;
    return { score: 0, reasons, fraudIndicators };
  }

  const trashReductionRatio =
    originalTrash.length > 0
      ? Math.max(
          0,
          (originalTrash.length - proofTrash.length) / originalTrash.length
        )
      : 0;

  if (trashReductionRatio >= 0.8) {
    score += 60;
    reasons.push(
      `✅ Significant trash removal detected (${(
        trashReductionRatio * 100
      ).toFixed(1)}% reduction)`
    );
  } else if (trashReductionRatio >= 0.5) {
    score += 40;
    reasons.push(
      `✅ Moderate trash removal (${(trashReductionRatio * 100).toFixed(
        1
      )}% reduction)`
    );
  } else if (trashReductionRatio >= 0.2) {
    score += 20;
    reasons.push(
      `⚠️ Minimal trash removal (${(trashReductionRatio * 100).toFixed(
        1
      )}% reduction)`
    );
    fraudIndicators += 10;
  } else {
    reasons.push(
      `❌ No significant trash removal detected (${(
        trashReductionRatio * 100
      ).toFixed(1)}% reduction)`
    );
    fraudIndicators += 25;
  }

  if (cleanIndicators.length > 0) {
    score += 15;
    reasons.push('✅ Clean environment detected in proof image');
  }

  if (proofTrash.length > originalTrash.length) {
    reasons.push(
      '❌ More trash detected in proof than original - highly suspicious'
    );
    fraudIndicators += 30;
    score = Math.max(0, score - 40);
  }

  return { score: Math.min(100, score), reasons, fraudIndicators };
}

// ----------- Stricter location proximity (GPS) -------------
async function verifyLocationProximity(
  reportLocation: admin.firestore.GeoPoint,
  proofMetadata: any
): Promise<{ score: number; reasons: string[]; fraudIndicators: number }> {
  const reasons: string[] = [];
  let score = 0;
  let fraudIndicators = 0;
  const maxAllowedDistance = 0.1; // 100 meters

  if (proofMetadata?.submissionLocation) {
    const submissionLocation = proofMetadata.submissionLocation;
    const distance = calculateDistance(
      { lat: reportLocation.latitude, lng: reportLocation.longitude },
      { lat: submissionLocation.latitude, lng: submissionLocation.longitude }
    );
    if (distance <= maxAllowedDistance) {
      score = 100;
      reasons.push(
        `✅ Proof submitted from correct location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance > 2) {
      reasons.push(
        `❌ Proof submitted too far away (${distance.toFixed(2)} km)`
      );
      fraudIndicators += 20;
      score = 0;
    } else {
      reasons.push(
        `⚠️ Proof submitted from distant location (${(distance * 1000).toFixed(
          0
        )}m)`
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

// ----------- Util functions for matching ----------

// Landmarks: strict intersection ratio
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

function compareObjectLayout(objects1: any[], objects2: any[]): number {
  if (!objects1.length || !objects2.length) return 0;
  const names1 = objects1
    .map((obj: any) => obj.name?.toLowerCase())
    .filter(Boolean);
  const names2 = objects2
    .map((obj: any) => obj.name?.toLowerCase())
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

function compareColorPalettes(colorAnn1: any, colorAnn2: any): number {
  // Super simple: compare main color dominance
  if (!colorAnn1?.dominantColors?.colors || !colorAnn2?.dominantColors?.colors)
    return 0;
  const col1 = colorAnn1.dominantColors.colors.map((c: any) => c.color);
  const col2 = colorAnn2.dominantColors.colors.map((c: any) => c.color);
  let matches = 0;
  for (const c1 of col1) {
    for (const c2 of col2) {
      if (
        Math.abs(c1.red - c2.red) < 40 &&
        Math.abs(c1.green - c2.green) < 40 &&
        Math.abs(c1.blue - c2.blue) < 40
      ) {
        matches++;
        break;
      }
    }
  }
  return matches / Math.max(col1.length, 1);
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
