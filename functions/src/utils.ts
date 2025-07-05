// functions/src/utils.ts
import * as admin from 'firebase-admin';
import { geohashForLocation, distanceBetween } from 'geofire-common';

// ================================
// GEOLOCATION UTILITIES
// ================================

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface GeoBounds {
  northeast: GeoPoint;
  southwest: GeoPoint;
}

// Calculate geohash for location-based queries
export function calculateGeohash(location: GeoPoint): string {
  return geohashForLocation([location.latitude, location.longitude]);
}

// Calculate distance between two points in kilometers
export function calculateDistance(point1: GeoPoint, point2: GeoPoint): number {
  return distanceBetween(
    [point1.latitude, point1.longitude],
    [point2.latitude, point2.longitude]
  );
}

// Find users within radius of a location
export async function findNearbyUsers(
  centerLocation: GeoPoint,
  radiusKm: number,
  limit: number = 50
): Promise<any[]> {
  try {
    // Get all active users (this is simplified - in production, use geohashing)
    const usersSnapshot = await admin
      .firestore()
      .collection('users')
      .where('settings.notificationsEnabled', '==', true)
      .limit(limit * 2) // Get more to filter by distance
      .get();

    const nearbyUsers = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();

      // Skip users without location or who opt out of notifications
      if (
        !userData.lastKnownLocation ||
        !userData.settings?.notificationsEnabled
      ) {
        continue;
      }

      const userLocation = userData.lastKnownLocation;
      const distance = calculateDistance(centerLocation, userLocation);

      if (distance <= radiusKm) {
        nearbyUsers.push({
          userId: userDoc.id,
          ...userData,
          distanceKm: distance,
        });
      }
    }

    // Sort by distance and limit results
    return nearbyUsers
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, limit);
  } catch (error) {
    console.error('Error finding nearby users:', error);
    return [];
  }
}

// ================================
// NOTIFICATION UTILITIES
// ================================

export interface NotificationPayload {
  title: string;
  body: string;
  data?: { [key: string]: string };
  imageUrl?: string;
}

// Send FCM notification to user
export async function sendPushNotification(
  userId: string,
  payload: NotificationPayload
): Promise<boolean> {
  try {
    // Get user's FCM tokens
    const userDoc = await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      console.log(`User ${userId} not found for notification`);
      return false;
    }

    const userData = userDoc.data();
    const fcmTokens = userData?.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`No FCM tokens found for user ${userId}`);
      return false;
    }

    // Prepare notification message
    const message = {
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: payload.imageUrl,
      },
      data: payload.data || {},
      tokens: fcmTokens,
    };

    // Send notification
    const response = await admin.messaging().sendMulticast(message);

    console.log(
      `Sent notification to user ${userId}: ${response.successCount} successful, ${response.failureCount} failed`
    );

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (
          !resp.success &&
          resp.error?.code === 'messaging/invalid-registration-token'
        ) {
          invalidTokens.push(fcmTokens[idx]);
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

    return response.successCount > 0;
  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
    return false;
  }
}

// Send bulk notifications
export async function sendBulkNotifications(
  userIds: string[],
  payload: NotificationPayload
): Promise<{ successful: number; failed: number }> {
  const promises = userIds.map((userId) =>
    sendPushNotification(userId, payload)
  );
  const results = await Promise.allSettled(promises);

  const successful = results.filter(
    (result) => result.status === 'fulfilled' && result.value
  ).length;
  const failed = results.length - successful;

  return { successful, failed };
}

// ================================
// DATABASE UTILITIES
// ================================

// Batch update users safely
export async function batchUpdateUsers(
  updates: { userId: string; data: any }[],
  batchSize: number = 500
): Promise<void> {
  const chunks = chunkArray(updates, batchSize);

  for (const chunk of chunks) {
    const batch = admin.firestore().batch();

    chunk.forEach((update) => {
      const userRef = admin.firestore().collection('users').doc(update.userId);
      batch.update(userRef, update.data);
    });

    await batch.commit();
  }
}

// Get leaderboard data
export async function getLeaderboardData(
  period: 'weekly' | 'monthly' | 'allTime',
  limit: number = 100
): Promise<any[]> {
  try {
    let field = 'totalPoints';

    if (period === 'monthly') {
      field = 'stats.monthlyPoints';
    } else if (period === 'weekly') {
      field = 'stats.weeklyPoints';
    }

    const snapshot = await admin
      .firestore()
      .collection('users')
      .orderBy(field, 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map((doc, index) => ({
      rank: index + 1,
      userId: doc.id,
      name: doc.data().name,
      photoURL: doc.data().photoURL,
      points: doc.data().totalPoints || 0,
      monthlyPoints: doc.data().stats?.monthlyPoints || 0,
      weeklyPoints: doc.data().stats?.weeklyPoints || 0,
      badges: doc.data().badges || [],
      level: doc.data().level || 1,
    }));
  } catch (error) {
    console.error('Error getting leaderboard data:', error);
    return [];
  }
}

// ================================
// IMAGE PROCESSING UTILITIES
// ================================

// Validate image content type
export function isValidImageType(contentType: string): boolean {
  const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  return validTypes.includes(contentType.toLowerCase());
}

// Generate optimized image URL
export function generateOptimizedImageUrl(
  originalUrl: string,
  width?: number,
  height?: number,
  quality: number = 80
): string {
  // In production, you might use Firebase Extensions or Cloud Functions
  // to generate optimized images. For now, return original URL.
  return originalUrl;
}

// ================================
// VALIDATION UTILITIES
// ================================

// Validate email format
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Validate coordinates
export function isValidCoordinates(lat: number, lng: number): boolean {
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

// Sanitize user input
export function sanitizeString(input: string): string {
  return input.trim().replace(/[<>]/g, '');
}

// ================================
// ERROR HANDLING UTILITIES
// ================================

// Custom error class
export class TrashTaggerError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 400
  ) {
    super(message);
    this.name = 'TrashTaggerError';
  }
}

// Log error with context
export async function logError(
  error: any,
  context: string,
  userId?: string,
  additionalData?: any
): Promise<void> {
  try {
    const errorLog = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      context,
      userId,
      error: {
        message: error.message,
        stack: error.stack,
        code: error.code,
      },
      additionalData,
      environment: process.env.NODE_ENV || 'unknown',
    };

    await admin.firestore().collection('errorLogs').add(errorLog);
  } catch (logError) {
    console.error('Failed to log error:', logError);
  }
}

// ================================
// ANALYTICS UTILITIES
// ================================

// Track analytics event
export async function trackEvent(
  eventName: string,
  userId?: string,
  properties?: any
): Promise<void> {
  try {
    const event = {
      eventName,
      userId,
      properties: properties || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      sessionId: generateSessionId(),
    };

    await admin.firestore().collection('analyticsEvents').add(event);
  } catch (error) {
    console.error('Error tracking event:', error);
  }
}

// Generate session ID
export function generateSessionId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// ================================
// UTILITY FUNCTIONS
// ================================

// Split array into chunks
export function chunkArray<T>(array: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

// Delay execution (for rate limiting)
export function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Generate random string
export function generateRandomString(length: number): string {
  const chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Format timestamp
export function formatTimestamp(timestamp: admin.firestore.Timestamp): string {
  return timestamp.toDate().toISOString();
}

// Calculate points based on activity type and severity
export function calculatePoints(
  activityType: 'report' | 'cleanup',
  severity: 'low' | 'medium' | 'high',
  bonusMultiplier: number = 1
): number {
  const basePoints = {
    report: { low: 10, medium: 15, high: 25 },
    cleanup: { low: 20, medium: 30, high: 50 },
  };

  return Math.floor(basePoints[activityType][severity] * bonusMultiplier);
}

// ================================
// BADGE CHECKING UTILITIES
// ================================

export interface BadgeCheck {
  badgeId: string;
  earned: boolean;
  progress: number;
  requirement: number;
}

// Check if user qualifies for specific badges
export function checkBadgeEligibility(
  userData: any,
  badgeDefinitions: any[]
): BadgeCheck[] {
  const results: BadgeCheck[] = [];
  const userBadges = userData.badges || [];
  const userStats = userData.stats || {};

  badgeDefinitions.forEach((badge) => {
    // Skip if user already has this badge
    if (userBadges.includes(badge.id)) {
      results.push({
        badgeId: badge.id,
        earned: true,
        progress: 1,
        requirement: 1,
      });
      return;
    }

    const criteria = badge.criteria || {};
    let progress = 0;
    let requirement = 1;
    let earned = false;

    // Check different criteria types
    if (criteria.reportsRequired) {
      requirement = criteria.reportsRequired;
      progress =
        Math.min(userStats.reportsSubmitted || 0, requirement) / requirement;
      earned = (userStats.reportsSubmitted || 0) >= requirement;
    } else if (criteria.cleanupsRequired) {
      requirement = criteria.cleanupsRequired;
      progress =
        Math.min(userStats.challengesCompleted || 0, requirement) / requirement;
      earned = (userStats.challengesCompleted || 0) >= requirement;
    } else if (criteria.pointsRequired) {
      requirement = criteria.pointsRequired;
      progress = Math.min(userData.totalPoints || 0, requirement) / requirement;
      earned = (userData.totalPoints || 0) >= requirement;
    }

    results.push({
      badgeId: badge.id,
      earned,
      progress,
      requirement,
    });
  });

  return results;
}

// ================================
// RATE LIMITING UTILITIES
// ================================

export async function checkRateLimit(
  userId: string,
  action: string,
  limitPerHour: number
): Promise<boolean> {
  try {
    const now = new Date();
    const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    const rateLimitDoc = `rateLimit_${userId}_${action}`;
    const rateLimitRef = admin
      .firestore()
      .collection('rateLimits')
      .doc(rateLimitDoc);

    const doc = await rateLimitRef.get();

    if (doc.exists) {
      const data = doc.data();
      const count = data?.count || 0;
      const lastReset = data?.lastReset?.toDate() || new Date(0);

      if (lastReset > hourAgo) {
        return count < limitPerHour;
      }
    }

    // Reset or create rate limit counter
    await rateLimitRef.set({
      count: 1,
      lastReset: admin.firestore.FieldValue.serverTimestamp(),
    });

    return true;
  } catch (error) {
    console.error('Error checking rate limit:', error);
    return true; // Allow on error to avoid blocking users
  }
}

// Increment rate limit counter
export async function incrementRateLimit(
  userId: string,
  action: string
): Promise<void> {
  try {
    const rateLimitDoc = `rateLimit_${userId}_${action}`;
    const rateLimitRef = admin
      .firestore()
      .collection('rateLimits')
      .doc(rateLimitDoc);

    await rateLimitRef.update({
      count: admin.firestore.FieldValue.increment(1),
    });
  } catch (error) {
    console.error('Error incrementing rate limit:', error);
  }
}
