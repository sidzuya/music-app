# 🚀 How to Run the MusicApp

## Quick Start

1. **Open Terminal** in the project directory:
   ```bash
   cd /Users/sidzuya/StudioProjects/music_app
   ```

2. **Install dependencies** (if not already done):
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## 📱 Testing the App

### Demo Account Creation
- Open the app and you'll see the splash screen
- Tap "Create Account" on the login screen
- Enter any email (e.g., `test@example.com`)
- Enter any username (e.g., `TestUser`)
- Enter any password (minimum 6 characters)
- Tap "Create Account"

### Features to Test

1. **Authentication Flow**
   - Register a new account
   - Login with the created account
   - Logout from profile screen

2. **Home Screen**
   - Browse recently played songs
   - Tap on quick access cards
   - View popular songs section

3. **Music Player**
   - Tap any song to start playing
   - Use the mini player at the bottom
   - Tap mini player to open full player
   - Test play/pause, skip, shuffle, repeat
   - Try seeking with the progress bar

4. **Search**
   - Search for songs by title or artist
   - Browse genres by tapping genre cards
   - View search results

5. **Library**
   - View recently played songs
   - Check playlists tab
   - Browse liked songs

6. **Profile**
   - View user profile
   - Check settings options
   - Test logout functionality

## 🎵 Sample Songs

The app comes with 5 pre-loaded sample songs:
- Blinding Lights - The Weeknd
- Watermelon Sugar - Harry Styles  
- Levitating - Dua Lipa
- Good 4 U - Olivia Rodrigo
- Stay - The Kid LAROI & Justin Bieber

## 🔧 Troubleshooting

### If you get build errors:
```bash
flutter clean
flutter pub get
flutter run
```

### If you need to reset the database:
- Uninstall the app from your device/simulator
- Run the app again (it will recreate the database)

### For iOS Simulator:
```bash
open -a Simulator
flutter run
```

### For Android Emulator:
- Start Android Studio
- Open AVD Manager
- Start an emulator
- Run `flutter run`

## 🎨 App Features Highlights

- **Beautiful Spotify-inspired UI** with dark theme
- **Smooth animations** including rotating album art
- **Real-time search** functionality
- **Local database** with SQLite
- **State management** with Provider
- **Audio playback** with just_audio
- **Persistent authentication** sessions

Enjoy exploring your new music streaming app! 🎵
