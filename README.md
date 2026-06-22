# 🎵 MusicApp

A beautiful Spotify-inspired music streaming app built with Flutter. Features a modern dark theme, user authentication, local database storage, and full music player functionality.

## ✨ Features

### 🔐 Authentication
- User registration and login
- Local authentication with SQLite database
- Persistent login sessions
- Beautiful login/register screens with form validation

### 🎵 Music Player
- Full-featured audio player with play/pause, skip, shuffle, and repeat
- Beautiful animated album art with rotation effects
- Progress bar with seek functionality
- Volume controls and favorite songs
- Mini player in bottom navigation

### 🏠 Home Screen
- Spotify-inspired dark theme design
- Quick access cards for favorite features
- Recently played songs carousel
- Popular songs recommendations
- Dynamic greeting based on time of day

### 🔍 Search & Discovery
- Real-time song search functionality
- Browse by genre with colorful category cards
- Search results with song details
- Beautiful genre grid layout

### 📚 Library Management
- Personal music library with tabs
- Recently played songs tracking
- Playlist creation and management
- Liked songs collection
- User profile with statistics

### 🎨 Design & UI
- Spotify-inspired dark theme with green accents
- Modern Material Design 3 components
- Smooth animations and transitions
- Responsive layout for different screen sizes
- Custom widgets and reusable components

## 🛠️ Technical Stack

### Frontend
- **Flutter** - Cross-platform mobile framework
- **Provider** - State management
- **Material Design 3** - UI components

### Audio & Media
- **just_audio** - Audio playback
- **audio_video_progress_bar** - Progress indicators

### Database & Storage
- **SQLite (sqflite)** - Local database
- **shared_preferences** - User preferences storage

### UI & Fonts
- **Google Fonts** - Typography (Inter font family)
- **cached_network_image** - Image caching

### Navigation
- **go_router** - Advanced routing

## 📱 Screenshots

The app features:
- Splash screen with animated logo
- Login/Register screens with validation
- Home screen with music discovery
- Search with genre browsing
- Library with personal collections
- Full-screen music player
- Profile with user settings

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code
- iOS Simulator / Android Emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd music_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Demo Usage

For demonstration purposes:
- You can create any account with any email/password
- Sample songs are pre-loaded in the database
- Audio playback uses sample URLs for demo

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/          # App constants and configuration
│   └── theme/             # App theme and styling
├── data/
│   ├── models/            # Data models (User, Song, Playlist)
│   └── services/          # Database and authentication services
└── presentation/
    ├── providers/         # State management providers
    ├── screens/          # App screens
    │   ├── auth/         # Login/Register screens
    │   ├── home/         # Home screen
    │   ├── search/       # Search screen
    │   ├── library/      # Library screen
    │   ├── player/       # Music player screen
    │   └── profile/      # Profile screen
    └── widgets/          # Reusable UI components
```

## 🎯 Key Features Implementation

### Authentication System
- Local SQLite database for user storage
- Password validation and email verification
- Persistent login with SharedPreferences
- Secure user session management

### Music Player Engine
- Audio streaming with just_audio
- Playlist management and queue system
- Shuffle and repeat modes
- Real-time progress tracking
- Background audio support

### Database Schema
- Users table with profile information
- Songs table with metadata
- Playlists and playlist_songs junction table
- Favorites table for liked songs

### State Management
- Provider pattern for reactive UI
- AuthProvider for user authentication state
- MusicProvider for player controls and current song
- Efficient state updates and UI rebuilds

## 🔧 Customization

### Themes
The app uses a custom Spotify-inspired theme defined in `lib/core/theme/app_theme.dart`:
- Primary green color (#1DB954)
- Dark background (#121212)
- Card backgrounds (#1E1E1E)
- Text colors for hierarchy

### Adding New Features
1. Create new models in `lib/data/models/`
2. Add database operations in `lib/data/services/`
3. Create UI screens in `lib/presentation/screens/`
4. Add state management in `lib/presentation/providers/`

## 📝 Future Enhancements

- [ ] Real audio streaming integration
- [ ] Social features (follow users, share playlists)
- [ ] Offline music downloads
- [ ] Equalizer and audio effects
- [ ] Lyrics display
- [ ] Music recommendations AI
- [ ] Cloud synchronization
- [ ] Artist profiles and albums

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Spotify for design inspiration
- Flutter team for the amazing framework
- Open source audio libraries used in this project

---

**Built with ❤️ using Flutter**
