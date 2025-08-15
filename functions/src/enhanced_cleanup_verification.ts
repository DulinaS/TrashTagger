// functions/src/enhanced-cleanup-verification.ts - CREATE NEW FILE
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
    visualSimilarity: number;
    locationProximity: number;
    timestampValidity: number;
    imageMetadata: number;
  };
  requiresManualReview: boolean;
}

export const verifyCleanupProof = functions.firestore
  .document('trashReports/{reportId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const reportId = context.params.reportId;

    console.log(`🔍 Enhanced verification for report: ${reportId}`);

    if (beforeData.proofURL !== afterData.proofURL && afterData.proofURL) {
      try {
        // Reset verification state
        await change.after.ref.update({
          proofVerification: admin.firestore.FieldValue.delete(),
          status: 'processing',
          disputeResolved: false,
        });

        // Comprehensive verification
        const verification = await performEnhancedVerification({
          originalImageUrl: afterData.imageURL,
          proofImageUrl: afterData.proofURL,
          reportLocation: afterData.location,
          reportTimestamp: afterData.timestamp,
          proofTimestamp: afterData.proofTimestamp,
          proofMetadata: afterData.proofMetadata,
          reportId,
        });

        // Determine final status
        let finalStatus = 'completed';
        if (!verification.verified) {
          finalStatus = verification.requiresManualReview
            ? 'needs_manual_review'
            : 'disputed';
        }

        // Update with comprehensive results
        await change.after.ref.update({
          proofVerification: {
            verified: verification.verified,
            confidence: verification.confidence,
            reasons: verification.reasons,
            methods: verification.methods,
            requiresManualReview: verification.requiresManualReview,
            analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
            verificationVersion: '2.0', // Track verification algorithm version
          },
          status: finalStatus,
          disputeResolved: verification.verified,
          lastProofAttempt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
          `✅ Enhanced verification complete: ${
            verification.verified ? 'PASSED' : 'FAILED'
          } (${verification.confidence}%)`
        );

        return { success: true, verification };
      } catch (error) {
        console.error(`❌ Enhanced verification error: ${error}`);

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
    }

    return null;
  });

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
    visualSimilarity: 0,
    locationProximity: 0,
    timestampValidity: 0,
    imageMetadata: 0,
  };

  const reasons: string[] = [];
  let requiresManualReview = false;

  // METHOD 1: Enhanced Visual Analysis (40% weight)
  try {
    const visualResult = await analyzeVisualSimilarity(
      params.originalImageUrl,
      params.proofImageUrl
    );
    methods.visualSimilarity = visualResult.score;
    reasons.push(...visualResult.reasons);
  } catch (error) {
    console.error('Visual analysis failed:', error);
    reasons.push('⚠️ Visual analysis failed - flagged for manual review');
    requiresManualReview = true;
  }

  // METHOD 2: Location Proximity Verification (30% weight)
  try {
    const locationResult = await verifyLocationProximity(
      params.proofImageUrl,
      params.reportLocation,
      params.proofMetadata
    );
    methods.locationProximity = locationResult.score;
    reasons.push(...locationResult.reasons);
  } catch (error) {
    console.error('Location verification failed:', error);
    reasons.push('⚠️ Location verification failed');
  }

  // METHOD 3: Timestamp Validation (20% weight)
  const timestampResult = verifyTimestamps(
    params.reportTimestamp,
    params.proofTimestamp
  );
  methods.timestampValidity = timestampResult.score;
  reasons.push(...timestampResult.reasons);

  // METHOD 4: Image Metadata Analysis (10% weight)
  try {
    const metadataResult = await analyzeImageMetadata(
      params.proofImageUrl,
      params.proofMetadata
    );
    methods.imageMetadata = metadataResult.score;
    reasons.push(...metadataResult.reasons);
  } catch (error) {
    console.error('Metadata analysis failed:', error);
    reasons.push('⚠️ Metadata analysis failed');
  }

  /* // Calculate weighted confidence
  const confidence = Math.round(
    methods.visualSimilarity * 0.4 +
      methods.locationProximity * 0.3 +
      methods.timestampValidity * 0.2 +
      methods.imageMetadata * 0.1
  );

  // Verification thresholds
  const verified = confidence >= 70 && !requiresManualReview;

  // Flag for manual review if confidence is borderline
  if (confidence >= 50 && confidence < 70 && !requiresManualReview) {
    requiresManualReview = true;
    reasons.push('⚠️ Borderline confidence - flagged for manual review');
  }

  if (verified) {
    reasons.push('🎉 Cleanup verification PASSED - all checks successful');
  } else if (requiresManualReview) {
    reasons.push('👁️ Verification needs human review');
  } else {
    reasons.push('❌ Cleanup verification FAILED - insufficient confidence');
  } */
  // Calculate weighted confidence
  const confidence = Math.round(
    methods.visualSimilarity * 0.4 +
      methods.locationProximity * 0.3 +
      methods.timestampValidity * 0.2 +
      methods.imageMetadata * 0.1
  );

  // UPDATED VERIFICATION THRESHOLDS - More realistic
  const verified = confidence >= 60 && !requiresManualReview; // Lowered from 70 to 60

  // UPDATED FLAG FOR MANUAL REVIEW - More lenient
  if (confidence >= 45 && confidence < 60 && !requiresManualReview) {
    // Lowered from 50-70
    requiresManualReview = true;
    reasons.push('⚠️ Borderline confidence - flagged for manual review');
  }

  // Success/failure messages
  if (verified) {
    reasons.push('🎉 Cleanup verification PASSED - all checks successful');
  } else if (requiresManualReview) {
    reasons.push('👁️ Verification needs human review');
  } else {
    reasons.push('❌ Cleanup verification FAILED - insufficient confidence');
  }

  return {
    verified,
    confidence,
    reasons,
    methods,
    requiresManualReview,
  };
}

async function analyzeVisualSimilarity(
  originalUrl: string,
  proofUrl: string
): Promise<{ score: number; reasons: string[] }> {
  const reasons: string[] = [];
  let score = 0;

  // Enhanced Google Vision analysis with multiple features
  const [originalResult] = await visionClient.annotateImage({
    image: { source: { imageUri: originalUrl } },
    features: [
      { type: 'LABEL_DETECTION', maxResults: 20 },
      { type: 'OBJECT_LOCALIZATION', maxResults: 15 },
      { type: 'LANDMARK_DETECTION', maxResults: 10 },
      { type: 'LOGO_DETECTION', maxResults: 10 },
      { type: 'TEXT_DETECTION', maxResults: 10 },
      { type: 'FACE_DETECTION', maxResults: 5 }, // Privacy: blur faces
    ],
  });

  const [proofResult] = await visionClient.annotateImage({
    image: { source: { imageUri: proofUrl } },
    features: [
      { type: 'LABEL_DETECTION', maxResults: 20 },
      { type: 'OBJECT_LOCALIZATION', maxResults: 15 },
      { type: 'LANDMARK_DETECTION', maxResults: 10 },
      { type: 'LOGO_DETECTION', maxResults: 10 },
      { type: 'TEXT_DETECTION', maxResults: 10 },
      { type: 'FACE_DETECTION', maxResults: 5 },
    ],
  });

  // 1. Landmark/Building Recognition (high confidence indicator)
  const landmarkScore = compareLandmarks(
    originalResult.landmarkAnnotations || [],
    proofResult.landmarkAnnotations || []
  );

  if (landmarkScore > 0.7) {
    score += 40;
    reasons.push(
      `✅ Strong landmark match (${(landmarkScore * 100).toFixed(1)}%)`
    );
  } else if (landmarkScore > 0.3) {
    score += 20;
    reasons.push(
      `✅ Partial landmark match (${(landmarkScore * 100).toFixed(1)}%)`
    );
  }

  // 2. Text/Signage Matching
  const textScore = compareTextElements(
    originalResult.textAnnotations || [],
    proofResult.textAnnotations || []
  );

  if (textScore > 0.5) {
    score += 25;
    reasons.push(
      `✅ Matching text/signs detected (${(textScore * 100).toFixed(1)}%)`
    );
  }

  // 3. Object Layout and Spatial Relationships
  const objectScore = compareObjectLayout(
    originalResult.localizedObjectAnnotations || [],
    proofResult.localizedObjectAnnotations || []
  );

  if (objectScore > 0.4) {
    score += 20;
    reasons.push(
      `✅ Similar scene layout (${(objectScore * 100).toFixed(1)}%)`
    );
  }

  // 4. Trash Absence Verification (most important)
  const trashAnalysis = analyzeTrashRemoval(
    originalResult.labelAnnotations || [],
    proofResult.labelAnnotations || []
  );

  if (trashAnalysis.removed) {
    score += 15;
    reasons.push('✅ Trash successfully removed from scene');
  } else {
    reasons.push('❌ Trash still visible or unclear removal');
  }

  return { score: Math.min(100, score), reasons };
}

async function verifyLocationProximity(
  proofImageUrl: string,
  reportLocation: admin.firestore.GeoPoint,
  proofMetadata: any
): Promise<{ score: number; reasons: string[] }> {
  const reasons: string[] = [];
  let score = 0;

  /* // 1. Check GPS data from proof submission metadata
  if (proofMetadata?.submissionLocation) {
    const submissionLocation = proofMetadata.submissionLocation;
    const distance = calculateDistance(
      { lat: reportLocation.latitude, lng: reportLocation.longitude },
      { lat: submissionLocation.latitude, lng: submissionLocation.longitude }
    );

    if (distance <= 0.05) {
      // Within 50 meters
      score += 50;
      reasons.push(
        `✅ Proof submitted from exact location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance <= 0.1) {
      // Within 100 meters
      score += 35;
      reasons.push(
        `✅ Proof submitted near location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance <= 0.5) {
      // Within 500 meters
      score += 20;
      reasons.push(
        `⚠️ Proof submitted nearby (${(distance * 1000).toFixed(0)}m away)`
      );
    } else {
      reasons.push(
        `❌ Proof submitted far away (${
          distance > 1
            ? distance.toFixed(1) + 'km'
            : (distance * 1000).toFixed(0) + 'm'
        } away)`
      );
    }

    // Bonus for verified location flag
    if (proofMetadata.locationVerified) {
      score += 20;
      reasons.push('✅ User confirmed location verification');
    }
  } else {
    // Fallback: Try to extract GPS from image EXIF
    try {
      const imageGPS = await extractGPSFromImageEXIF(proofImageUrl);
      if (imageGPS) {
        const distance = calculateDistance(
          { lat: reportLocation.latitude, lng: reportLocation.longitude },
          imageGPS
        );

        if (distance <= 0.05) {
          score += 40;
          reasons.push(
            `✅ Image GPS confirms location (${(distance * 1000).toFixed(0)}m)`
          );
        } else if (distance <= 0.2) {
          score += 25;
          reasons.push(
            `✅ Image GPS nearby (${(distance * 1000).toFixed(0)}m)`
          );
        }
      } else {
        reasons.push('📍 No GPS data available for location verification');
      }
    } catch (error) {
      reasons.push('📍 Could not extract location data from image');
    }
  } */
  // 1. Check GPS data from proof submission metadata
  if (proofMetadata?.submissionLocation) {
    const submissionLocation = proofMetadata.submissionLocation;
    const distance = calculateDistance(
      { lat: reportLocation.latitude, lng: reportLocation.longitude },
      { lat: submissionLocation.latitude, lng: submissionLocation.longitude }
    );

    // UPDATED THRESHOLDS - More realistic for cleanup scenarios
    if (distance <= 0.1) {
      // Within 100 meters - perfect
      score += 50;
      reasons.push(
        `✅ Proof submitted from exact location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance <= 0.4) {
      // Within 400 meters - good (your 327m case would get points here)
      score += 35;
      reasons.push(
        `✅ Proof submitted near location (${(distance * 1000).toFixed(
          0
        )}m away)`
      );
    } else if (distance <= 0.8) {
      // Within 800 meters - acceptable
      score += 20;
      reasons.push(
        `⚠️ Proof submitted nearby (${(distance * 1000).toFixed(0)}m away)`
      );
    } else if (distance <= 2.0) {
      // Within 2km - questionable but some points
      score += 10;
      reasons.push(
        `⚠️ Proof submitted from distant location (${
          distance > 1
            ? distance.toFixed(1) + 'km'
            : (distance * 1000).toFixed(0) + 'm'
        } away)`
      );
    } else {
      // Too far away
      reasons.push(
        `❌ Proof submitted too far away (${
          distance > 1
            ? distance.toFixed(1) + 'km'
            : (distance * 1000).toFixed(0) + 'm'
        } away)`
      );
    }

    // Bonus for verified location flag (even if distance is imperfect)
    if (proofMetadata.locationVerified) {
      score += 15; // Additional points for user-confirmed verification
      reasons.push('✅ User confirmed location verification');
    }
  } else {
    // Existing fallback logic remains the same...
    try {
      const imageGPS = await extractGPSFromImageEXIF(proofImageUrl);
      if (imageGPS) {
        const distance = calculateDistance(
          { lat: reportLocation.latitude, lng: reportLocation.longitude },
          imageGPS
        );

        if (distance <= 0.1) {
          score += 40;
          reasons.push(
            `✅ Image GPS confirms location (${(distance * 1000).toFixed(0)}m)`
          );
        } else if (distance <= 0.5) {
          score += 25;
          reasons.push(
            `✅ Image GPS nearby (${(distance * 1000).toFixed(0)}m)`
          );
        }
      } else {
        reasons.push('📍 No GPS data available for location verification');
      }
    } catch (error) {
      reasons.push('📍 Could not extract location data from image');
    }
  }

  // 2. Reverse geocoding verification
  try {
    const addressVerification = await verifyWithReverseGeocoding(
      reportLocation,
      proofMetadata?.submissionLocation
    );

    if (addressVerification.match) {
      score += 15;
      reasons.push('✅ Address verification confirms same area');
    }
  } catch (error) {
    console.log('Reverse geocoding failed:', error);
  }

  return { score: Math.min(100, score), reasons };
}

function verifyTimestamps(
  reportTimestamp: admin.firestore.Timestamp,
  proofTimestamp: admin.firestore.Timestamp
): { score: number; reasons: string[] } {
  const reasons: string[] = [];
  let score = 0;

  const reportTime = reportTimestamp.toDate();
  const proofTime = proofTimestamp.toDate();
  const timeDiff = proofTime.getTime() - reportTime.getTime();
  const hoursDiff = timeDiff / (1000 * 60 * 60);

  if (hoursDiff > 0 && hoursDiff <= 72) {
    // Within 3 days
    score = 100;
    reasons.push(
      `✅ Proof submitted ${hoursDiff.toFixed(
        1
      )} hours after report (optimal timing)`
    );
  } else if (hoursDiff > 72 && hoursDiff <= 168) {
    // Within 1 week
    score = 80;
    reasons.push(
      `✅ Proof submitted ${(hoursDiff / 24).toFixed(1)} days after report`
    );
  } else if (hoursDiff > 168 && hoursDiff <= 720) {
    // Within 1 month
    score = 60;
    reasons.push(
      `⚠️ Proof submitted ${(hoursDiff / 24).toFixed(
        1
      )} days after report (delayed)`
    );
  } else if (hoursDiff <= 0) {
    score = 30;
    reasons.push(
      '⚠️ Proof timestamp appears to be before report (clock skew?)'
    );
  } else {
    score = 20;
    reasons.push(
      `❌ Proof submitted ${(hoursDiff / 24).toFixed(
        1
      )} days after report (too delayed)`
    );
  }

  return { score, reasons };
}

async function analyzeImageMetadata(
  proofImageUrl: string,
  proofMetadata: any
): Promise<{ score: number; reasons: string[] }> {
  const reasons: string[] = [];
  let score = 0;

  try {
    // Check device consistency
    if (proofMetadata?.deviceInfo) {
      score += 20;
      reasons.push('✅ Device metadata available');

      // Check for suspicious timing patterns
      const deviceTimestamp = proofMetadata.deviceInfo.timestamp;
      const submissionTime = Date.now();
      const timeDelta = Math.abs(submissionTime - deviceTimestamp);

      if (timeDelta < 60000) {
        // Within 1 minute
        score += 20;
        reasons.push('✅ Real-time submission verified');
      }
    }

    // Verify image hasn't been heavily processed
    const imageAnalysis = await analyzeImageAuthenticity(proofImageUrl);
    if (imageAnalysis.authentic) {
      score += 30;
      reasons.push('✅ Image appears authentic');
    } else {
      reasons.push('⚠️ Image may have been processed');
    }

    // Check for duplicate images across system
    const duplicateCheck = await checkForDuplicateImages(proofImageUrl);
    if (!duplicateCheck.isDuplicate) {
      score += 30;
      reasons.push('✅ Unique image confirmed');
    } else {
      reasons.push('❌ Similar image found in system');
    }
  } catch (error) {
    console.log('Metadata analysis failed:', error);
    reasons.push('⚠️ Metadata analysis incomplete');
  }

  return { score: Math.min(100, score), reasons };
}

// Helper functions
function calculateDistance(
  point1: { lat: number; lng: number },
  point2: { lat: number; lng: number }
): number {
  const R = 6371; // Earth's radius in kilometers
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

function compareLandmarks(landmarks1: any[], landmarks2: any[]): number {
  if (landmarks1.length === 0 && landmarks2.length === 0) return 0;
  if (landmarks1.length === 0 || landmarks2.length === 0) return 0;

  const names1 = landmarks1
    .map((l) => l.description?.toLowerCase())
    .filter(Boolean);
  const names2 = landmarks2
    .map((l) => l.description?.toLowerCase())
    .filter(Boolean);

  const intersection = names1.filter((name) => names2.includes(name));
  const union = [...new Set([...names1, ...names2])];

  return intersection.length / Math.max(union.length, 1);
}

function compareTextElements(texts1: any[], texts2: any[]): number {
  if (texts1.length === 0 && texts2.length === 0) return 0;
  if (texts1.length === 0 || texts2.length === 0) return 0;

  const words1 = texts1
    .map((t) => t.description?.toLowerCase().split(/\s+/))
    .flat()
    .filter((word) => word && word.length > 2);

  const words2 = texts2
    .map((t) => t.description?.toLowerCase().split(/\s+/))
    .flat()
    .filter((word) => word && word.length > 2);

  if (words1.length === 0 && words2.length === 0) return 0;
  if (words1.length === 0 || words2.length === 0) return 0;

  const intersection = words1.filter((word) => words2.includes(word));
  const union = [...new Set([...words1, ...words2])];

  return intersection.length / union.length;
}

function compareObjectLayout(objects1: any[], objects2: any[]): number {
  if (objects1.length === 0 && objects2.length === 0) return 1;
  if (objects1.length === 0 || objects2.length === 0) return 0;

  const names1 = objects1.map((obj) => obj.name?.toLowerCase()).filter(Boolean);
  const names2 = objects2.map((obj) => obj.name?.toLowerCase()).filter(Boolean);

  const intersection = names1.filter((name) => names2.includes(name));
  const union = [...new Set([...names1, ...names2])];

  return intersection.length / Math.max(union.length, 1);
}

function analyzeTrashRemoval(
  originalLabels: any[],
  proofLabels: any[]
): { removed: boolean; confidence: number } {
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
  ];

  const originalTrash = originalLabels.filter((label) =>
    trashKeywords.some((keyword) =>
      label.description?.toLowerCase().includes(keyword)
    )
  );

  const proofTrash = proofLabels.filter((label) =>
    trashKeywords.some((keyword) =>
      label.description?.toLowerCase().includes(keyword)
    )
  );

  // Calculate confidence based on trash detection reduction
  const originalTrashScore = originalTrash.reduce(
    (sum, label) => sum + (label.score || 0),
    0
  );
  const proofTrashScore = proofTrash.reduce(
    (sum, label) => sum + (label.score || 0),
    0
  );

  const reductionRatio =
    originalTrashScore > 0
      ? (originalTrashScore - proofTrashScore) / originalTrashScore
      : 0;

  return {
    removed: reductionRatio > 0.5, // 50% reduction in trash detection
    confidence: Math.max(0, Math.min(100, reductionRatio * 100)),
  };
}

async function extractGPSFromImageEXIF(
  imageUrl: string
): Promise<{ lat: number; lng: number } | null> {
  // Implementation would use EXIF parsing library
  // This is a placeholder - implement based on your needs
  try {
    // Use Cloud Function to download image and parse EXIF
    // Or use Google Cloud Vision API's properties detection
    return null; // Placeholder
  } catch (error) {
    return null;
  }
}

async function verifyWithReverseGeocoding(
  reportLocation: admin.firestore.GeoPoint,
  submissionLocation?: admin.firestore.GeoPoint
): Promise<{ match: boolean }> {
  // Implementation would use Google Geocoding API
  // Compare administrative areas, postal codes, etc.
  return { match: false }; // Placeholder
}

async function analyzeImageAuthenticity(
  imageUrl: string
): Promise<{ authentic: boolean }> {
  // Could implement image forensics, check for signs of manipulation
  // For now, return true (authentic)
  return { authentic: true };
}

async function checkForDuplicateImages(
  imageUrl: string
): Promise<{ isDuplicate: boolean }> {
  // Could implement perceptual hashing to find similar images
  // Check against existing proof images in database
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
