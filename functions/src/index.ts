// functions/src/index.ts - Clean version
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { ImageAnnotatorClient } from '@google-cloud/vision';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Google Cloud Vision with your service account
const visionClient = new ImageAnnotatorClient({
  keyFilename: './trashtagger-service-account.json',
});

// ================================
// AI IMAGE ANALYSIS FUNCTION
// ================================

export const analyzeTrashImage = functions.firestore
  .document('trashReports/{reportId}')
  .onCreate(async (snap, context) => {
    const reportData = snap.data();
    const reportId = context.params.reportId;

    console.log(`🔍 Starting AI analysis for report: ${reportId}`);

    try {
      const imageUrl = reportData.imageURL;
      if (!imageUrl) {
        throw new Error('No image URL found in report');
      }

      console.log(`📸 Analyzing image: ${imageUrl}`);

      // 🤖 GOOGLE CLOUD VISION ANALYSIS
      const [result] = await visionClient.labelDetection(imageUrl);
      const labels = result.labelAnnotations || [];

      console.log(
        `🏷️ Found ${labels.length} labels:`,
        labels
          .slice(0, 5)
          .map((l) => `${l.description} (${(l.score! * 100).toFixed(1)}%)`)
      );

      // 🗑️ TRASH DETECTION
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
        'food waste',
        'cigarette',
        'container',
        'packaging',
      ];

      const hazardousKeywords = [
        'chemical',
        'battery',
        'glass',
        'needle',
        'medical',
        'toxic',
      ];

      const detectedLabels = labels.map(
        (l) => l.description?.toLowerCase() || ''
      );

      // Check for trash
      const hasTrash = detectedLabels.some((label) =>
        trashKeywords.some((keyword) => label.includes(keyword))
      );

      // Check for hazardous materials
      const hasHazardous = detectedLabels.some((label) =>
        hazardousKeywords.some((keyword) => label.includes(keyword))
      );

      // Calculate confidence
      const trashConfidence = labels
        .filter((label) =>
          trashKeywords.some((keyword) =>
            (label.description?.toLowerCase() || '').includes(keyword)
          )
        )
        .reduce((max, label) => Math.max(max, label.score || 0), 0);

      // 🎯 DETERMINE STATUS
      let status = 'rejected';
      if (hasTrash && trashConfidence > 0.6) {
        status = 'verified';
      } else if (trashConfidence > 0.3) {
        status = 'pending';
      }

      // 🏷️ CLASSIFY TRASH TYPE
      let trashType = 'general';
      if (hasHazardous) {
        trashType = 'hazardous';
      } else if (
        detectedLabels.some((l) => l.includes('plastic') || l.includes('can'))
      ) {
        trashType = 'recyclable';
      }

      const severity = hasHazardous ? 'high' : 'low';

      // 💾 UPDATE REPORT
      await snap.ref.update({
        visionVerified: hasTrash,
        visionLabels: detectedLabels.slice(0, 10),
        visionConfidence: trashConfidence,
        status: status,
        trashType: trashType,
        severity: severity,
        safetyWarnings: hasHazardous
          ? ['⚠️ Hazardous materials - contact authorities']
          : [],
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(
        `✅ Analysis complete: ${status} (${(trashConfidence * 100).toFixed(
          1
        )}% confidence)`
      );

      return { success: true, status, confidence: trashConfidence };
    } catch (error) {
      console.error(`❌ Vision API error for ${reportId}:`, error);

      await snap.ref.update({
        status: 'pending',
        visionError: error instanceof Error ? error.message : String(error),
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: false, error: String(error) };
    }
  });

// ================================
// POINTS AND BADGES FUNCTION
// ================================

export const awardPointsAndBadges = functions.firestore
  .document('trashReports/{reportId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const reportId = context.params.reportId;

    // Check if status changed to completed
    if (beforeData.status !== 'completed' && afterData.status === 'completed') {
      console.log(`Awarding points for completed report: ${reportId}`);

      try {
        const reporterId = afterData.reporterId;
        const cleanerId = afterData.acceptedBy;

        if (!reporterId || !cleanerId) {
          console.error('Missing reporterId or cleanerId');
          return;
        }

        // Calculate points based on severity
        const reporterPoints = getReporterPoints(afterData.severity);
        const cleanerPoints = getCleanerPoints(afterData.severity);

        // Use transaction to ensure data consistency
        await admin.firestore().runTransaction(async (transaction) => {
          // Get user documents
          const reporterRef = admin
            .firestore()
            .collection('users')
            .doc(reporterId);
          const cleanerRef = admin
            .firestore()
            .collection('users')
            .doc(cleanerId);

          const reporterDoc = await transaction.get(reporterRef);
          const cleanerDoc = await transaction.get(cleanerRef);

          if (reporterDoc.exists) {
            const reporterData = reporterDoc.data() || {};
            const newReporterPoints =
              (reporterData.totalPoints || 0) + reporterPoints;

            transaction.update(reporterRef, {
              totalPoints: newReporterPoints,
              level: calculateLevel(newReporterPoints),
              'stats.monthlyPoints':
                admin.firestore.FieldValue.increment(reporterPoints),
              'stats.reportsSubmitted': admin.firestore.FieldValue.increment(1),
            });

            console.log(
              `Awarded ${reporterPoints} points to reporter ${reporterId}`
            );
          }

          if (cleanerDoc.exists) {
            const cleanerData = cleanerDoc.data() || {};
            const newCleanerPoints =
              (cleanerData.totalPoints || 0) + cleanerPoints;

            transaction.update(cleanerRef, {
              totalPoints: newCleanerPoints,
              level: calculateLevel(newCleanerPoints),
              'stats.monthlyPoints':
                admin.firestore.FieldValue.increment(cleanerPoints),
              'stats.challengesCompleted':
                admin.firestore.FieldValue.increment(1),
            });

            console.log(
              `Awarded ${cleanerPoints} points to cleaner ${cleanerId}`
            );
          }
        });

        return { success: true };
      } catch (error) {
        console.error(`Error awarding points for report ${reportId}:`, error);
        return { success: false, error: String(error) };
      }
    }

    return null;
  });

// ================================
// HELPER FUNCTIONS
// ================================

function getReporterPoints(severity: string): number {
  switch (severity) {
    case 'low':
      return 10;
    case 'medium':
      return 15;
    case 'high':
      return 25;
    default:
      return 10;
  }
}

function getCleanerPoints(severity: string): number {
  switch (severity) {
    case 'low':
      return 20;
    case 'medium':
      return 30;
    case 'high':
      return 50;
    default:
      return 20;
  }
}

function calculateLevel(points: number): number {
  if (points < 50) return 1;
  if (points < 150) return 2;
  if (points < 300) return 3;
  if (points < 500) return 4;
  if (points < 1000) return 5;
  return Math.floor(points / 200) + 1;
}

// Import your initialization functions
export {
  initializeDatabase,
  resetDatabase,
  createTestData,
} from './initialization';
