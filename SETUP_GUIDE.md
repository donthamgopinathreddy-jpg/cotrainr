# Quick Setup Guide

## ✅ What's Done

1. **Flutter Project Created** ✓
2. **Dependencies Installed** ✓
   - supabase_flutter
   - flutter_riverpod
   - go_router
   - google_fonts
   - image_picker
   - permission_handler
   - cached_network_image
   - intl
   - flutter_svg

3. **Project Structure Created** ✓
   - Core config and services folders
   - Theme system
   - Router setup
   - Auth pages (Login, Signup)
   - Home shell with bottom nav
   - Splash screen

4. **Core Files Created** ✓
   - `lib/core/config/supabase_config.dart` - Add your Supabase credentials here
   - `lib/theme/app_theme.dart` - Light/Dark/System themes with Material 3
   - `lib/router/app_router.dart` - GoRouter setup with auth protection
   - `lib/main.dart` - App entry with Supabase initialization
   - `lib/pages/splash_page.dart` - Splash screen with session check
   - `lib/pages/auth/login_page.dart` - Login page
   - `lib/pages/auth/signup_page.dart` - 5-step signup flow (UI only)
   - `lib/pages/home/home_shell_page.dart` - Bottom navigation shell

## 🚀 Next Steps

### 1. Configure Supabase (REQUIRED)

1. Create a Supabase project at https://app.supabase.com
2. Get your project URL and anon key from Settings → API
3. Update `lib/core/config/supabase_config.dart`:
   ```dart
   static const String supabaseUrl = 'https://your-project.supabase.co';
   static const String supabaseAnonKey = 'your-anon-key-here';
   ```

### 2. Create Storage Buckets

In Supabase Dashboard → Storage, create:
- `avatars` (public)
- `covers` (public)
- `cocircle` (public)
- `meal_photos` (public)
- `workout_plans` (private)

### 3. Test the App

```bash
flutter run
```

The app should:
- Show splash screen
- Check for existing session
- Route to login if not logged in
- Route to home if logged in

### 4. Complete Signup Flow

The signup page has a 5-step UI but needs backend integration:
1. Step 1: Email, User ID, Password
2. Step 2: First Name, Last Name, Phone
3. Step 3: Role Selection (Client/Trainer/Nutritionist)
4. Step 4: Height, Weight, DOB, Gender
5. Step 5: Categories (for trainers/nutritionists)

**Important**: When implementing signup:
- Create auth user first: `supabase.auth.signUp()`
- Then manually insert profile row using returned user ID
- Disable any database triggers temporarily until stable

### 5. Build Main Screens

After auth works, build:
- Home page (cover, metrics, feed preview)
- Discover page (search, filters, map)
- Quest page (challenges, leaderboard)
- Cocircle page (social feed)
- Profile page (edit profile, settings)

### 6. Database Tables

Create tables in Supabase after UI is stable:
- `profiles`
- `posts`
- `followers`
- `meals`
- `quests`
- etc.

Then add RLS policies one table at a time.

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart  ← Add your Supabase credentials here
│   └── services/
├── pages/
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── signup_page.dart
│   ├── home/
│   │   └── home_shell_page.dart
│   ├── splash_page.dart
│   ├── discover/
│   ├── quest/
│   ├── cocircle/
│   └── profile/
├── widgets/
├── providers/
├── repositories/
├── models/
├── router/
│   └── app_router.dart
├── theme/
│   └── app_theme.dart
└── main.dart
```

## 🎨 Theme System

The app supports:
- **Light theme**: White cards, dark text
- **Dark theme**: Dark cards, light text
- **System theme**: Follows device setting

Uses Material 3 with Poppins font and orange/yellow gradient accents.

## 🔐 Auth Flow

1. Splash checks for existing session
2. If no session → Login page
3. If session exists → Home page
4. Login → Creates session → Home page
5. Signup → Creates auth user + profile → Home page

## ⚠️ Important Notes

- **Supabase credentials are required** before the app will work
- The signup flow UI is complete but needs backend integration
- All routes are protected - unauthenticated users redirect to login
- Theme mode is set to `system` by default (can be changed in `app_theme.dart`)

## 🐛 Troubleshooting

If you see import errors:
- Run `flutter pub get` again
- Restart your IDE
- Run `flutter clean && flutter pub get`

If Supabase connection fails:
- Check your URL and anon key in `supabase_config.dart`
- Ensure your Supabase project is active
- Check network connectivity

