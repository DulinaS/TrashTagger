// functions/src/scheduled-functions.ts - FIXED VERSION
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

// ================================
// DAILY REMINDER NOTIFICATIONS
// ================================

export const sendDailyReminders = functions.pubsub
  .schedule('0 9 * * *') // 9 AM daily
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('📅 Sending daily reminders...');

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

      console.log(`👥 Found ${usersSnapshot.docs.length} active users`);

      // Get available challenges
      const challengesSnapshot = await admin
        .firestore()
        .collection('trashReports')
        .where('status', '==', 'verified')
        .where('acceptedBy', '==', null)
        .get();

      console.log(
        `🎯 Found ${challengesSnapshot.docs.length} available challenges`
      );

      if (challengesSnapshot.docs.length === 0) {
        console.log('No challenges available, skipping reminders');
        return { success: true, message: 'No challenges available' };
      }

      // Send reminders to active users - FIXED: Added return statement
      const promises = usersSnapshot.docs.map(async (userDoc) => {
        const userId = userDoc.id;

        try {
          // Find nearby challenges (simplified - could use geo-queries)
          const userChallenges = challengesSnapshot.docs.filter(
            (challengeDoc) => {
              const challengeData = challengeDoc.data();
              // Don't remind about own reports
              return challengeData.reporterId !== userId;
            }
          );

          if (userChallenges.length > 0) {
            // Create notification document
            await admin
              .firestore()
              .collection('notifications')
              .add({
                userId: userId,
                type: 'daily_reminder',
                title: 'Cleanup Opportunities Available! 🗑️',
                body: `${userChallenges.length} cleanup challenges need your help!`,
                data: {
                  challengeCount: userChallenges.length,
                  action: 'open_challenges',
                },
                read: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });

            console.log(`📬 Sent reminder to user: ${userId}`);
            return { userId, sent: true }; // FIXED: Added return
          } else {
            return {
              userId,
              sent: false,
              reason: 'No challenges available for user',
            }; // FIXED: Added return
          }
        } catch (error) {
          console.error(`❌ Failed to send reminder to ${userId}: ${error}`);
          return { userId, sent: false, error: String(error) }; // FIXED: Added return
        }
      });

      const results = await Promise.allSettled(promises);
      const successful = results.filter((r) => r.status === 'fulfilled').length;
      const failed = results.filter((r) => r.status === 'rejected').length;

      console.log(
        `✅ Daily reminders complete: ${successful} sent, ${failed} failed`
      );

      return {
        success: true,
        totalUsers: usersSnapshot.docs.length,
        remindersSent: successful,
        failed: failed,
        availableChallenges: challengesSnapshot.docs.length,
      };
    } catch (error) {
      console.error('❌ Error sending daily reminders:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });

// ================================
// MONTHLY LEADERBOARD RESET
// ================================

export const resetMonthlyLeaderboard = functions.pubsub
  .schedule('0 0 1 * *') // First day of every month at midnight
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🏆 Starting monthly leaderboard reset...');

    try {
      // Get current month for archiving
      const now = new Date();
      const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const monthKey = lastMonth.toISOString().substring(0, 7); // YYYY-MM format

      console.log(`📅 Archiving data for month: ${monthKey}`);

      // Get top performers for the month
      const topPerformersSnapshot = await admin
        .firestore()
        .collection('users')
        .where('stats.monthlyPoints', '>', 0)
        .orderBy('stats.monthlyPoints', 'desc')
        .limit(100)
        .get();

      console.log(
        `👑 Found ${topPerformersSnapshot.docs.length} monthly performers`
      );

      // Archive monthly winners
      if (!topPerformersSnapshot.empty) {
        const archiveData = {
          month: monthKey,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          topPerformers: topPerformersSnapshot.docs.map((doc, index) => {
            const data = doc.data();
            return {
              rank: index + 1,
              userId: doc.id,
              name: data.name || 'Unknown',
              points: data.stats?.monthlyPoints || 0,
              level: data.level || 1,
              badges: data.badges?.length || 0,
            };
          }),
          totalParticipants: topPerformersSnapshot.docs.length,
          winner:
            topPerformersSnapshot.docs.length > 0
              ? {
                  userId: topPerformersSnapshot.docs[0].id,
                  name: topPerformersSnapshot.docs[0].data().name || 'Unknown',
                  points:
                    topPerformersSnapshot.docs[0].data().stats?.monthlyPoints ||
                    0,
                }
              : null,
        };

        // Save archive
        await admin
          .firestore()
          .collection('monthlyArchives')
          .doc(monthKey)
          .set(archiveData);

        console.log(`📚 Archived monthly leaderboard for ${monthKey}`);

        // Award special badges to top performers
        await awardMonthlyBadges(topPerformersSnapshot.docs);
      }

      // Reset all users' monthly points
      console.log('🔄 Resetting monthly points for all users...');

      const allUsersSnapshot = await admin
        .firestore()
        .collection('users')
        .get();

      // Process in batches to avoid timeout
      const batchSize = 500;
      const batches = [];

      for (let i = 0; i < allUsersSnapshot.docs.length; i += batchSize) {
        const batch = admin.firestore().batch();
        const batchDocs = allUsersSnapshot.docs.slice(i, i + batchSize);

        batchDocs.forEach((doc) => {
          batch.update(doc.ref, {
            'stats.monthlyPoints': 0,
            'stats.weeklyStreak': 0, // Reset weekly streak too
            'stats.lastMonthlyReset':
              admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        batches.push(batch.commit());
      }

      await Promise.all(batches);

      console.log(
        `🎉 Monthly reset complete! Updated ${allUsersSnapshot.docs.length} users`
      );

      // Update global stats
      await admin
        .firestore()
        .collection('globalStats')
        .doc('current')
        .update({
          lastMonthlyReset: admin.firestore.FieldValue.serverTimestamp(),
          monthlyResetsCompleted: admin.firestore.FieldValue.increment(1),
        });

      return {
        success: true,
        month: monthKey,
        topPerformers: topPerformersSnapshot.docs.length,
        usersReset: allUsersSnapshot.docs.length,
        winner:
          topPerformersSnapshot.docs.length > 0
            ? {
                name: topPerformersSnapshot.docs[0].data().name,
                points:
                  topPerformersSnapshot.docs[0].data().stats?.monthlyPoints ||
                  0,
              }
            : null,
      };
    } catch (error) {
      console.error('❌ Error resetting monthly leaderboard:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });

// ================================
// AWARD MONTHLY BADGES
// ================================

async function awardMonthlyBadges(
  topPerformers: FirebaseFirestore.QueryDocumentSnapshot[]
) {
  console.log('🏅 Awarding monthly badges...');

  const badgePromises = topPerformers.map(async (userDoc, index) => {
    const rank = index + 1;
    const userId = userDoc.id;
    const userData = userDoc.data();
    const currentBadges = userData.badges || [];

    const newBadges: string[] = [];

    // Monthly winner badge
    if (rank === 1 && !currentBadges.includes('monthly_champion')) {
      newBadges.push('monthly_champion');
    }

    // Top 10 monthly badge
    if (rank <= 10 && !currentBadges.includes('monthly_top_ten')) {
      newBadges.push('monthly_top_ten');
    }

    // High monthly score badge
    const monthlyPoints = userData.stats?.monthlyPoints || 0;
    if (
      monthlyPoints >= 500 &&
      !currentBadges.includes('monthly_high_scorer')
    ) {
      newBadges.push('monthly_high_scorer');
    }

    // Award new badges
    if (newBadges.length > 0) {
      await userDoc.ref.update({
        badges: admin.firestore.FieldValue.arrayUnion(...newBadges),
        'stats.monthlyBadgesEarned': admin.firestore.FieldValue.increment(
          newBadges.length
        ),
      });

      // Create notification for badge awards
      await admin
        .firestore()
        .collection('notifications')
        .add({
          userId: userId,
          type: 'monthly_badge_award',
          title: 'Monthly Badge Earned! 🏆',
          body: `You've earned ${newBadges.length} badge(s) for your monthly performance!`,
          data: {
            badges: newBadges,
            rank: rank,
            points: monthlyPoints,
          },
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`🏅 Awarded badges to ${userId}: ${newBadges.join(', ')}`);
    }

    return { userId, badges: newBadges }; // Added return statement
  });

  await Promise.allSettled(badgePromises);
}

// ================================
// WEEKLY STATS UPDATE (BONUS)
// ================================

export const updateWeeklyStats = functions.pubsub
  .schedule('0 0 * * 0') // Every Sunday at midnight
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('📊 Updating weekly stats...');

    try {
      // Update weekly streaks and reset weekly points
      const usersSnapshot = await admin.firestore().collection('users').get();

      const batch = admin.firestore().batch();

      usersSnapshot.docs.forEach((doc) => {
        // FIXED: Removed unused variable 'stats'
        // const userData = doc.data();
        // const stats = userData.stats || {};

        // Reset weekly points but maintain streak info
        batch.update(doc.ref, {
          'stats.weeklyPoints': 0,
          'stats.lastWeeklyReset': admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      console.log(
        `📈 Updated weekly stats for ${usersSnapshot.docs.length} users`
      );

      return {
        success: true,
        usersUpdated: usersSnapshot.docs.length,
      };
    } catch (error) {
      console.error('❌ Error updating weekly stats:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });

// ================================
// ADDITIONAL HELPER FUNCTIONS
// ================================

// Clean up old notifications (run weekly)
export const cleanupOldNotifications = functions.pubsub
  .schedule('0 2 * * 1') // Every Monday at 2 AM
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🧹 Cleaning up old notifications...');

    try {
      // Delete notifications older than 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const oldNotificationsSnapshot = await admin
        .firestore()
        .collection('notifications')
        .where(
          'createdAt',
          '<',
          admin.firestore.Timestamp.fromDate(thirtyDaysAgo)
        )
        .limit(500) // Process in batches
        .get();

      if (oldNotificationsSnapshot.empty) {
        console.log('No old notifications to clean up');
        return { success: true, deleted: 0 };
      }

      const batch = admin.firestore().batch();
      oldNotificationsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      console.log(
        `🗑️ Deleted ${oldNotificationsSnapshot.docs.length} old notifications`
      );

      return {
        success: true,
        deleted: oldNotificationsSnapshot.docs.length,
      };
    } catch (error) {
      console.error('❌ Error cleaning up notifications:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });

// Update global statistics (run daily)
export const updateGlobalStats = functions.pubsub
  .schedule('0 1 * * *') // Every day at 1 AM
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('📊 Updating global statistics...');

    try {
      const [usersSnapshot, reportsSnapshot, completedReportsSnapshot] =
        await Promise.all([
          admin.firestore().collection('users').get(),
          admin.firestore().collection('trashReports').get(),
          admin
            .firestore()
            .collection('trashReports')
            .where('status', '==', 'completed')
            .get(),
        ]);

      // Calculate totals
      let totalPoints = 0;
      let activeUsers = 0;
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      usersSnapshot.docs.forEach((doc) => {
        const userData = doc.data();
        totalPoints += userData.totalPoints || 0;

        if (
          userData.lastActive &&
          userData.lastActive.toDate() > sevenDaysAgo
        ) {
          activeUsers++;
        }
      });

      // Update global stats
      await admin
        .firestore()
        .collection('globalStats')
        .doc('current')
        .update({
          totalUsers: usersSnapshot.docs.length,
          activeUsers: activeUsers,
          totalReports: reportsSnapshot.docs.length,
          totalCleanups: completedReportsSnapshot.docs.length,
          totalPointsAwarded: totalPoints,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          updateCount: admin.firestore.FieldValue.increment(1),
        });

      console.log(
        `📈 Updated global stats: ${usersSnapshot.docs.length} users, ${reportsSnapshot.docs.length} reports`
      );

      return {
        success: true,
        stats: {
          totalUsers: usersSnapshot.docs.length,
          activeUsers: activeUsers,
          totalReports: reportsSnapshot.docs.length,
          totalCleanups: completedReportsSnapshot.docs.length,
          totalPointsAwarded: totalPoints,
        },
      };
    } catch (error) {
      console.error('❌ Error updating global stats:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      };
    }
  });
