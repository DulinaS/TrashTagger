import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { calculateDistance, findNearbyUsers } from './utils';

// ================================
// NOTIFICATION TYPES & INTERFACES
// ================================

export interface NotificationData {
  type: string;
  reportId?: string;
  challengeId?: string;
  badgeId?: string;
  action: string;
  [key: string]: string | undefined;
}

export interface NotificationPayload {
  title: string;
  body: string;
  imageUrl?: string;
  data: NotificationData;
  priority?: 'high' | 'normal';
  sound?: string;
  badge?: number;
}

export enum NotificationType {
  // Challenge-related
  NEW_CHALLENGE = 'new_challenge',
  CHALLENGE_ACCEPTED = 'challenge_accepted',
  CHALLENGE_REMINDER = 'challenge_reminder',
  PROOF_SUBMITTED = 'proof_submitted',
  VERIFICATION_RESULT = 'verification_result',

  // Gamification
  BADGE_EARNED = 'badge_earned',
  LEVEL_UP = 'level_up',
  POINTS_AWARDED = 'points_awarded',
  LEADERBOARD_UPDATE = 'leaderboard_update',

  // Community
  REPORT_VERIFIED = 'report_verified',
  MONTHLY_RESET = 'monthly_reset',
  ACHIEVEMENT_MILESTONE = 'achievement_milestone',
}

// ================================
// CORE NOTIFICATION SERVICE
// ================================

export class NotificationService {
  static async sendToUsers(
    userIds: string[],
    payload: NotificationPayload
  ): Promise<void> {
    if (userIds.length === 0) return;

    const promises = userIds.map((userId) => this.sendToUser(userId, payload));
    await Promise.allSettled(promises);
  }

  static async sendToUser(
    userId: string,
    payload: NotificationPayload
  ): Promise<boolean> {
    try {
      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        return false;
      }

      const userData = userDoc.data();

      // Check notification preferences
      if (!this.shouldSendNotification(userData, payload.data.type)) {
        console.log(
          `Notifications disabled for user ${userId}, type: ${payload.data.type}`
        );
        return false;
      }

      const fcmTokens = userData?.fcmTokens || [];
      if (fcmTokens.length === 0) {
        console.log(`No FCM tokens for user ${userId}`);
        return false;
      }

      // Build FCM message
      const message = this.buildFCMMessage(payload, fcmTokens);

      // Send notification
      const response = await admin.messaging().sendMulticast(message);
      console.log(
        `Sent notification to ${userId}: ${response.successCount} successful, ${response.failureCount} failed`
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        await this.cleanupInvalidTokens(userId, fcmTokens, response);
      }

      // Store notification in database for history
      await this.storeNotificationHistory(userId, payload);

      return response.successCount > 0;
    } catch (error) {
      console.error(`Error sending notification to ${userId}:`, error);
      return false;
    }
  }

  private static shouldSendNotification(
    userData: any,
    notificationType: string
  ): boolean {
    const settings = userData?.settings || {};

    // Global notification setting
    if (!settings.notificationsEnabled) return false;

    // Specific notification type settings
    switch (notificationType) {
      case NotificationType.NEW_CHALLENGE:
      case NotificationType.CHALLENGE_REMINDER:
        return settings.challengeNotifications !== false;

      case NotificationType.BADGE_EARNED:
      case NotificationType.LEVEL_UP:
      case NotificationType.POINTS_AWARDED:
        return settings.achievementNotifications !== false;

      case NotificationType.LEADERBOARD_UPDATE:
        return settings.leaderboardNotifications !== false;

      default:
        return true;
    }
  }

  private static buildFCMMessage(
    payload: NotificationPayload,
    tokens: string[]
  ) {
    // Fix priority type issue
    const androidPriority: 'default' | 'high' | 'low' | 'min' | 'max' =
      payload.priority === 'high' ? 'high' : 'default';

    return {
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: payload.imageUrl,
      },
      data: this.sanitizeData(payload.data),
      android: {
        notification: {
          sound: payload.sound || 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          priority: androidPriority,
          channelId: this.getChannelId(payload.data.type),
        },
        data: this.sanitizeData(payload.data),
      },
      apns: {
        payload: {
          aps: {
            sound: payload.sound || 'default',
            badge: payload.badge || 1,
            'content-available': 1,
          },
        },
        fcmOptions: {
          imageUrl: payload.imageUrl,
        },
      },
      tokens: tokens,
    };
  }

  private static sanitizeData(data: NotificationData): {
    [key: string]: string;
  } {
    const sanitized: { [key: string]: string } = {};
    Object.entries(data).forEach(([key, value]) => {
      if (value !== undefined) {
        sanitized[key] = String(value);
      }
    });
    return sanitized;
  }

  private static getChannelId(notificationType: string): string {
    switch (notificationType) {
      case NotificationType.NEW_CHALLENGE:
      case NotificationType.CHALLENGE_REMINDER:
        return 'challenges';
      case NotificationType.BADGE_EARNED:
      case NotificationType.LEVEL_UP:
        return 'achievements';
      case NotificationType.LEADERBOARD_UPDATE:
        return 'leaderboard';
      default:
        return 'general';
    }
  }

  private static async cleanupInvalidTokens(
    userId: string,
    tokens: string[],
    response: admin.messaging.BatchResponse
  ): Promise<void> {
    const invalidTokens: string[] = [];

    response.responses.forEach((resp, idx) => {
      if (
        !resp.success &&
        (resp.error?.code === 'messaging/invalid-registration-token' ||
          resp.error?.code === 'messaging/registration-token-not-registered')
      ) {
        invalidTokens.push(tokens[idx]);
      }
    });

    if (invalidTokens.length > 0) {
      await admin
        .firestore()
        .collection('users')
        .doc(userId)
        .update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
    }
  }

  private static async storeNotificationHistory(
    userId: string,
    payload: NotificationPayload
  ): Promise<void> {
    try {
      await admin.firestore().collection('notifications').add({
        userId,
        type: payload.data.type,
        title: payload.title,
        body: payload.body,
        data: payload.data,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Error storing notification history:', error);
    }
  }
}

// ================================
// CHALLENGE-RELATED NOTIFICATIONS
// ================================

// Helper function for direct calls from other functions
export async function notifyNearbyUsersFunction(data: {
  reportLocation: any;
  reportId: string;
  reportData: any;
}): Promise<{ success: boolean; notified: number }> {
  const { reportLocation, reportId, reportData } = data;

  try {
    const nearbyUsers = await findNearbyUsers(
      {
        latitude: reportLocation.latitude,
        longitude: reportLocation.longitude,
      },
      10, // 10km radius
      50 // max 50 users
    );

    if (nearbyUsers.length === 0) return { success: true, notified: 0 };

    const userIds = nearbyUsers
      .filter((user) => user.userId !== reportData.reporterId) // Don't notify reporter
      .map((user) => user.userId);

    await NotificationService.sendToUsers(userIds, {
      title: 'New Cleanup Challenge Available!',
      body: `${reportData.trashType} cleanup needed nearby - ${reportData.address}`,
      imageUrl: reportData.imageURL,
      data: {
        type: NotificationType.NEW_CHALLENGE,
        reportId: reportId,
        action: 'open_challenge_details',
        trashType: reportData.trashType,
        severity: reportData.severity,
      },
      priority: 'high',
    });

    console.log(
      `Notified ${userIds.length} users about new challenge ${reportId}`
    );
    return { success: true, notified: userIds.length };
  } catch (error) {
    console.error('Error notifying nearby users:', error);
    return { success: false, notified: 0 };
  }
}

export const notifyNearbyUsers = functions.https.onCall(
  async (data, context) => {
    return await notifyNearbyUsersFunction(data);
  }
);

// Triggered when someone accepts a challenge
export const notifyChallengAccepted = functions.firestore
  .document('trashReports/{reportId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const reportId = context.params.reportId;

    // Check if challenge was just accepted
    if (
      !beforeData.acceptedBy &&
      afterData.acceptedBy &&
      afterData.status === 'cleaning'
    ) {
      try {
        // Notify the original reporter
        await NotificationService.sendToUser(afterData.reporterId, {
          title: 'Your Report Was Accepted!',
          body: 'Someone has accepted your cleanup challenge and will clean it up soon.',
          data: {
            type: NotificationType.CHALLENGE_ACCEPTED,
            reportId: reportId,
            action: 'view_report_status',
            cleanerId: afterData.acceptedBy,
          },
          priority: 'normal',
        });

        // Notify the cleaner with confirmation
        await NotificationService.sendToUser(afterData.acceptedBy, {
          title: 'Challenge Accepted!',
          body: "You've accepted a cleanup challenge. Don't forget to submit proof when completed.",
          data: {
            type: NotificationType.CHALLENGE_ACCEPTED,
            reportId: reportId,
            action: 'open_my_challenges',
          },
          priority: 'normal',
        });

        console.log(`Sent acceptance notifications for challenge ${reportId}`);
      } catch (error) {
        console.error(`Error sending acceptance notifications:`, error);
      }
    }
  });

// Send reminder notifications for pending challenges
export const sendChallengeReminders = functions.pubsub
  .schedule('0 18 * * *') // 6 PM daily
  .timeZone('UTC')
  .onRun(async () => {
    console.log('Starting challenge reminder notifications...');

    try {
      const now = new Date();
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);

      // Find challenges accepted but not completed
      const pendingChallenges = await admin
        .firestore()
        .collection('trashReports')
        .where('status', '==', 'cleaning')
        .where(
          'acceptedAt',
          '<=',
          admin.firestore.Timestamp.fromDate(oneDayAgo)
        )
        .get();

      const reminderPromises = pendingChallenges.docs.map(async (doc) => {
        const data = doc.data();
        const acceptedAt = data.acceptedAt.toDate();
        const daysSinceAccepted = Math.floor(
          (now.getTime() - acceptedAt.getTime()) / (24 * 60 * 60 * 1000)
        );

        let title = 'Cleanup Reminder';
        let body = "Don't forget about your cleanup challenge!";
        let priority: 'high' | 'normal' = 'normal';

        if (daysSinceAccepted >= 7) {
          title = 'Urgent: Cleanup Overdue';
          body =
            'Your cleanup challenge is overdue. Please complete it or cancel if needed.';
          priority = 'high';
        } else if (daysSinceAccepted >= 3) {
          title = 'Cleanup Reminder';
          body = `Your cleanup challenge is waiting - ${daysSinceAccepted} days since accepted.`;
        }

        await NotificationService.sendToUser(data.acceptedBy, {
          title,
          body,
          data: {
            type: NotificationType.CHALLENGE_REMINDER,
            reportId: doc.id,
            action: 'open_challenge_proof',
            daysPending: daysSinceAccepted.toString(),
          },
          priority,
        });
      });

      await Promise.all(reminderPromises);
      console.log(`Sent ${pendingChallenges.docs.length} challenge reminders`);

      return { success: true, remindersSent: pendingChallenges.docs.length };
    } catch (error) {
      console.error('Error sending challenge reminders:', error);
      return { success: false, error: String(error) };
    }
  });

// Notify about proof submission and verification results
export const notifyVerificationResult = functions.firestore
  .document('trashReports/{reportId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const reportId = context.params.reportId;

    // Check if verification status changed
    if (
      beforeData.status !== afterData.status &&
      ['completed', 'disputed', 'needs_manual_review'].includes(
        afterData.status
      )
    ) {
      try {
        const verification = afterData.proofVerification;
        let title = '';
        let body = '';
        let action = 'view_challenge_result';

        switch (afterData.status) {
          case 'completed':
            title = 'Cleanup Verified! 🎉';
            body = `Your cleanup was successfully verified! You earned ${getCleanerPoints(
              afterData.severity
            )} points.`;
            break;

          case 'disputed':
            title = 'Cleanup Needs Resubmission';
            body =
              'Your cleanup proof was disputed. Please check the feedback and resubmit.';
            action = 'resubmit_proof';
            break;

          case 'needs_manual_review':
            title = 'Cleanup Under Review';
            body =
              "Your cleanup is being manually reviewed. We'll notify you of the result soon.";
            break;
        }

        // Notify the cleaner
        await NotificationService.sendToUser(afterData.acceptedBy, {
          title,
          body,
          data: {
            type: NotificationType.VERIFICATION_RESULT,
            reportId: reportId,
            action: action,
            result: afterData.status,
            confidence: verification?.confidence?.toString() || '0',
          },
          priority: afterData.status === 'completed' ? 'high' : 'normal',
        });

        // Also notify the original reporter if cleanup was completed
        if (afterData.status === 'completed') {
          await NotificationService.sendToUser(afterData.reporterId, {
            title: 'Your Report Was Cleaned Up!',
            body: 'The trash you reported has been successfully cleaned up. Thank you for making a difference!',
            data: {
              type: NotificationType.REPORT_VERIFIED,
              reportId: reportId,
              action: 'view_completed_report',
            },
            priority: 'normal',
          });
        }

        console.log(
          `Sent verification result notifications for ${reportId}: ${afterData.status}`
        );
      } catch (error) {
        console.error('Error sending verification notifications:', error);
      }
    }
  });

// ================================
// GAMIFICATION NOTIFICATIONS
// ================================

// Badge earned notification (triggered by existing badge award system)
export const notifyBadgeEarned = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    const beforeBadges = beforeData?.badges || [];
    const afterBadges = afterData?.badges || [];

    // Check if new badges were added
    const newBadges = afterBadges.filter(
      (badge: string) => !beforeBadges.includes(badge)
    );

    if (newBadges.length > 0) {
      try {
        // Get badge details from badges collection
        const badgePromises = newBadges.map(async (badgeId: string) => {
          const badgeDoc = await admin
            .firestore()
            .collection('badges')
            .doc(badgeId)
            .get();
          return badgeDoc.exists ? { id: badgeId, ...badgeDoc.data() } : null;
        });

        const badgeDetails = (await Promise.all(badgePromises)).filter(Boolean);

        for (const badge of badgeDetails) {
          await NotificationService.sendToUser(userId, {
            title: `New Badge Earned! 🏆`,
            body: `You've earned "${badge.name}" - ${badge.description}`,
            data: {
              type: NotificationType.BADGE_EARNED,
              badgeId: badge.id,
              action: 'view_badges',
              badgeName: badge.name,
              points: badge.pointsAwarded?.toString() || '0',
            },
            priority: 'high',
            sound: 'achievement.wav',
          });
        }

        console.log(
          `Sent badge notifications to ${userId} for badges: ${newBadges.join(
            ', '
          )}`
        );
      } catch (error) {
        console.error('Error sending badge notifications:', error);
      }
    }
  });

// Level up notification
export const notifyLevelUp = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    const beforeLevel = beforeData?.level || 1;
    const afterLevel = afterData?.level || 1;

    if (afterLevel > beforeLevel) {
      try {
        await NotificationService.sendToUser(userId, {
          title: `Level Up! 🚀`,
          body: `Congratulations! You've reached Level ${afterLevel}!`,
          data: {
            type: NotificationType.LEVEL_UP,
            action: 'view_profile',
            newLevel: afterLevel.toString(),
            previousLevel: beforeLevel.toString(),
          },
          priority: 'high',
          sound: 'level_up.wav',
        });

        console.log(
          `Sent level up notification to ${userId}: Level ${afterLevel}`
        );
      } catch (error) {
        console.error('Error sending level up notification:', error);
      }
    }
  });

// Leaderboard position notifications (weekly)
export const notifyLeaderboardUpdates = functions.pubsub
  .schedule('0 12 * * 1') // Every Monday at noon
  .timeZone('UTC')
  .onRun(async () => {
    console.log('Sending weekly leaderboard notifications...');

    try {
      // Get top 10 users from monthly leaderboard
      const topUsers = await admin
        .firestore()
        .collection('users')
        .orderBy('stats.monthlyPoints', 'desc')
        .where('stats.monthlyPoints', '>', 0)
        .limit(10)
        .get();

      const notificationPromises = topUsers.docs.map(async (doc, index) => {
        const userData = doc.data();
        const rank = index + 1;

        let title = '';
        let body = '';

        if (rank === 1) {
          title = "🥇 You're #1 on the Leaderboard!";
          body =
            "Amazing work! You're currently leading this month's cleanup efforts.";
        } else if (rank <= 3) {
          title = `🏆 You're in the Top 3!`;
          body = `You're currently ranked #${rank} on the monthly leaderboard. Keep it up!`;
        } else if (rank <= 10) {
          title = '📊 Top 10 Achievement!';
          body = `You're ranked #${rank} on the monthly leaderboard. Great work!`;
        }

        if (title) {
          await NotificationService.sendToUser(doc.id, {
            title,
            body,
            data: {
              type: NotificationType.LEADERBOARD_UPDATE,
              action: 'view_leaderboard',
              rank: rank.toString(),
              points: userData.stats?.monthlyPoints?.toString() || '0',
            },
            priority: 'normal',
          });
        }
      });

      await Promise.all(notificationPromises);
      console.log(
        `Sent leaderboard notifications to ${topUsers.docs.length} users`
      );

      return { success: true, notificationsSent: topUsers.docs.length };
    } catch (error) {
      console.error('Error sending leaderboard notifications:', error);
      return { success: false, error: String(error) };
    }
  });

// ================================
// COMMUNITY NOTIFICATIONS
// ================================

// Monthly reset notification
export const notifyMonthlyReset = functions.pubsub
  .schedule('0 0 1 * *') // First day of every month
  .timeZone('UTC')
  .onRun(async () => {
    console.log('Sending monthly reset notifications...');

    try {
      // Get all active users
      const activeUsers = await admin
        .firestore()
        .collection('users')
        .where('stats.monthlyPoints', '>', 0)
        .get();

      const notificationPromises = activeUsers.docs.map(async (doc) => {
        const userData = doc.data();
        const monthlyPoints = userData.stats?.monthlyPoints || 0;

        await NotificationService.sendToUser(doc.id, {
          title: 'New Month, New Challenges! 🗓️',
          body: `Last month you earned ${monthlyPoints} points. Ready for this month's cleanup challenges?`,
          data: {
            type: NotificationType.MONTHLY_RESET,
            action: 'view_challenges',
            lastMonthPoints: monthlyPoints.toString(),
          },
          priority: 'normal',
        });
      });

      await Promise.all(notificationPromises);
      console.log(
        `Sent monthly reset notifications to ${activeUsers.docs.length} users`
      );

      return { success: true, notificationsSent: activeUsers.docs.length };
    } catch (error) {
      console.error('Error sending monthly reset notifications:', error);
      return { success: false, error: String(error) };
    }
  });

// ================================
// FCM TOKEN MANAGEMENT
// ================================

export const updateFCMToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { token, platform } = data;
  const userId = context.auth.uid;

  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Token is required'
    );
  }

  try {
    await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .update({
        fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
        platform: platform || 'unknown',
      });

    console.log(`Updated FCM token for user ${userId}`);
    return { success: true };
  } catch (error) {
    console.error('Error updating FCM token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update FCM token'
    );
  }
});

export const removeFCMToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { token } = data;
  const userId = context.auth.uid;

  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Token is required'
    );
  }

  try {
    await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
      });

    console.log(`Removed FCM token for user ${userId}`);
    return { success: true };
  } catch (error) {
    console.error('Error removing FCM token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to remove FCM token'
    );
  }
});

// Helper function to get cleaner points (matches your existing system)
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
