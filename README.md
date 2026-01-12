# Cotrainr Flutter App

A modern fitness app built with Flutter, Supabase, and Riverpod.

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (Auth, Postgres, Storage)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **UI**: Material 3, Poppins font, Light/Dark/System theme support

## Setup Instructions

### Step 1: Supabase Setup

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Create a new project
3. Get your project URL and anon key from:
   - Settings → API
4. Update `lib/core/config/supabase_config.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
   ```

### Step 2: Supabase Configuration

#### Storage Buckets
Create these buckets in Supabase Storage:
- `avatars` (public)
- `covers` (public)
- `cocircle` (public)
- `meal_photos` (public)
- `workout_plans` (private)

#### Database Tables
Create tables after the Flutter app is running:
- `profiles`
- `posts`
- `followers`
- `meals`
- `quests`
- etc.

**Note**: Enable RLS (Row Level Security) and add policies after tables are stable.

### Step 3: Run the App

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── config/          # Configuration files (Supabase, etc.)
│   └── services/        # Core services (Storage, Permissions)
├── pages/
│   ├── auth/            # Login, Signup pages
│   ├── home/            # Home shell with bottom nav
│   ├── discover/        # Discover trainers/nutritionists/centers
│   ├── quest/           # Quest system, challenges, leaderboard
│   ├── cocircle/        # Social feed
│   └── profile/         # User profile
├── widgets/             # Reusable widgets
├── providers/           # Riverpod providers
├── repositories/        # Data repositories
├── models/              # Data models
├── router/              # GoRouter configuration
└── theme/               # App themes (light/dark)
```

## Development Roadmap

### ✅ Completed
- [x] Project structure setup
- [x] Core dependencies added
- [x] Supabase initialization
- [x] Theme system (Light/Dark/System)
- [x] Routing structure
- [x] Splash screen
- [x] Login page
- [x] Signup page (5-step flow - UI only)
- [x] Home shell with bottom navigation

### 🚧 In Progress
- [ ] Complete signup flow with Supabase integration
- [ ] Fix signup error handling
- [ ] Build main app screens

### 📋 Next Steps
1. Complete signup flow (connect to Supabase)
2. Build Home page UI
3. Build Discover page
4. Build Quest page
5. Build Cocircle page
6. Build Profile page
7. Create database tables
8. Add RLS policies
9. Final polish (animations, haptics, error handling)

## Important Notes

### Signup Error Handling
The signup flow should:
1. Create auth user in Supabase Auth
2. Manually insert profile row using the returned user ID
3. Disable any custom triggers temporarily until stable
4. Re-enable triggers only after testing

### Theme System
- Supports Light, Dark, and System theme modes
- Uses Material 3 design
- Poppins font via Google Fonts
- Orange/Yellow gradient accents
- Cards use shadows and subtle gradients (no borders)

## Dependencies

- `supabase_flutter`: Backend integration
- `flutter_riverpod`: State management
- `go_router`: Navigation
- `google_fonts`: Poppins font
- `image_picker`: Media selection
- `permission_handler`: Permissions
- `cached_network_image`: Image caching
- `intl`: Internationalization
- `flutter_svg`: SVG support

## License

Private project - All rights reserved
