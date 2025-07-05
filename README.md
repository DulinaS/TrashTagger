# 🚮 TrashTagger - Gamified Cloud Waste Reporting App

TrashTagger is a mobile application built with **Flutter and Firebase** that allows users to report littered public areas, accept cleanup challenges, and earn points through gamified environmental actions. It integrates **Google Cloud Vision API** to verify trash in images and promotes eco-friendly participation via leaderboards and badges.

---

## 📱 Features

- 📸 Upload geotagged photos of trash
- 🤖 Automated trash detection via Vision API
- ✅ Accept cleanup challenges and submit proof
- 🏆 Leaderboards and badges for volunteers
- 🗺️ Real-time map of reports and cleanups
- 🔐 Secure login with Firebase Authentication

---

## 🧰 Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Authentication
  - Firestore
  - Firebase Storage
  - Cloud Functions
- **AI Integration**: Google Cloud Vision API
- **DevOps**: GitHub Actions (optional)

---

## 🧱 Folder Structure

```
TrashTagger/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── report_form_screen.dart
│   │   ├── report_list_screen.dart
│   │   ├── challenge_detail_screen.dart
│   │   ├── leaderboard_screen.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── trash_report_model.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── storage_service.dart
│   │   ├── vision_service.dart
│   └── widgets/
│       ├── report_card.dart
│       ├── badge_display.dart
│
├── functions/ (Cloud Functions)
│   ├── index.js (calls Vision API)
│
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

---

## 🔧 Setup Instructions

### 🧪 Prerequisites

- Flutter installed and configured
- Firebase project created
- Google Cloud Vision API enabled
- Service account JSON file created

### 🚀 Flutter Setup

```bash
git clone https://github.com/yourusername/TrashTagger.git
cd TrashTagger
flutter pub get
flutter run
```

### 🔐 Firebase Setup

- Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Enable:
  - Firebase Authentication
  - Firestore Database
  - Cloud Storage

### 🤖 Vision API Setup

- Enable Cloud Vision API in Google Cloud Console
- Create and download service account key (`vision-key.json`)
- Place it in your `functions/` folder and reference in `index.js`

---

## 📡 Firestore Structure (Simplified)

```
users/
  {userId} → name, email, totalPoints, badges[]
trashReports/
  {reportId} → imageURL, location, reporterId, status, proofURL
```

---

## 🧪 Example Cloud Function (Vision API)

```javascript
const functions = require('firebase-functions');
const vision = require('@google-cloud/vision');
const admin = require('firebase-admin');

admin.initializeApp();
const client = new vision.ImageAnnotatorClient({
  keyFilename: 'vision-key.json',
});

exports.analyzeTrashImage = functions.firestore
  .document('trashReports/{reportId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const [result] = await client.labelDetection(data.imageURL);
    const labels = result.labelAnnotations.map((l) =>
      l.description.toLowerCase()
    );

    const trashTags = ['garbage', 'litter', 'plastic', 'trash', 'waste'];
    const isTrash = labels.some((label) => trashTags.includes(label));

    await snap.ref.update({
      visionVerified: isTrash,
      status: isTrash ? 'verified' : 'rejected',
    });
  });
```

---

## 📜 License

MIT License – feel free to fork and build on it.

---

## 👥 Authors

- [Dulina Senarathne](https://github.com/DulinaS)
- [Janindu Mahathanthila](https://github.com/janindujm)
- [Dilya Walpola]()

---

## 🌱 Contributing

Pull requests are welcome. Please open an issue first to discuss any major changes.

---

## ✅ Status

🚧 In development – MVP due by 2025 Aug

> > > > > > > 6b667b9b564e86d354f953468fe742531f351b01
