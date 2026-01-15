# Implementation Plan - Cotrainr

Based on the project overview, here's the step-by-step implementation plan.

## Current Status ✅

- [x] Flutter project setup
- [x] Supabase configuration
- [x] Theme system (Light/Dark/System)
- [x] Routing with GoRouter
- [x] Auth pages UI (Login, Signup)
- [x] Home shell with bottom navigation
- [x] GitHub repository setup

## Next Steps - Priority Order

### 1. Complete Authentication Flow 🔐

**Tasks:**
- [ ] Implement 5-step signup flow with Supabase
  - Step 1: Email, User ID, Password validation
  - Step 2: First Name, Last Name, Phone (India format)
  - Step 3: Role selection (Client/Trainer/Nutritionist)
  - Step 4: Height, Weight, DOB, Gender (wheel selectors)
  - Step 5: Categories (for trainers/nutritionists)
- [ ] Create profile in database after auth signup
- [ ] Handle signup errors gracefully
- [ ] Add email verification flow
- [ ] Implement forgot password

**Files to Create/Update:**
- `lib/repositories/auth_repository.dart`
- `lib/repositories/profile_repository.dart`
- `lib/providers/auth_provider.dart`
- `lib/pages/auth/signup_page.dart` (complete implementation)

**Database:**
- Create `profiles` table with all required fields
- Set up RLS policies for profiles

---

### 2. Build Home Page Dashboard 🏠

**Features:**
- [ ] Cover image header with parallax effect
- [ ] Floating profile avatar with border
- [ ] Notification bell with badge
- [ ] Steps card with line chart (7-day trend)
- [ ] Calories card with weekly mini indicators
- [ ] Water card with progress bar
- [ ] BMI card with circular multi-segment chart
- [ ] Quick actions carousel (Challenges, Meal Tracker, Video Session)
- [ ] Cocircle feed preview (3-5 recent posts)
- [ ] Nearby places preview

**Files to Create:**
- `lib/pages/home/home_page.dart`
- `lib/widgets/home/cover_header_widget.dart`
- `lib/widgets/home/steps_card_widget.dart`
- `lib/widgets/home/calories_card_widget.dart`
- `lib/widgets/home/water_card_widget.dart`
- `lib/widgets/home/bmi_card_widget.dart`
- `lib/widgets/home/quick_actions_carousel.dart`
- `lib/widgets/home/feed_preview_widget.dart`
- `lib/widgets/home/nearby_places_widget.dart`

**Dependencies to Add:**
- `fl_chart` - For charts and graphs
- `sensors_plus` or `pedometer` - For step tracking (optional)

---

### 3. Daily Metrics Tracking 📊

**Features:**
- [ ] Steps tracking (from device or manual entry)
- [ ] Calories tracking (manual entry + meal tracker integration)
- [ ] Water tracking (quick add +250ml button)
- [ ] BMI calculation and history
- [ ] Streak calculation (day counts if 2 of 3 goals met)

**Files to Create:**
- `lib/services/metrics_service.dart`
- `lib/providers/metrics_provider.dart`
- `lib/models/daily_metrics.dart`
- `lib/repositories/metrics_repository.dart`

**Database:**
- Create `daily_metrics` table
- Create `bmi_history` table

---

### 4. Weekly Insights & Analytics 📈

**Features:**
- [ ] Weekly progress charts
- [ ] Trend analysis (7-day, 30-day)
- [ ] Achievement highlights
- [ ] Goal completion rates

**Files to Create:**
- `lib/pages/weekly_insights_page.dart`
- `lib/widgets/analytics/weekly_chart_widget.dart`
- `lib/widgets/analytics/trend_indicator_widget.dart`

**Dependencies:**
- `fl_chart` - Already added for charts

---

### 5. Quest System 🎮

**Features:**
- [ ] XP system and leveling
- [ ] Daily streak tracking
- [ ] Challenges (Daily, Weekly, Monthly)
- [ ] Leaderboard
- [ ] Achievements/Badges

**Files to Create:**
- `lib/pages/quest/quest_page.dart`
- `lib/pages/quest/daily_quests_tab.dart`
- `lib/pages/quest/weekly_quests_tab.dart`
- `lib/pages/quest/challenges_tab.dart`
- `lib/pages/quest/leaderboard_tab.dart`
- `lib/pages/quest/achievements_tab.dart`
- `lib/providers/quest_provider.dart`
- `lib/models/quest.dart`
- `lib/models/achievement.dart`

**Database:**
- Create `quests` table
- Create `user_quests` table
- Create `xp_history` table
- Create `achievements` table
- Create `user_achievements` table

---

### 6. Cocircle Community Feed 👥

**Features:**
- [ ] Infinite scroll feed
- [ ] Post creation with media picker
- [ ] Image/video cropping
- [ ] Like, comment, share
- [ ] Follow/unfollow
- [ ] User profiles
- [ ] Search by User ID or name
- [ ] Filter by role (All, Clients, Trainers, Nutritionists)

**Files to Create:**
- `lib/pages/cocircle/cocircle_feed_page.dart`
- `lib/pages/cocircle/create_post_page.dart`
- `lib/pages/cocircle/profile_page.dart`
- `lib/widgets/cocircle/post_card.dart`
- `lib/widgets/cocircle/media_picker_card.dart`
- `lib/widgets/cocircle/comment_sheet.dart`
- `lib/providers/feed_provider.dart`
- `lib/repositories/posts_repository.dart`
- `lib/models/post.dart`

**Dependencies to Add:**
- `crop_your_image` or `image_cropper` - For image cropping
- `video_player` - For video preview

**Database:**
- Create `posts` table
- Create `likes` table
- Create `comments` table
- Create `followers` table

---

### 7. Discover Page 🔍

**Features:**
- [ ] Search bar with filters
- [ ] Segmented tabs (Trainers, Nutritionists, Centers)
- [ ] Result cards with avatar, rating, distance
- [ ] Map view with markers
- [ ] Filter bottom sheet (distance, rating, categories)
- [ ] Profile detail pages

**Files to Create:**
- `lib/pages/discover/discover_page.dart`
- `lib/pages/discover/map_view_page.dart`
- `lib/pages/discover/profile_detail_page.dart`
- `lib/widgets/discover/search_bar_pill.dart`
- `lib/widgets/discover/discover_tabs.dart`
- `lib/widgets/discover/result_card.dart`
- `lib/widgets/discover/filter_sheet.dart`
- `lib/providers/discover_provider.dart`
- `lib/repositories/discover_repository.dart`

**Dependencies to Add:**
- `google_maps_flutter` or `mapbox_maps_flutter` - For map view
- `geolocator` - For location services

---

### 8. Video Sessions 📹

**Features:**
- [ ] Create session (trainers)
- [ ] Join session (clients)
- [ ] Session list
- [ ] Session history

**Files to Create:**
- `lib/pages/video_sessions/video_sessions_page.dart`
- `lib/pages/video_sessions/create_session_page.dart`
- `lib/pages/video_sessions/session_detail_page.dart`
- `lib/providers/sessions_provider.dart`

**Dependencies to Add:**
- `agora_rtc_engine` or `zego_express_engine` - For video calls

**Database:**
- Create `video_sessions` table

---

### 9. Profile & Settings ⚙️

**Features:**
- [ ] Edit profile (name, bio, phone, etc.)
- [ ] Cover image picker
- [ ] Avatar picker
- [ ] Body metrics editing
- [ ] Theme toggle (Light/Dark/System)
- [ ] Settings page
- [ ] Help center
- [ ] Logout

**Files to Create:**
- `lib/pages/profile/profile_page.dart`
- `lib/pages/profile/edit_profile_page.dart`
- `lib/pages/profile/settings_page.dart`
- `lib/providers/settings_provider.dart`
- `lib/services/storage_service.dart` - For image uploads

---

### 10. Meal Tracker 🍽️

**Features:**
- [ ] Add meal entries
- [ ] Photo upload
- [ ] Calorie calculation
- [ ] Meal history
- [ ] Nutritionist review (for nutritionists)

**Files to Create:**
- `lib/pages/meal_tracker/meal_tracker_page.dart`
- `lib/pages/meal_tracker/add_meal_page.dart`
- `lib/providers/meal_provider.dart`
- `lib/repositories/meals_repository.dart`

**Database:**
- Already created `meals` and `meal_items` tables

---

## Database Schema Design

### Profiles Table
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  user_id TEXT UNIQUE NOT NULL,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  role TEXT CHECK (role IN ('client', 'trainer', 'nutritionist')),
  avatar_url TEXT,
  cover_url TEXT,
  bio TEXT,
  height_cm INTEGER,
  weight_kg DECIMAL,
  date_of_birth DATE,
  gender TEXT,
  categories TEXT[], -- For trainers/nutritionists
  experience_years INTEGER, -- For trainers/nutritionists
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Daily Metrics Table
```sql
CREATE TABLE daily_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  date DATE NOT NULL,
  steps INTEGER DEFAULT 0,
  calories INTEGER DEFAULT 0,
  water_ml INTEGER DEFAULT 0,
  streak_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, date)
);
```

### Posts Table
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  content TEXT,
  media_urls TEXT[],
  tags TEXT[],
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

*(Add more table schemas as needed)*

---

## Priority Implementation Order

1. **Week 1**: Complete Auth + Home Page
2. **Week 2**: Daily Metrics + Weekly Insights
3. **Week 3**: Quest System
4. **Week 4**: Cocircle Feed
5. **Week 5**: Discover Page
6. **Week 6**: Video Sessions + Meal Tracker
7. **Week 7**: Profile & Settings + Polish

---

## Notes

- **Service Role Key**: The token `ltc1qs49erv7pzeczp5qlnxd46aufzapsmzpa7y73ct` should NOT be stored in the client app. It's for server-side operations only (admin panel, backend functions).

- **RLS Policies**: Enable Row Level Security on all tables and create policies carefully to ensure data privacy.

- **Storage**: Set up all storage buckets before implementing features that require file uploads.

- **Testing**: Test each feature thoroughly before moving to the next, especially authentication and data persistence.





