# Cotrainr Flutter - Complete App Structure Summary

## 📱 App Overview
**Cotrainr** is a role-based fitness and wellness application with three distinct user roles:
- **Client**: Regular users tracking fitness, meals, and goals
- **Trainer**: Fitness trainers managing clients and sessions
- **Nutritionist**: Nutrition experts managing clients and meal plans

---

## 🎯 Role-Based Navigation Structure

### 👤 **CLIENT ROLE**
**Navigation:** Home → Discover → Quest → Cocircle → Profile

**Dashboard:** `HomeShellPage` (`/home`)
- **Home** (`HomePageV3`)
  - Hero Header (cover image, profile, notifications)
  - Steps Card
  - Calories, Water, Distance Row
  - BMI Card
  - Quick Access (Video Sessions, Meal Tracker, AI Planner, etc.)
  
- **Discover** (`DiscoverPage`)
  - Content discovery and filtering
  
- **Quest** (`QuestPage`)
  - Daily/Weekly quests
  - Leaderboard
  - Achievements
  - XP and Leveling system
  
- **Cocircle** (`CocirclePage`)
  - Social feed
  - Create posts
  - User profiles
  
- **Profile** (`ProfilePage`)
  - Cover image and avatar
  - Stats (Steps, Streak, Level, XP)
  - Settings
  - Refer a Friend
  - Subscription
  - Become a Trainer

---

### 💪 **TRAINER ROLE**
**Navigation:** Home → My Clients → Quest → Cocircle → Profile

**Dashboard:** `TrainerDashboardPage` (`/trainer/dashboard`)
- **Home** (`TrainerHomePage`)
  - Hero Header (cover image, profile, notifications)
  - Steps, Calories, Water, Distance, BMI cards
  - Quick Access
  - Stats Cards (Total Clients, Active, Upcoming Sessions, Today Sessions)
  - Recent Activity feed
  
- **My Clients** (`TrainerMyClientsPage`)
  - Header: "MY CLIENTS" with gradient icon
  - Tabs: "My Clients" | "Pending"
  - Client cards with:
    - Avatar with status border
    - Name, email, status badge
    - Online indicator (for Active)
    - Accept button (for Pending) - gradient green/blue
    - Navigate to client detail page
  
- **Quest** (`TrainerQuestPage`)
  - Same structure as client Quest
  - Header: "QUESTS"
  
- **Cocircle** (`TrainerCocirclePage`)
  - Same structure as client Cocircle
  - Header: "COCIRCLE"
  
- **Profile** (`TrainerProfilePage`)
  - Cover image and avatar
  - Stats
  - Verification Card (if not verified)
  - Settings
  - Refer a Friend
  - My Clients button
  - NO Subscription or Become a Trainer

---

### 🥗 **NUTRITIONIST ROLE**
**Navigation:** Home → My Clients → Quest → Cocircle → Profile

**Dashboard:** `NutritionistDashboardPage` (`/nutritionist/dashboard`)
- **Home** (`NutritionistHomePage`)
  - Hero Header (cover image, profile, notifications)
  - Steps, Calories, Water, Distance, BMI cards
  - Quick Access
  - Stats Cards (Total Clients, Active, Upcoming Consultations, Today Consultations)
  - Recent Activity feed
  
- **My Clients** (`NutritionistMyClientsPage`)
  - Header: "MY CLIENTS" with gradient icon
  - Tabs: "My Clients" | "Pending"
  - Client cards with Accept button for pending requests
  
- **Quest** (`NutritionistQuestPage`)
  - Same structure as client Quest
  - Header: "QUESTS"
  
- **Cocircle** (`NutritionistCocirclePage`)
  - Same structure as client Cocircle
  - Header: "COCIRCLE"
  
- **Profile** (`NutritionistProfilePage`)
  - Cover image and avatar
  - Stats
  - Verification Card (if not verified)
  - Settings
  - Refer a Friend
  - My Clients button
  - NO Subscription or Become a Trainer

---

## 📄 Complete Page Structure

### 🔐 **Authentication Pages** (`lib/pages/auth/`)
- `welcome_page.dart` - Welcome screen
- `welcome_animation_page.dart` - Animated welcome
- `login_page.dart` - Login with email/password
- `signup_wizard_page.dart` - Multi-step signup flow
  - Step 1: Credentials (User ID, Email, Password, Confirm Password)
  - Step 2: Personal Info (First Name, Last Name, Phone)
  - Step 3: About You (Date of Birth, Gender, Age)
  - Step 4: Height & Weight (with unit toggles)
  - Step 5: Preferences & Role (Goals, Categories, Role Selection)

### 🏠 **Client Pages** (`lib/pages/home/`)
- `home_shell_page.dart` - Main navigation shell for clients
- `home_page_v3.dart` - Client home page with metrics
- `home_page.dart` - Legacy home page

### 🔍 **Discover** (`lib/pages/discover/`)
- `discover_page.dart` - Content discovery page

### 🎯 **Quest** (`lib/pages/quest/`)
- `quest_page.dart` - Main quest page (used by clients)
  - Daily quests
  - Weekly quests
  - Leaderboard
  - Achievements

### 👥 **Cocircle** (`lib/pages/cocircle/`)
- `cocircle_page.dart` - Main social feed (used by clients)
- `cocircle_create_post_page.dart` - Create new post
- `user_profile_page.dart` - User profile in Cocircle
- `image_crop_page.dart` - Image cropping for posts

### 📊 **Profile** (`lib/pages/profile/`)
- `profile_page.dart` - Main profile page (used by clients)
- `edit_profile_page.dart` - Edit profile information
- `settings_page.dart` - App settings
- `settings/notifications_page.dart` - Notification settings
- `settings/privacy_security_page.dart` - Privacy & security
- `settings/info_pages.dart` - Help, FAQ, Terms, Privacy Policy

### 💪 **Trainer Pages** (`lib/pages/trainer/`)
- `trainer_dashboard_page.dart` - Main navigation shell
- `trainer_home_page.dart` - Trainer home with stats
- `trainer_my_clients_page.dart` - Client management
- `trainer_quest_page.dart` - Trainer quest page
- `trainer_cocircle_page.dart` - Trainer social feed
- `trainer_profile_page.dart` - Trainer profile
- `client_detail_page.dart` - Detailed client view
  - Expandable sections: Daily Metrics, Meal Tracker, Goals, Video Sessions
- `create_client_page.dart` - Legacy (now replaced by trainer_my_clients_page)
- `become_trainer_page.dart` - Apply to become a trainer
- `verification_submission_page.dart` - Submit verification documents

### 🥗 **Nutritionist Pages** (`lib/pages/nutritionist/`)
- `nutritionist_dashboard_page.dart` - Main navigation shell
- `nutritionist_home_page.dart` - Nutritionist home with stats
- `nutritionist_my_clients_page.dart` - Client management
- `nutritionist_quest_page.dart` - Nutritionist quest page
- `nutritionist_cocircle_page.dart` - Nutritionist social feed
- `nutritionist_profile_page.dart` - Nutritionist profile

### 📈 **Insights** (`lib/pages/insights/`)
- `insights_detail_page.dart` - Detailed metric insights
- `steps_insights_page.dart` - Steps analytics
- `calories_insights_page.dart` - Calories analytics
- `water_insights_page.dart` - Water intake analytics
- `distance_insights_page.dart` - Distance analytics
- `weekly_insights_page.dart` - Weekly health metrics overview (Steps, Calories, Water, Distance)

### 🍽️ **Meal Tracker** (`lib/pages/meal_tracker/`)
- `meal_tracker_page_v2.dart` - Main meal tracking page
- `meal_tracker_page.dart` - Legacy meal tracker
- `weekly_insights_page.dart` - Weekly meal insights (food data, charts, macros) - **Different from insights/weekly_insights_page.dart**

### 💬 **Messaging** (`lib/pages/messaging/`)
- `messaging_page.dart` - Messages list
- `chat_screen.dart` - Individual chat conversation

### 🔔 **Notifications** (`lib/pages/notifications/`)
- `notification_page.dart` - All notifications

### 📹 **Video Sessions** (`lib/pages/video_sessions/`)
- `video_sessions_page.dart` - List of video sessions
- `create_meeting_page.dart` - Create new meeting
- `join_meeting_page.dart` - Join existing meeting
- `meeting_room_page.dart` - Active video call room

### 🔗 **Other Pages**
- `refer/refer_friend_page.dart` - Referral program
- `help/` - Help center, FAQ, Terms, Privacy, etc.
- `splash_page.dart` - Splash screen

---

## 🛣️ Route Structure

### Public Routes (No Auth Required)
- `/welcome` - Welcome page
- `/auth/login` - Login page
- `/auth/create-account` - Signup wizard
- `/welcome-animation` - Welcome animation

### Client Routes
- `/home` - Client dashboard (HomeShellPage)
  - Contains: Home, Discover, Quest, Cocircle, Profile

### Trainer Routes
- `/trainer/dashboard` - Trainer dashboard (TrainerDashboardPage)
  - Contains: Home, My Clients, Quest, Cocircle, Profile
- `/trainer/become` - Become a trainer application
- `/clients/:id` - Client detail page (standardized route)

### Nutritionist Routes
- `/nutritionist/dashboard` - Nutritionist dashboard (NutritionistDashboardPage)
  - Contains: Home, My Clients, Quest, Cocircle, Profile

### Shared Routes
- `/notifications` - Notifications page
- `/messaging` - Messages list
- `/messaging/chat/:userId` - Individual chat
- `/meal-tracker` - Meal tracking
- `/insights/steps` - Steps insights
- `/insights/water` - Water insights
- `/insights/calories` - Calories insights
- `/insights/distance` - Distance insights
- `/quest` - Quest page (standalone)
- `/video` - Video sessions list (role-aware via query param: `?role=client|trainer|nutritionist`)
- `/video/create` - Create meeting (role-aware via query param)
- `/video/join` - Join meeting (accepts `meetingId` + optional `passcode`)
- `/video/room/:meetingId` - Meeting room (requires `meetingId`)
- `/refer` - Refer a friend
- `/verification` - Verification submission (Trainer/Nutritionist only)

---

## 🎨 Design System

### Color Gradients by Feature
- **Primary/Orange**: `[#FF7A00, #FFC300]` - Home, general actions
- **My Clients**: `[#3ED598, #4DA3FF]` - Green to Blue
- **Quest**: `[#FFD93D, #FF5A5A]` - Yellow to Red
- **Cocircle**: `[#4DA3FF, #8B5CF6]` - Blue to Purple
- **Profile**: `[#FF5A5A, #FF8A7A]` - Red to Pink

### Typography
- **Headers**: `GoogleFonts.montserrat` - Bold, 30px, letter-spacing 1.2
- **Body**: System font with DesignTokens sizing
- **Quest Headers**: Montserrat w900

---

## 🔑 Key Features by Role

### Client Features
- ✅ Health metrics tracking (Steps, Calories, Water, Distance, BMI)
- ✅ Meal tracking and logging
- ✅ Quest system with XP and levels
- ✅ Social feed (Cocircle)
- ✅ Video sessions with trainers/nutritionists
- ✅ Discover content
- ✅ Subscription management
- ✅ Apply to become a trainer

### Trainer Features
- ✅ All client features (own health tracking)
- ✅ Client management (My Clients page)
- ✅ Client detail view with metrics
- ✅ Video sessions with clients
- ✅ Direct messaging with clients
- ✅ Verification system (submit documents)
- ❌ No Discover page
- ❌ No Subscription
- ❌ No "Become a Trainer"

### Nutritionist Features
- ✅ All client features (own health tracking)
- ✅ Client management (My Clients page)
- ✅ Client detail view with metrics
- ✅ Video consultations with clients
- ✅ Direct messaging with clients
- ✅ Verification system (submit documents)
- ❌ No Discover page
- ❌ No Subscription
- ❌ No "Become a Trainer"

---

## 📦 Widget Structure

### Reusable Widgets (`lib/widgets/`)
- **home_v3/**: Hero header, Steps card, Macro row, BMI card, Quick access
- **common/**: Pressable cards, animated cards, gradient icons
- **cocircle/**: Feed cards, create FAB
- **discover/**: Content cards, search bars, filters
- **quest/**: Quest cards, level badges, progress indicators

---

## 🔄 Navigation Flow

### After Signup
1. User completes signup wizard
2. Role selected (Client/Trainer/Nutritionist)
3. Redirect based on role:
   - Client → `/home`
   - Trainer → `/trainer/dashboard`
   - Nutritionist → `/nutritionist/dashboard`

### Client Detail Flow (Trainer/Nutritionist)
1. My Clients page → Click client card
2. Navigate to `/client/:clientId`
3. Client Detail Page with expandable sections:
   - Daily Metrics (Steps, Calories, Water, Distance, BMI)
   - Meal Tracker
   - Goals & Targets
   - Video Sessions
4. Can message or view sessions directly

---

## 🎯 Role-Specific Page Differences

| Feature | Client | Trainer | Nutritionist |
|---------|--------|---------|--------------|
| **Navigation** | Home, Discover, Quest, Cocircle, Profile | Home, My Clients, Quest, Cocircle, Profile | Home, My Clients, Quest, Cocircle, Profile |
| **Home Page** | Standard home | Trainer stats + activity | Nutritionist stats + activity |
| **Quest Page** | QuestPage | TrainerQuestPage | NutritionistQuestPage |
| **Cocircle Page** | CocirclePage | TrainerCocirclePage | NutritionistCocirclePage |
| **Profile Page** | ProfilePage | TrainerProfilePage | NutritionistProfilePage |
| **My Clients** | ❌ | ✅ TrainerMyClientsPage | ✅ NutritionistMyClientsPage |
| **Client Detail** | ❌ | ✅ ClientDetailPage | ✅ ClientDetailPage |
| **Verification** | ❌ | ✅ VerificationSubmissionPage | ✅ VerificationSubmissionPage |
| **Discover** | ✅ | ❌ | ❌ |
| **Subscription** | ✅ | ❌ | ❌ |
| **Become Trainer** | ✅ | ❌ | ❌ |

---

## 📝 Notes

- All role-specific pages maintain the same design language
- Headers use gradient icons and text matching navigation colors
- Quest and Cocircle pages have role-specific branding but same functionality
- Client detail page uses expandable dropdown sections for easy navigation
- Quick Access section filters items based on user role

## 🔒 Verification Gating Rules

### Trainer & Nutritionist Verification Status
Verification status is stored in user metadata (`user_metadata['verification_status']`):
- `null` or missing: Not verified (needs verification)
- `'pending'`: Documents submitted, awaiting review (24hr wait)
- `'verified'`: Fully verified and active

### Access Rules
1. **Home Page**: ✅ Always accessible (can view own stats)
2. **My Clients Page**: 
   - ✅ View existing clients: Always accessible
   - ⚠️ Accept new clients: Only when `verification_status == 'verified'`
   - ⚠️ View client details: Only when `verification_status == 'verified'`
3. **Quest, Cocircle, Profile**: ✅ Always accessible
4. **Video Sessions**: ✅ Always accessible (can create/join sessions)
5. **Verification Submission**: ✅ Always accessible (can submit documents)

### UI Indicators
- **Verification Card** appears in Profile page when `verification_status != 'verified'`
- Card shows different states:
  - "Verify Account" button → Not submitted
  - "Pending Verification" message → Submitted, awaiting review
- After submission, shows: "Documents submitted. Please wait up to 24 hours for verification."

---

## 🗂️ File Organization

```
lib/
├── pages/
│   ├── auth/              # Authentication
│   ├── home/              # Client home pages
│   ├── trainer/           # Trainer-specific pages
│   ├── nutritionist/      # Nutritionist-specific pages
│   ├── quest/             # Quest system (client version)
│   ├── cocircle/          # Social feed (client version)
│   ├── profile/           # Profile (client version)
│   ├── discover/          # Content discovery
│   ├── insights/          # Health metrics insights
│   ├── meal_tracker/      # Meal tracking
│   ├── messaging/         # Chat and messaging
│   ├── notifications/     # Notifications
│   ├── video_sessions/    # Video calls
│   ├── refer/             # Referral program
│   └── help/              # Help and support
├── widgets/               # Reusable UI components
├── theme/                 # Design tokens, colors, themes
├── router/                # Navigation and routing
├── services/              # Business logic services
├── providers/             # State management
├── models/                # Data models
└── utils/                 # Utility functions
```

---

**Last Updated:** Based on current codebase structure
**Total Pages:** ~50+ pages across all roles
**Navigation Items:** 5 per role (different for each role)
