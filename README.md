# 🚮 TrashTagger - Gamified Environmental Cleanup Platform

TrashTagger is a mobile application that gamifies environmental cleanup by enabling users to report littered areas, accept cleanup challenges, and earn rewards. Built with Flutter and powered by Firebase with Google Cloud Vision AI.

---

## ✨ Key Features

### 📸 Smart Waste Reporting

- AI-powered trash detection using Google Cloud Vision API
- Geotagged photos with Google Maps integration
- Camera integration with image compression
- Multiple image uploads per report
- Real-time AI validation

### 🎮 Gamification System

- Point-based rewards for reporting and cleaning
- Badge system with achievement unlocks
- Level progression system
- Global and monthly leaderboards
- Daily activity streak tracking

### 🗺️ Interactive Mapping

- Real-time report visualization on Google Maps
- Nearby challenge finder
- Color-coded markers by severity
- Location picker for precise reporting
- Route planning integration

### 🏆 Challenge System

- Accept cleanup tasks from verified reports
- Before/after photo proof submission
- AI-powered cleanup verification
- Real-time challenge notifications
- 48-hour completion time limit

### 🔔 Notifications

- Firebase Cloud Messaging for push notifications
- Challenge alerts and badge notifications
- Daily cleanup reminders
- Leaderboard updates
- Customizable notification preferences

### 👤 User Management

- Google Sign-In and Email/Password authentication
- Profile customization
- Personal statistics dashboard
- Privacy and notification controls

---

## 🏗️ Tech Stack

### Frontend

- **Flutter** - Cross-platform mobile development
- **Provider** - State management
- **Google Maps** - Mapping and location services
- **Camera & Image Picker** - Photo capture
- **Firebase SDK** - Authentication, Firestore, Storage, Messaging

### Backend

- **Firebase Authentication** - User authentication
- **Cloud Firestore** - Real-time database
- **Firebase Storage** - Image storage
- **Cloud Functions** - Serverless backend (Node.js with TypeScript)
- **Firebase Cloud Messaging** - Push notifications
- **Google Cloud Vision API** - AI image analysis
- **Geospatial Libraries** - Location-based queries

---

## 🏛️ System Architecture

```
                    Flutter Mobile App (Dart)
                              |
                              ▼
                    ┌─────────────────────┐
                    │   Firebase Backend  │
                    └─────────────────────┘
                              |
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│    Auth      │      │  Firestore   │     │   Storage    │
│              │      │              │     │              │
│ • Email/Pass │      │ • Users      │     │ • Images     │
│ • Google SSO │      │ • Reports    │     │              │
└──────────────┘      │ • Notifc     │     └──────────────┘
                      │ • Leaderboard│
                      └──────────────┘
                             |
                             ▼
            ┌─────────────────────────────────┐
            │     Cloud Functions Layer       │
            ├─────────────────────────────────┤
            │ analyzeTrashImage               │
            │ awardPointsAndBadges            │
            │ verifyCleanupProof              │
            │ notifyNearbyUsers               │
            │ sendDailyReminders (Cron)       │
            │ monthlyLeaderboardReset (Cron)  │
            └─────────────────────────────────┘
                              |
                ┌─────────────┴─────────────┐
                ▼                           ▼
        ┌──────────────┐          ┌──────────────┐
        │ Google Cloud │          │ Google Maps  │
        │  Vision API  │          │     API      │
        │              │          │              │
        │ • AI Trash   │          │ • Location   │
        │   Detection  │          │ • Geocoding  │
        └──────────────┘          └──────────────┘
```

### Key Flows

**📸 Report Flow**: User captures photo → Firebase Storage → Cloud Function → Vision API analyzes → Report status updated → Nearby users notified

**🎮 Challenge Flow**: User accepts challenge → Uploads proof → Vision API validates cleanup → Points awarded → Badges unlocked → Leaderboard updated

**🔔 Notification Flow**: New event occurs → Cloud Function queries nearby users → FCM sends push notifications → In-app notifications stored

**⏰ Scheduled Flow**: Cron triggers → Cloud Functions execute → Database batch operations → Users notified

---

## 📁 Project Structure

- **lib/** - Flutter application code

  - **screens/** - All UI screens (auth, home, report, map, challenges, profile, notifications)
  - **models/** - Data models for users, reports, notifications, and badges
  - **providers/** - State management
  - **services/** - Business logic and API integrations
  - **themes/** - App styling and design system
  - **widgets/** - Reusable UI components
  - **animations/** - Custom animations

- **functions/** - Firebase Cloud Functions (TypeScript)

  - **src/** - AI image analysis, notifications, scheduled tasks, cleanup verification

- **assets/** - Images, icons, and static resources
- **android/ios/web/** - Platform-specific files

---

## 🔥 Firebase Cloud Functions

### Core Functions

**analyzeTrashImage**

- Automatically triggered when new trash report is created
- Uses Google Cloud Vision API to detect trash in images
- Classifies trash type and severity level
- Updates report status (verified/pending/rejected) based on AI confidence
- Notifies nearby users of verified reports

**awardPointsAndBadges**

- Triggered when cleanup challenges are completed
- Awards points to both reporter and cleaner based on severity
- Updates user statistics and level progression
- Checks badge eligibility and unlocks achievements
- Updates leaderboard rankings

**verifyCleanupProof**

- Validates cleanup submissions with before/after photos
- Compares images using Vision API to confirm trash removal
- Awards points if cleanup is successfully verified

**notifyNearbyUsers**

- Finds users within configurable radius using geospatial queries
- Sends push notifications about new cleanup opportunities
- Respects user notification preferences

### Scheduled Tasks

**sendDailyReminders**

- Runs daily at 9 AM UTC
- Sends cleanup reminders to active users
- Promotes engagement with available challenges

**monthlyLeaderboardReset**

- Runs on 1st day of each month
- Archives top performers
- Resets monthly points and rankings

**cleanupOldReports**

- Runs weekly
- Archives reports older than 90 days
- Maintains database performance

---

## 🗄️ Database Structure

### Main Collections

**users**

- User profile information (name, email, photo)
- Total points, level, and unlocked badges
- Statistics (reports submitted, challenges completed, streaks)
- Settings (notification preferences, search radius)
- Location data with geohash for spatial queries
- FCM tokens for push notifications

**trashReports**

- Report details (images, description, location)
- Trash type and severity classification
- AI analysis results from Vision API
- Challenge status (pending, verified, accepted, completed)
- Before/after cleanup photos
- Acceptance and completion timestamps

**notifications**

- In-app notification history
- Notification type, title, and message
- Associated report or badge data
- Read/unread status

**leaderboard_history**

- Monthly archives of top performers
- Historical rankings and points

---

## 🎯 Achievements & Rewards

### Badge Categories

- **First-Time Achievements**: First report, first cleanup
- **Cleaner Tiers**: Bronze (5 cleanups), Silver (25), Gold (100)
- **Point Milestones**: Century Club (100 points), Eco Warrior (500), Green Champion (1000)
- **Streak Badges**: 7-day and 30-day activity streaks
- **Special Awards**: Early Bird, Night Owl, Rapid Responder, Community Hero

---

## 🚀 Setup & Installation

### Prerequisites

- Flutter SDK and Dart
- Node.js (for Cloud Functions)
- Firebase CLI
- Android Studio / Xcode
- Firebase project with billing enabled

### Quick Start

1. **Clone and install Flutter dependencies**

   - Clone repository
   - Run flutter pub get

2. **Firebase Setup**

   - Create Firebase project
   - Add Android/iOS apps and download config files
   - Enable Authentication (Email/Password, Google Sign-In)
   - Enable Firestore, Storage, and Cloud Messaging
   - Upgrade to Blaze plan for Cloud Functions

3. **Google Cloud Vision API**

   - Enable Cloud Vision API
   - Create service account with Vision AI role
   - Download JSON key and place in functions/ folder

4. **Deploy Cloud Functions**

   - Navigate to functions folder
   - Run npm install
   - Run firebase deploy --only functions

5. **Security Rules**

   - Configure Firestore rules for authenticated access
   - Set Storage rules with file size limits

6. **Run the App**
   - Run flutter run for development
   - Build APK/IPA for production deployment

---

## 👥 Team

- [Dulina Senarathne](https://github.com/DulinaS)
- [Janindu Mahathanthila](https://github.com/janindujm)
- [Dilya Walpola](https://github.com/dilyawalpola)

---

## 🗺️ Future Roadmap

- Dark mode support
- Offline mode with sync
- Social sharing and team challenges
- AR cleanup verification
- Multi-language support
- Advanced analytics dashboard

---

## 📜 License

MIT License - Copyright (c) 2025 TrashTagger Team

---

**Made with 💚 for a cleaner planet**
