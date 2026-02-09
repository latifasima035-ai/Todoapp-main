# Firebase Setup Guide for Habit Tracker Community Wall

## Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Name it: `habit-tracker`
4. Disable Google Analytics (optional)
5. Click "Create Project"

## Step 2: Register Your App
1. In Firebase Console, click the Flutter icon (</> if not visible)
2. Enter package name: `com.example.habit_tracker`
3. Download `google-services.json` for Android
4. Click "Register App"

## Step 3: Download Firebase Config Files
### For Android:
1. Download `google-services.json`
2. Place it in: `android/app/`

### For iOS (if needed):
1. Download `GoogleService-Info.plist`
2. Place it in Xcode project

## Step 4: Update Android Build Files
Edit `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

Edit `android/app/build.gradle`:
```gradle
plugins {
    id 'com.android.application'
    id 'com.google.gms.google-services'  // Add this line
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-storage'
}
```

## Step 5: Create Firestore Database
1. In Firebase Console, go to **Firestore Database**
2. Click **Create Database**
3. Choose **Start in test mode** (for development)
4. Select region close to you
5. Click **Create**

## Step 6: Setup Security Rules
In Firestore → Rules, replace with:
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /community_posts/{document=**} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId.toString();
    }
  }
}
```

## Step 7: Initialize Firebase in main.dart
Update `lib/main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

## Step 8: Add Community Wall to Navigation
In your home page or navigation, add:
```dart
CommunityWallScreen(
  userId: userId,  // Your current user ID
  userName: userName,  // Current user name
)
```

## Step 9: Run & Test
```bash
flutter clean
flutter pub get
flutter run
```

## File Structure
```
lib/
├── models/
│   └── community_post.dart
├── services/
│   └── community_service.dart
└── screens/
    └── community_wall_screen.dart
```

## How It Works
1. **Create Post**: User enters text → Saved to Firestore with timestamp
2. **Real-time Feed**: StreamBuilder fetches posts in real-time order (newest first)
3. **Like/Unlike**: Users can like posts → List of user IDs stored in post
4. **Delete**: Only post owner can delete their own posts
5. **Time Display**: Shows relative time (e.g., "5m ago")

## Features Implemented
✅ Create posts  
✅ Real-time feed (StreamBuilder)  
✅ Like/Unlike posts  
✅ Delete posts (owner only)  
✅ User avatars with initials  
✅ Relative timestamps  
✅ Beautiful UI  

## Notes
- Currently using test mode (not production ready)
- Integrate with your existing authentication system
- Replace `userId` and `userName` with actual logged-in user data
- In production, move from test mode to production rules
