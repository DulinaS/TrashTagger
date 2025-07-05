// functions/src/index.ts
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { ImageAnnotatorClient } from '@google-cloud/vision';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Google Cloud Vision
const visionClient = new ImageAnnotatorClient();

// ================================
// IMAGE ANALYSIS FUNCTION
// ================================

export const analyzeTrashImage = functions.firestore
  .document('trashReports/{reportId}')
  .onCreate(async (snap, context) => {
    const reportData = snap.data();
    const reportId = context.params.reportId;

    console.log(`Analyzing image for report: ${reportId}`);

    try {
      // Get the image URL
      const imageUrl = reportData.imageURL;
      if (!imageUrl) {
        throw new Error('No image URL found in report');
      }

      // Analyze image with Google Cloud Vision API
      const [result] = await visionClient.labelDetection(imageUrl);
      const labels = result.labelAnnotations || [];

      console.log(
        `Vision API returned ${labels.length} labels for report ${reportId}`
      );

      // Define trash-related keywords
      const trashKeywords = [
        'trash',
        'garbage',
        'waste',
        'litter',
        'debris',
        'rubbish',
        'plastic bottle',
        'can',
        'wrapper',
        'bag',
        'paper',
        'cigarette',
        'bottle',
        'container',
        'packaging',
      ];

      // Define inappropriate content keywords
      const inappropriateKeywords = [
        'person',
        'face',
        'human',
        'clothing',
        'underwear',
        'adult',
        'child',
        'nudity',
        'body part',
      ];

      // Define hazardous material keywords
      const hazardousKeywords = [
        'chemical',
        'toxic',
        'hazardous',
        'battery',
        'electronic',
        'glass',
        'sharp',
        'needle',
        'syringe',
        'medical waste',
      ];

      // Analyze labels
      const detectedLabels = labels.map(
        (label) => label.description?.toLowerCase() || ''
      );

      // Check for trash content
      const hasTrashContent = detectedLabels.some((label) =>
        trashKeywords.some((keyword) => label.includes(keyword.toLowerCase()))
      );

      // Check for inappropriate content
      const hasInappropriateContent = detectedLabels.some((label) =>
        inappropriateKeywords.some((keyword) =>
          label.includes(keyword.toLowerCase())
        )
      );

      // Check for hazardous materials
      const hasHazardousMaterial = detectedLabels.some((label) =>
        hazardousKeywords.some((keyword) =>
          label.includes(keyword.toLowerCase())
        )
      );

      // Calculate confidence score
      const trashConfidence = labels
        .filter((label) =>
          trashKeywords.some((keyword) =>
            (label.description?.toLowerCase() || '').includes(
              keyword.toLowerCase()
            )
          )
        )
        .reduce((maxScore, label) => Math.max(maxScore, label.score || 0), 0);

      // Determine trash type and severity
      const trashType = determineTrashType(detectedLabels);
      const severity = determineSeverity(detectedLabels, hasHazardousMaterial);
      const safetyWarnings = generateSafetyWarnings(
        detectedLabels,
        hasHazardousMaterial
      );

      // Determine final status
      let finalStatus = 'rejected';
      let needsModeratorReview = false;

      if (hasInappropriateContent) {
        finalStatus = 'rejected';
        needsModeratorReview = true;
      } else if (hasTrashContent && trashConfidence > 0.6) {
        finalStatus = 'verified';
      } else if (trashConfidence > 0.3) {
        finalStatus = 'pending';
        needsModeratorReview = true;
      }

      // Update the report document
      const updateData = {
        visionVerified: hasTrashContent && !hasInappropriateContent,
        visionLabels: detectedLabels,
        visionConfidence: trashConfidence,
        status: finalStatus,
        moderatorReviewed: needsModeratorReview,
        trashType: trashType,
        severity: severity,
        safetyWarnings: safetyWarnings,
        estimatedEffort: getEstimatedEffort(severity),
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await snap.ref.update(updateData);

      console.log(
        `Report ${reportId} analyzed: status=${finalStatus}, confidence=${trashConfidence}`
      );

      // If verified, send notifications to nearby users
      if (finalStatus === 'verified') {
        await notifyNearbyUsers(
          reportData.location,
          reportId,
          trashType,
          severity
        );
      }

      // If needs review, notify moderators
      if (needsModeratorReview) {
        await notifyModerators(
          reportId,
          hasInappropriateContent ? 'inappropriate_content' : 'low_confidence'
        );
      }

      return { success: true, status: finalStatus };
    } catch (error) {
      console.error(`Error analyzing image for report ${reportId}:`, error);

      const errorMessage =
        error instanceof Error ? error.message : String(error);

      // Mark for manual review on error
      await snap.ref.update({
        status: 'pending',
        moderatorReviewed: true,
        visionError: errorMessage,
        analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: false, error: errorMessage };
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
            const newMonthlyPoints =
              (reporterData.stats?.monthlyPoints || 0) + reporterPoints;

            transaction.update(reporterRef, {
              totalPoints: newReporterPoints,
              level: calculateLevel(newReporterPoints),
              'stats.monthlyPoints': newMonthlyPoints,
              'stats.reportsSubmitted': admin.firestore.FieldValue.increment(1),
              'stats.lastReportDate':
                admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(
              `Awarded ${reporterPoints} points to reporter ${reporterId}`
            );
          }

          if (cleanerDoc.exists) {
            const cleanerData = cleanerDoc.data() || {};
            const newCleanerPoints =
              (cleanerData.totalPoints || 0) + cleanerPoints;
            const newMonthlyPoints =
              (cleanerData.stats?.monthlyPoints || 0) + cleanerPoints;

            transaction.update(cleanerRef, {
              totalPoints: newCleanerPoints,
              level: calculateLevel(newCleanerPoints),
              'stats.monthlyPoints': newMonthlyPoints,
              'stats.challengesCompleted':
                admin.firestore.FieldValue.increment(1),
              'stats.lastCleanupDate':
                admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(
              `Awarded ${cleanerPoints} points to cleaner ${cleanerId}`
            );

            // Check and award badges to cleaner
            await checkAndAwardBadges(cleanerId, cleanerData, newCleanerPoints);
          }
        });

        // Send congratulation notifications
        await sendCompletionNotifications(
          reporterId,
          cleanerId,
          reporterPoints,
          cleanerPoints
        );

        return { success: true };
      } catch (error) {
        console.error(`Error awarding points for report ${reportId}:`, error);
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        return { success: false, error: errorMessage };
      }
    }

    return null;
  });

// ================================
// NOTIFICATION FUNCTIONS
// ================================

export const sendDailyReminders = functions.pubsub
  .schedule('0 9 * * *') // 9 AM daily
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Sending daily reminders');

    try {
      // Get active users (last active within 7 days)
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const usersSnapshot = await admin
        .firestore()
        .collection('users')
        .where(
          'lastActive',
          '>',
          admin.firestore.Timestamp.fromDate(sevenDaysAgo)
        )
        .where('settings.notificationsEnabled', '==', true)
        .get();

      console.log(
        `Found ${usersSnapshot.docs.length} active users for daily reminders`
      );

      // Send reminder to each user
      const promises = usersSnapshot.docs.map(async (userDoc) => {
        const userData = userDoc.data();

        // Check if user has nearby unverified reports
        const nearbyReports = await getNearbyUnverifiedReports(
          userData.location,
          userData.settings?.radius || 5
        );

        if (nearbyReports.length > 0) {
          return sendPushNotification(userDoc.id, {
            title: 'Trash Alert! 🗑️',
            body: `${nearbyReports.length} cleanup opportunities near you!`,
            data: {
              type: 'daily_reminder',
              reportCount: nearbyReports.length.toString(),
            },
          });
        }
      });

      await Promise.all(promises.filter(Boolean));

      return { success: true };
    } catch (error) {
      console.error('Error sending daily reminders:', error);
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

// ================================
// LEADERBOARD RESET FUNCTION
// ================================

export const resetMonthlyLeaderboard = functions.pubsub
  .schedule('0 0 1 * *') // First day of every month at midnight
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Resetting monthly leaderboard');

    try {
      // Archive current monthly leaderboard
      const currentMonth = new Date().toISOString().substring(0, 7); // YYYY-MM format

      // Get top performers for the month
      const topPerformersSnapshot = await admin
        .firestore()
        .collection('users')
        .orderBy('stats.monthlyPoints', 'desc')
        .limit(100)
        .get();

      // Save monthly archive
      if (!topPerformersSnapshot.empty) {
        const archiveData = {
          month: currentMonth,
          topPerformers: topPerformersSnapshot.docs.map((doc, index) => ({
            userId: doc.id,
            name: doc.data().name,
            points: doc.data().stats?.monthlyPoints || 0,
            rank: index + 1,
          })),
          archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await admin
          .firestore()
          .collection('monthlyArchives')
          .doc(currentMonth)
          .set(archiveData);
      }

      // Reset all users' monthly points
      const batch = admin.firestore().batch();
      const allUsersSnapshot = await admin
        .firestore()
        .collection('users')
        .get();

      allUsersSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          'stats.monthlyPoints': 0,
          'stats.weeklyStreak': 0, // Reset weekly streak too
        });
      });

      await batch.commit();

      console.log(
        `Monthly leaderboard reset complete. Archived ${topPerformersSnapshot.docs.length} top performers.`
      );

      return { success: true };
    } catch (error) {
      console.error('Error resetting monthly leaderboard:', error);
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

// ================================
// HELPER FUNCTIONS
// ================================

function determineTrashType(labels: string[]): string {
  if (
    labels.some(
      (label) =>
        label.includes('plastic') ||
        label.includes('bottle') ||
        label.includes('can')
    )
  ) {
    return 'recyclable';
  }
  if (
    labels.some((label) => label.includes('glass') || label.includes('metal'))
  ) {
    return 'recyclable';
  }
  if (
    labels.some(
      (label) =>
        label.includes('hazardous') ||
        label.includes('chemical') ||
        label.includes('battery')
    )
  ) {
    return 'hazardous';
  }
  if (
    labels.some(
      (label) =>
        label.includes('furniture') ||
        label.includes('appliance') ||
        label.includes('large')
    )
  ) {
    return 'large';
  }
  if (
    labels.some((label) => label.includes('food') || label.includes('organic'))
  ) {
    return 'organic';
  }
  return 'general';
}

function determineSeverity(labels: string[], hasHazardous: boolean): string {
  if (hasHazardous) return 'high';
  if (
    labels.some(
      (label) =>
        label.includes('large') ||
        label.includes('heavy') ||
        label.includes('furniture')
    )
  ) {
    return 'medium';
  }
  return 'low';
}

function generateSafetyWarnings(
  labels: string[],
  hasHazardous: boolean
): string[] {
  const warnings: string[] = [];

  if (hasHazardous) {
    warnings.push('Hazardous materials detected - contact local authorities');
  }
  if (
    labels.some((label) => label.includes('glass') || label.includes('sharp'))
  ) {
    warnings.push('Sharp objects detected - wear protective gloves');
  }
  if (
    labels.some((label) => label.includes('heavy') || label.includes('large'))
  ) {
    warnings.push('Heavy items detected - may require assistance');
  }
  if (
    labels.some(
      (label) => label.includes('chemical') || label.includes('toxic')
    )
  ) {
    warnings.push('Chemical waste detected - use proper safety equipment');
  }

  return warnings;
}

function getEstimatedEffort(severity: string): string {
  switch (severity) {
    case 'low':
      return '5-15min';
    case 'medium':
      return '15-30min';
    case 'high':
      return '30min+';
    default:
      return '15min';
  }
}

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

async function checkAndAwardBadges(
  userId: string,
  userData: any,
  newTotalPoints: number
) {
  const badges = userData.badges || [];
  const stats = userData.stats || {};
  const challengesCompleted = (stats.challengesCompleted || 0) + 1;

  const newBadges: string[] = [];

  // First cleanup badge
  if (challengesCompleted === 1 && !badges.includes('first_cleanup')) {
    newBadges.push('first_cleanup');
  }

  // Bronze cleaner badge (5 cleanups)
  if (challengesCompleted === 5 && !badges.includes('cleaner_bronze')) {
    newBadges.push('cleaner_bronze');
  }

  // Silver cleaner badge (25 cleanups)
  if (challengesCompleted === 25 && !badges.includes('cleaner_silver')) {
    newBadges.push('cleaner_silver');
  }

  // Point-based badges
  if (newTotalPoints >= 100 && !badges.includes('century_club')) {
    newBadges.push('century_club');
  }

  if (newTotalPoints >= 500 && !badges.includes('high_achiever')) {
    newBadges.push('high_achiever');
  }

  // Award new badges
  if (newBadges.length > 0) {
    await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .update({
        badges: admin.firestore.FieldValue.arrayUnion(...newBadges),
      });

    // Send badge notification
    for (const badge of newBadges) {
      await sendBadgeNotification(userId, badge);
    }

    console.log(
      `Awarded ${
        newBadges.length
      } new badges to user ${userId}: ${newBadges.join(', ')}`
    );
  }
}

async function notifyNearbyUsers(
  location: any,
  reportId: string,
  trashType: string,
  severity: string
) {
  // Implementation for FCM notifications to nearby users
  console.log(
    `Notifying nearby users about new ${severity} ${trashType} report: ${reportId}`
  );
  // TODO: Implement geolocation-based user queries and FCM notifications
}

async function notifyModerators(reportId: string, reason: string) {
  console.log(`Notifying moderators about report ${reportId}: ${reason}`);
  // TODO: Implement moderator notification system
}

async function sendCompletionNotifications(
  reporterId: string,
  cleanerId: string,
  reporterPoints: number,
  cleanerPoints: number
) {
  // Send notifications to both users
  const promises = [
    sendPushNotification(reporterId, {
      title: 'Report Completed! 🎉',
      body: `Your report was cleaned up! You earned ${reporterPoints} points.`,
      data: { type: 'report_completed', points: reporterPoints.toString() },
    }),
    sendPushNotification(cleanerId, {
      title: 'Challenge Complete! 🏆',
      body: `Great job! You earned ${cleanerPoints} points for cleaning up.`,
      data: { type: 'challenge_completed', points: cleanerPoints.toString() },
    }),
  ];

  await Promise.all(promises);
}

async function sendBadgeNotification(userId: string, badgeId: string) {
  const badgeNames = {
    first_cleanup: 'Cleanup Hero',
    cleaner_bronze: 'Bronze Cleaner',
    cleaner_silver: 'Silver Cleaner',
    century_club: 'Century Club',
    high_achiever: 'High Achiever',
  };

  const badgeName =
    badgeNames[badgeId as keyof typeof badgeNames] || 'New Badge';

  await sendPushNotification(userId, {
    title: 'Badge Earned! 🏅',
    body: `You've unlocked the "${badgeName}" badge!`,
    data: { type: 'badge_earned', badgeId },
  });
}

async function sendPushNotification(userId: string, notification: any) {
  // TODO: Implement FCM push notification logic
  console.log(`Sending notification to user ${userId}:`, notification);
}

async function getNearbyUnverifiedReports(userLocation: any, radiusKm: number) {
  // TODO: Implement geolocation query for nearby reports
  return [];
}

export {
  initializeDatabase,
  resetDatabase,
  createTestData,
} from './initialization';
