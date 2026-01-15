# Cotrainr - Project Overview

## App Purpose
Cotrainr is a modern fitness and wellness mobile app that helps users improve their fitness consistency and lifestyle through tracking, guidance, and community.

## Core Purpose
Helps users improve their fitness consistency and lifestyle through:
- **Tracking**: Daily health metrics (steps, calories, water, BMI)
- **Guidance**: Connect with fitness professionals (trainers, nutritionists)
- **Community**: Cocircle social feed for motivation and support

## Target Users

### 1. Clients (Default User)
- Track daily health metrics
- Follow workout plans
- Connect with trainers and nutritionists
- Participate in quests and challenges
- Share progress in Cocircle community

### 2. Trainers
- Monitor client progress
- Create and assign workout plans
- Conduct video sessions
- Track client metrics and achievements

### 3. Nutritionists
- Review client meals
- Create and review diet plans
- Consult with clients
- Track nutritional progress

## Main Features

### 1. Daily Health Tracking
- **Steps Tracking**: Daily step count with goals
- **Calories Tracking**: Daily calorie intake/expenditure
- **Water Tracking**: Daily water intake with reminders
- **BMI & Body Metrics**: Height, weight, BMI calculation with trends

### 2. Weekly Insights & Progress
- Analytical visuals (not simple bars)
- Weekly progress reports
- Trend analysis
- Achievement tracking

### 3. Quest System
- **Levels**: XP-based leveling system
- **Streaks**: Daily consistency tracking
- **Challenges**: Weekly and monthly challenges
- **Achievements**: Unlockable badges and rewards

### 4. Video Sessions
- Clients can join trainer video sessions
- Trainers can create and manage sessions
- Real-time coaching and feedback

### 5. Cocircle Community
- Social feed for posts, comments, and likes
- Follow trainers, nutritionists, and other users
- Share progress, workouts, and meals
- Community challenges and motivation

### 6. Discover Page
- Find trainers by specialty and location
- Find nutritionists by expertise
- Find fitness centers and gyms
- Filter by distance, rating, categories
- Map view for nearby professionals

## Roles & Permissions

### Client (Default)
- Full access to personal tracking
- Can follow trainers/nutritionists
- Can book sessions
- Can participate in quests
- Can post in Cocircle

### Trainer
- All client features +
- Monitor assigned clients
- Create workout plans
- Create and manage video sessions
- View client progress analytics

### Nutritionist
- All client features +
- Review client meals
- Create diet plans
- Consult with clients
- View nutritional analytics

## Design Philosophy

### Theme System
- **Light Theme**: Clean, bright interface
- **Dark Theme**: Easy on the eyes
- **System Theme**: Follows device preference

### Visual Design
- **Analytical Visuals**: Charts, graphs, and data visualizations instead of simple progress bars
- **Smooth Animations**: Micro-interactions and transitions
- **Cover Image & Profile**: Homepage features cover image with floating profile avatar
- **Modern UI**: Material 3 design with gradients and soft shadows

### User Experience
- Intuitive navigation
- Haptic feedback on interactions
- Pull-to-refresh on feeds
- Skeleton loaders for better perceived performance
- Error handling with helpful messages

## Tech Stack

### Frontend
- **Flutter** (Dart) - Cross-platform mobile development
- **Material 3** - Modern design system
- **Riverpod** - State management
- **GoRouter** - Navigation and routing

### Backend
- **Supabase** - Backend as a Service
  - Authentication (Email/Password, OAuth)
  - PostgreSQL Database
  - Storage (avatars, covers, posts, meal photos, workout plans)
  - Real-time subscriptions

### Data Model
- **PostgreSQL** - Relational database
- Row Level Security (RLS) for data protection
- Triggers for automatic profile creation

### Future
- Admin panel for management
- Analytics dashboard
- Push notifications

## App Architecture

### Pages Structure
1. **Splash** - Initial screen with session check
2. **Auth** - Login and 5-step signup flow
3. **Home** - Dashboard with metrics, cover image, profile
4. **Discover** - Find trainers, nutritionists, centers
5. **Quest** - Challenges, levels, streaks, leaderboard
6. **Cocircle** - Social feed, posts, comments
7. **Profile** - User profile, settings, edit info

### State Management
- **Riverpod Providers**:
  - `authProvider` - Authentication state
  - `profileProvider` - User profile data
  - `settingsProvider` - Theme and app settings
  - `metricsProvider` - Health metrics
  - `questProvider` - Quest and XP data
  - `feedProvider` - Cocircle feed data

### Data Flow
1. User actions → Riverpod providers
2. Providers → Repositories
3. Repositories → Supabase client
4. Supabase → Database/Storage
5. Real-time updates → Providers → UI

## Database Schema (Planned)

### Core Tables
- `profiles` - User profiles with role, bio, metrics
- `posts` - Cocircle posts with media
- `likes` - Post likes
- `comments` - Post comments
- `followers` - User follow relationships
- `meals` - Meal tracking entries
- `meal_items` - Individual meal items
- `workout_plans` - Trainer-created plans
- `video_sessions` - Scheduled sessions
- `quests` - Available quests/challenges
- `user_quests` - User quest progress
- `xp_history` - XP transactions
- `achievements` - Unlocked achievements

### Storage Buckets
- `avatars` - User profile pictures (public)
- `covers` - Profile cover images (public)
- `cocircle` - Post media (public)
- `meal_photos` - Meal images (public)
- `workout_plans` - Workout plan documents (private)

## Development Roadmap

### Phase 1: Foundation ✅
- [x] Project setup
- [x] Supabase configuration
- [x] Theme system
- [x] Routing structure
- [x] Auth pages (UI)

### Phase 2: Authentication (In Progress)
- [ ] Complete signup flow with backend
- [ ] Profile creation
- [ ] Session management
- [ ] Role assignment

### Phase 3: Core Features
- [ ] Home page with metrics
- [ ] Daily tracking (steps, calories, water)
- [ ] BMI calculator and trends
- [ ] Weekly insights with charts

### Phase 4: Quest System
- [ ] XP and leveling
- [ ] Streak tracking
- [ ] Challenges
- [ ] Leaderboard
- [ ] Achievements

### Phase 5: Social Features
- [ ] Cocircle feed
- [ ] Post creation with media
- [ ] Comments and likes
- [ ] Follow system
- [ ] Profile pages

### Phase 6: Professional Features
- [ ] Discover page
- [ ] Trainer/nutritionist profiles
- [ ] Video sessions
- [ ] Client monitoring (for trainers)
- [ ] Meal review (for nutritionists)

### Phase 7: Polish
- [ ] Animations and transitions
- [ ] Haptic feedback
- [ ] Error handling
- [ ] Loading states
- [ ] Offline support

## Key Differentiators

1. **Not Just a Tracker**: Focus on coaching and community
2. **Long-term Consistency**: Quest system and streaks encourage daily engagement
3. **Professional Network**: Connect with real trainers and nutritionists
4. **Analytical Insights**: Data-driven progress visualization
5. **Community Support**: Cocircle for motivation and sharing

## Success Metrics

- Daily active users
- Streak consistency
- Trainer-client connections
- Quest completion rates
- Community engagement (posts, comments, likes)





