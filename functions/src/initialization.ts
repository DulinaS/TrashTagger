// functions/src/initialization.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// ================================
// INITIALIZE DATABASE
// ================================

export const initializeDatabase = functions.https.onRequest(
  async (req, res) => {
    // Only allow POST requests
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Simple authentication check (in production, use proper admin auth)
    const authToken = req.headers.authorization;
    if (!authToken || authToken !== 'Bearer init-db-secret-key') {
      res.status(401).send('Unauthorized');
      return;
    }

    try {
      console.log('Starting database initialization...');

      // Initialize badges
      await initializeBadges();

      // Initialize global statistics
      await initializeGlobalStats();

      // Initialize app configuration
      await initializeAppConfig();

      // Initialize leaderboards
      await initializeLeaderboards();

      console.log('Database initialization completed successfully');

      res.status(200).json({
        success: true,
        message: 'Database initialized successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      console.error('Database initialization error:', error);
      res.status(500).json({
        success: false,
        error:
          typeof error === 'object' && error !== null && 'message' in error
            ? (error as { message: string }).message
            : String(error),
      });
    }
  }
);

// ================================
// INITIALIZE BADGES
// ================================

async function initializeBadges() {
  const badges = [
    // Milestone Badges
    {
      id: 'first_report',
      name: 'First Step',
      description: 'Submit your first trash report',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Ffirst_report.png',
      type: 'milestone',
      rarity: 'common',
      criteria: {
        reportsRequired: 1,
      },
      pointsAwarded: 10,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'first_cleanup',
      name: 'Cleanup Hero',
      description: 'Complete your first cleanup challenge',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Ffirst_cleanup.png',
      type: 'milestone',
      rarity: 'common',
      criteria: {
        cleanupsRequired: 1,
      },
      pointsAwarded: 25,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'reporter_bronze',
      name: 'Bronze Reporter',
      description: 'Submit 10 trash reports',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Freporter_bronze.png',
      type: 'milestone',
      rarity: 'uncommon',
      criteria: {
        reportsRequired: 10,
      },
      pointsAwarded: 50,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'reporter_silver',
      name: 'Silver Reporter',
      description: 'Submit 50 trash reports',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Freporter_silver.png',
      type: 'milestone',
      rarity: 'rare',
      criteria: {
        reportsRequired: 50,
      },
      pointsAwarded: 100,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'reporter_gold',
      name: 'Gold Reporter',
      description: 'Submit 100 trash reports',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Freporter_gold.png',
      type: 'milestone',
      rarity: 'legendary',
      criteria: {
        reportsRequired: 100,
      },
      pointsAwarded: 250,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'cleaner_bronze',
      name: 'Bronze Cleaner',
      description: 'Complete 5 cleanup challenges',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fcleaner_bronze.png',
      type: 'milestone',
      rarity: 'uncommon',
      criteria: {
        cleanupsRequired: 5,
      },
      pointsAwarded: 75,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'cleaner_silver',
      name: 'Silver Cleaner',
      description: 'Complete 25 cleanup challenges',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fcleaner_silver.png',
      type: 'milestone',
      rarity: 'rare',
      criteria: {
        cleanupsRequired: 25,
      },
      pointsAwarded: 150,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'cleaner_gold',
      name: 'Gold Cleaner',
      description: 'Complete 100 cleanup challenges',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fcleaner_gold.png',
      type: 'milestone',
      rarity: 'legendary',
      criteria: {
        cleanupsRequired: 100,
      },
      pointsAwarded: 300,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },

    // Point-based Badges
    {
      id: 'century_club',
      name: 'Century Club',
      description: 'Earn 100 total points',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fcentury_club.png',
      type: 'milestone',
      rarity: 'uncommon',
      criteria: {
        pointsRequired: 100,
      },
      pointsAwarded: 25,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'high_achiever',
      name: 'High Achiever',
      description: 'Earn 500 total points',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fhigh_achiever.png',
      type: 'milestone',
      rarity: 'rare',
      criteria: {
        pointsRequired: 500,
      },
      pointsAwarded: 100,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'legendary_contributor',
      name: 'Legendary Contributor',
      description: 'Earn 1000 total points',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Flegendary_contributor.png',
      type: 'milestone',
      rarity: 'legendary',
      criteria: {
        pointsRequired: 1000,
      },
      pointsAwarded: 200,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },

    // Special Badges
    {
      id: 'hazard_handler',
      name: 'Hazard Handler',
      description: 'Clean up hazardous waste safely',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fhazard_handler.png',
      type: 'special',
      rarity: 'rare',
      criteria: {
        cleanupsRequired: 1,
        specificTrashTypes: ['hazardous'],
      },
      pointsAwarded: 150,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'recycling_champion',
      name: 'Recycling Champion',
      description: 'Clean up 10 recyclable items',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Frecycling_champion.png',
      type: 'special',
      rarity: 'uncommon',
      criteria: {
        cleanupsRequired: 10,
        specificTrashTypes: ['recyclable'],
      },
      pointsAwarded: 75,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },

    // Streak Badges
    {
      id: 'weekly_warrior',
      name: 'Weekly Warrior',
      description: 'Complete cleanup challenges for 7 consecutive days',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fweekly_warrior.png',
      type: 'streak',
      rarity: 'rare',
      criteria: {
        streakRequired: 7,
        timeFrame: 'daily',
      },
      pointsAwarded: 100,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'monthly_master',
      name: 'Monthly Master',
      description: 'Complete cleanup challenges for 30 consecutive days',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fmonthly_master.png',
      type: 'streak',
      rarity: 'legendary',
      criteria: {
        streakRequired: 30,
        timeFrame: 'daily',
      },
      pointsAwarded: 500,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },

    // Rank Badges
    {
      id: 'top_hundred',
      name: 'Top 100',
      description: 'Reach top 100 on the leaderboard',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Ftop_hundred.png',
      type: 'rank',
      rarity: 'uncommon',
      criteria: {
        leaderboardPosition: 100,
      },
      pointsAwarded: 50,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'top_ten',
      name: 'Top 10',
      description: 'Reach top 10 on the leaderboard',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Ftop_ten.png',
      type: 'rank',
      rarity: 'legendary',
      criteria: {
        leaderboardPosition: 10,
      },
      pointsAwarded: 250,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'number_one',
      name: '#1 Champion',
      description: 'Reach #1 on the leaderboard',
      iconURL:
        'https://firebasestorage.googleapis.com/v0/b/your-project/o/badges%2Fnumber_one.png',
      type: 'rank',
      rarity: 'legendary',
      criteria: {
        leaderboardPosition: 1,
      },
      pointsAwarded: 500,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  const batch = admin.firestore().batch();

  badges.forEach((badge) => {
    const badgeRef = admin.firestore().collection('badges').doc(badge.id);
    batch.set(badgeRef, badge);
  });

  await batch.commit();
  console.log(`Initialized ${badges.length} badges`);
}

// ================================
// INITIALIZE GLOBAL STATISTICS
// ================================

async function initializeGlobalStats() {
  const globalStats = {
    totalUsers: 0,
    totalReports: 0,
    totalCleanups: 0,
    totalPointsAwarded: 0,
    wasteRemoved: {
      general: 0,
      recyclable: 0,
      hazardous: 0,
      large: 0,
      organic: 0,
    },
    avgResponseTime: 0, // in hours
    topContributors: [],
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin
    .firestore()
    .collection('globalStats')
    .doc('current')
    .set(globalStats);
  console.log('Initialized global statistics');
}

// ================================
// INITIALIZE APP CONFIGURATION
// ================================

async function initializeAppConfig() {
  const appConfig = {
    version: '1.0.0',
    minSupportedVersion: '1.0.0',
    features: {
      aiVerification: true,
      realTimeNotifications: true,
      leaderboards: true,
      badges: true,
      socialSharing: true,
      offlineMode: true,
    },
    limits: {
      maxReportsPerDay: 20,
      maxImageSizeMB: 10,
      maxRadius: 50, // km
      minRadius: 1, // km
    },
    defaultSettings: {
      notificationsEnabled: true,
      radius: 5.0,
      safetyWarningsEnabled: true,
      preferredLanguage: 'en',
    },
    supportedLanguages: ['en', 'es', 'fr', 'de'],
    maintenanceMode: false,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection('config').doc('app').set(appConfig);
  console.log('Initialized app configuration');
}

// ================================
// INITIALIZE LEADERBOARDS
// ================================

async function initializeLeaderboards() {
  const leaderboards = {
    global: {
      weekly: [],
      monthly: [],
      allTime: [],
    },
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  await admin
    .firestore()
    .collection('leaderboards')
    .doc('global')
    .set(leaderboards);
  console.log('Initialized leaderboards');
}

// ================================
// RESET DATABASE (Development Only)
// ================================

export const resetDatabase = functions.https.onRequest(async (req, res) => {
  // Only allow in development environment
  if (process.env.NODE_ENV === 'production') {
    res.status(403).send('Operation not allowed in production');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    console.log('Starting database reset...');

    // Collections to reset
    const collections = [
      'users',
      'trashReports',
      'badges',
      'flags',
      'notifications',
      'userBadgeProgress',
      'leaderboards',
      'monthlyArchives',
      'globalStats',
      'config',
      'errorLogs',
      'analyticsEvents',
      'rateLimits',
    ];

    // Delete all documents in each collection
    for (const collectionName of collections) {
      const snapshot = await admin.firestore().collection(collectionName).get();
      const batch = admin.firestore().batch();

      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      if (!snapshot.empty) {
        await batch.commit();
        console.log(
          `Deleted ${snapshot.docs.length} documents from ${collectionName}`
        );
      }
    }

    // Reinitialize with fresh data
    await initializeBadges();
    await initializeGlobalStats();
    await initializeAppConfig();
    await initializeLeaderboards();

    console.log('Database reset completed successfully');

    res.status(200).json({
      success: true,
      message: 'Database reset and reinitialized successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Database reset error:', error);
    res.status(500).json({
      success: false,
      error:
        typeof error === 'object' && error !== null && 'message' in error
          ? (error as { message: string }).message
          : String(error),
    });
  }
});

// ================================
// CREATE TEST DATA
// ================================

export const createTestData = functions.https.onRequest(async (req, res) => {
  // Only allow in development environment
  if (process.env.NODE_ENV === 'production') {
    res.status(403).send('Operation not allowed in production');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    console.log('Creating test data...');

    // Create test users
    const testUsers = [
      {
        id: 'test_user_1',
        name: 'Alice Johnson',
        email: 'alice@test.com',
        totalPoints: 250,
        badges: ['first_report', 'first_cleanup', 'reporter_bronze'],
        level: 3,
        stats: {
          reportsSubmitted: 15,
          challengesCompleted: 8,
          monthlyPoints: 120,
          weeklyStreak: 3,
        },
      },
      {
        id: 'test_user_2',
        name: 'Bob Smith',
        email: 'bob@test.com',
        totalPoints: 180,
        badges: ['first_report', 'first_cleanup'],
        level: 2,
        stats: {
          reportsSubmitted: 12,
          challengesCompleted: 5,
          monthlyPoints: 80,
          weeklyStreak: 1,
        },
      },
      {
        id: 'test_user_3',
        name: 'Charlie Brown',
        email: 'charlie@test.com',
        totalPoints: 450,
        badges: [
          'first_report',
          'first_cleanup',
          'reporter_bronze',
          'cleaner_bronze',
          'century_club',
        ],
        level: 4,
        stats: {
          reportsSubmitted: 25,
          challengesCompleted: 15,
          monthlyPoints: 200,
          weeklyStreak: 5,
        },
      },
    ];

    // Add test users
    const userBatch = admin.firestore().batch();
    testUsers.forEach((user) => {
      const userRef = admin.firestore().collection('users').doc(user.id);
      userBatch.set(userRef, {
        ...user,
        joinDate: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
        settings: {
          notificationsEnabled: true,
          radius: 5.0,
          safetyWarningsEnabled: true,
          preferredLanguage: 'en',
        },
      });
    });
    await userBatch.commit();

    // Create test reports
    const testReports = [
      {
        imageURL: 'https://example.com/trash1.jpg',
        location: new admin.firestore.GeoPoint(40.7128, -74.006), // NYC
        address: 'Central Park, New York, NY',
        reporterId: 'test_user_1',
        status: 'verified',
        trashType: 'general',
        severity: 'low',
        visionVerified: true,
        visionLabels: ['trash', 'plastic', 'bottle'],
        visionConfidence: 0.85,
      },
      {
        imageURL: 'https://example.com/trash2.jpg',
        location: new admin.firestore.GeoPoint(34.0522, -118.2437), // LA
        address: 'Venice Beach, Los Angeles, CA',
        reporterId: 'test_user_2',
        status: 'completed',
        trashType: 'recyclable',
        severity: 'medium',
        visionVerified: true,
        visionLabels: ['plastic bottle', 'can', 'recyclable'],
        visionConfidence: 0.92,
        acceptedBy: 'test_user_3',
        proofURL: 'https://example.com/proof1.jpg',
      },
    ];

    // Add test reports
    const reportBatch = admin.firestore().batch();
    testReports.forEach((report) => {
      const reportRef = admin.firestore().collection('trashReports').doc();
      reportBatch.set(reportRef, {
        ...report,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        acceptedAt: report.acceptedBy
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
        proofTimestamp: report.proofURL
          ? admin.firestore.FieldValue.serverTimestamp()
          : null,
        safetyWarnings: [],
        estimatedEffort: report.severity === 'low' ? '5-15min' : '15-30min',
        votes: { upvotes: 0, downvotes: 0, voters: [] },
        flagged: false,
        flagReasons: [],
        moderatorReviewed: false,
      });
    });
    await reportBatch.commit();

    console.log('Test data created successfully');

    res.status(200).json({
      success: true,
      message: 'Test data created successfully',
      data: {
        users: testUsers.length,
        reports: testReports.length,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Test data creation error:', error);
    res.status(500).json({
      success: false,
      error:
        typeof error === 'object' && error !== null && 'message' in error
          ? (error as { message: string }).message
          : String(error),
    });
  }
});
