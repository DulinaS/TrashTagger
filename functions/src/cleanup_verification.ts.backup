// functions/src/cleanup-verification.ts
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { ImageAnnotatorClient } from '@google-cloud/vision';

const visionClient = new ImageAnnotatorClient({
  keyFilename: './trashtagger-service-account.json',
});

// ================================
// CLEANUP PROOF VERIFICATION
// ================================

export const verifyCleanupProof = functions.firestore
  .document('trashReports/{reportId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const reportId = context.params.reportId;

    console.log(`📋 Document ${reportId} updated:`);
    console.log(`   - Before proofURL: ${beforeData.proofURL}`);
    console.log(`   - After proofURL: ${afterData.proofURL}`);
    console.log(`   - Status: ${beforeData.status} → ${afterData.status}`);

    // ✅ FIXED: Trigger on ANY proof URL change, not just when resubmissionAttempt is set
    if (
      (!beforeData.proofURL && afterData.proofURL) ||
      (beforeData.proofURL !== afterData.proofURL && afterData.proofURL)
    ) {
      console.log(`🔍 Verifying cleanup proof for report: ${reportId}`);
      console.log(`Previous URL: ${beforeData.proofURL}`);
      console.log(`New URL: ${afterData.proofURL}`);

      // ✅ Reset verification state for new attempt
      await change.after.ref.update({
        proofVerification: admin.firestore.FieldValue.delete(),
        status: 'processing',
        disputeResolved: false,
      });

      try {
        // Get both images
        const originalImageUrl = afterData.imageURL;
        const proofImageUrl = afterData.proofURL;

        if (!originalImageUrl || !proofImageUrl) {
          throw new Error('Missing original or proof image URL');
        }

        // Analyze both images
        const [originalResult] = await visionClient.labelDetection(
          originalImageUrl
        );
        const [proofResult] = await visionClient.labelDetection(proofImageUrl);

        const originalLabels = originalResult.labelAnnotations || [];
        const proofLabels = proofResult.labelAnnotations || [];

        // Convert to lowercase for comparison
        const originalDescriptions = originalLabels.map(
          (l) => l.description?.toLowerCase() || ''
        );
        const proofDescriptions = proofLabels.map(
          (l) => l.description?.toLowerCase() || ''
        );

        console.log(
          `📸 Original image labels: ${originalDescriptions
            .slice(0, 5)
            .join(', ')}`
        );
        console.log(
          `📸 Proof image labels: ${proofDescriptions.slice(0, 5).join(', ')}`
        );

        // ================================
        // VERIFICATION LOGIC
        // ================================
        const verification = await performCleanupVerification(
          originalDescriptions,
          proofDescriptions,
          originalImageUrl,
          proofImageUrl
        );

        // ✅ FIXED: Check attempt count BEFORE updating
        const currentAttemptNumber =
          (beforeData.proofVerification?.attemptNumber || 0) + 1;
        const MAX_ATTEMPTS = 3;

        let finalStatus = verification.verified ? 'completed' : 'disputed';

        // If max attempts exceeded and still failing, require manual review
        if (!verification.verified && currentAttemptNumber >= MAX_ATTEMPTS) {
          finalStatus = 'needs_manual_review';
          console.log(
            `⚠️ Max attempts (${MAX_ATTEMPTS}) exceeded for report ${reportId}`
          );
        }

        // ✅ FIXED: Complete verification data update
        await change.after.ref.update({
          proofVerification: {
            verified: verification.verified,
            confidence: verification.confidence,
            reasons: verification.reasons,
            analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
            attemptNumber: currentAttemptNumber,
          },
          status: finalStatus,
          disputeResolved: verification.verified,
          lastProofAttempt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
          `✅ Proof verification ${
            verification.verified ? 'PASSED' : 'FAILED'
          } - Attempt ${currentAttemptNumber}/${MAX_ATTEMPTS}`
        );

        return {
          success: true,
          verification,
          attemptNumber: currentAttemptNumber,
        };
      } catch (error) {
        console.error(`❌ Error verifying cleanup proof: ${error}`);

        // ✅ FIXED: Proper error handling with attempt tracking
        const currentAttemptNumber =
          (beforeData.proofVerification?.attemptNumber || 0) + 1;

        await change.after.ref.update({
          status: 'needs_manual_review',
          proofVerification: {
            verified: false,
            confidence: 0,
            reasons: [`Error during verification: ${error}`],
            analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
            attemptNumber: currentAttemptNumber,
          },
          lastProofAttempt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { success: false, error: String(error) };
      }
    }

    return null;
  });

// ================================
// VERIFICATION ALGORITHMS
// ================================

async function performCleanupVerification(
  originalLabels: string[],
  proofLabels: string[],
  originalImageUrl: string,
  proofImageUrl: string
): Promise<{
  verified: boolean;
  confidence: number;
  reasons: string[];
}> {
  const reasons: string[] = [];
  let confidence = 0;

  // ================================
  // METHOD 1: TRASH ABSENCE CHECK
  // ================================

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

  const originalHasTrash = originalLabels.some((label) =>
    trashKeywords.some((keyword) => label.includes(keyword))
  );

  const proofHasTrash = proofLabels.some((label) =>
    trashKeywords.some((keyword) => label.includes(keyword))
  );

  if (originalHasTrash && !proofHasTrash) {
    confidence += 40;
    reasons.push('✅ Trash detected in original but not in proof');
  } else if (originalHasTrash && proofHasTrash) {
    confidence -= 30;
    reasons.push('❌ Trash still detected in proof image');
  }

  // ================================
  // METHOD 2: LOCATION SIMILARITY
  // ================================

  const locationKeywords = [
    'building',
    'road',
    'street',
    'sidewalk',
    'wall',
    'fence',
    'tree',
    'grass',
    'pavement',
    'sign',
    'door',
    'window',
    'park',
    'bench',
    'path',
    'ground',
    'floor',
    'concrete',
  ];

  const originalLocation = originalLabels.filter((label) =>
    locationKeywords.some((keyword) => label.includes(keyword))
  );

  const proofLocation = proofLabels.filter((label) =>
    locationKeywords.some((keyword) => label.includes(keyword))
  );

  const locationSimilarity = calculateSimilarity(
    originalLocation,
    proofLocation
  );

  if (locationSimilarity > 0.3) {
    confidence += Math.floor(locationSimilarity * 30);
    reasons.push(
      `✅ Location similarity: ${(locationSimilarity * 100).toFixed(1)}%`
    );
  } else {
    confidence -= 50;
    reasons.push('❌ Images appear to be from different locations');
  }

  // ================================
  // METHOD 3: GENERAL SCENE ANALYSIS
  // ================================

  const sceneKeywords = [
    'outdoor',
    'indoor',
    'urban',
    'nature',
    'architectural',
    'landscape',
    'cityscape',
    'residential',
    'commercial',
  ];

  const originalScene = originalLabels.filter((label) =>
    sceneKeywords.some((keyword) => label.includes(keyword))
  );

  const proofScene = proofLabels.filter((label) =>
    sceneKeywords.some((keyword) => label.includes(keyword))
  );

  const sceneSimilarity = calculateSimilarity(originalScene, proofScene);

  if (sceneSimilarity > 0.5) {
    confidence += Math.floor(sceneSimilarity * 20);
    reasons.push(
      `✅ Scene consistency: ${(sceneSimilarity * 100).toFixed(1)}%`
    );
  }

  // ================================
  // METHOD 4: ADVANCED VISUAL COMPARISON
  // ================================

  try {
    const visualSimilarity = await compareImageFeatures(
      originalImageUrl,
      proofImageUrl
    );

    if (visualSimilarity > 0.4) {
      confidence += Math.floor(visualSimilarity * 30);
      reasons.push(
        `✅ Visual similarity: ${(visualSimilarity * 100).toFixed(1)}%`
      );
    }
  } catch (error) {
    console.log('Visual comparison failed, using label-based analysis only');
  }

  // ================================
  // FINAL VERIFICATION DECISION
  // ================================

  // Ensure confidence is within bounds
  confidence = Math.max(0, Math.min(100, confidence));

  const verified = confidence >= 70; // 60% confidence threshold

  if (verified) {
    reasons.push('🎉 Cleanup verification PASSED');
  } else {
    reasons.push('❌ Cleanup verification FAILED - may need manual review');
  }

  return {
    verified,
    confidence,
    reasons,
  };
}

// ================================
// HELPER FUNCTIONS
// ================================

function calculateSimilarity(array1: string[], array2: string[]): number {
  if (array1.length === 0 && array2.length === 0) return 1;
  if (array1.length === 0 || array2.length === 0) return 0;

  const intersection = array1.filter((item) => array2.includes(item));
  const union = [...new Set([...array1, ...array2])];

  return intersection.length / union.length;
}

async function compareImageFeatures(
  imageUrl1: string,
  imageUrl2: string
): Promise<number> {
  try {
    if (!visionClient.objectLocalization) {
      throw new Error('objectLocalization is not available on visionClient');
    }

    // Use Google Cloud Vision's object localization to compare spatial features
    const [result1] = await visionClient.objectLocalization(imageUrl1);
    const [result2] = await visionClient.objectLocalization(imageUrl2);

    const objects1 = result1.localizedObjectAnnotations || [];
    const objects2 = result2.localizedObjectAnnotations || [];

    // Compare object positions and types
    const objectNames1 = objects1.map((obj) => obj.name?.toLowerCase() || '');
    const objectNames2 = objects2.map((obj) => obj.name?.toLowerCase() || '');

    return calculateSimilarity(objectNames1, objectNames2);
  } catch (error) {
    console.log('Object localization comparison failed');
    return 0;
  }
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
