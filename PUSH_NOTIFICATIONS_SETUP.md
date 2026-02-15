# Push Notifications Setup

This guide configures Firebase Cloud Messaging (FCM) for device push notifications.

**App package:** `com.example.cotrainr_flutter`

## Quick checklist (you must do these)

1. **Replace** `android/app/google-services.json` with the file you downloaded from Firebase
2. **Link Supabase** (if not done): `supabase link`
3. **Push migrations**: `supabase db push`
4. **Set Firebase secrets** in Supabase Dashboard → Project Settings → Edge Functions
5. **Deploy function**: `supabase functions deploy send-push-notification`
6. **Create Database Webhook** in Supabase Dashboard → Database → Webhooks (table: `notifications`, event: Insert)

## 1. Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a project or use an existing one
3. Enable **Cloud Messaging** (Project Settings → Cloud Messaging)

## 2. Android

1. In Firebase Console, add an **Android app** with package name: `com.example.cotrainr_flutter`
2. Download `google-services.json` and **replace** the file in `android/app/` (overwrite the placeholder)
3. The Google Services plugin is already configured in `android/app/build.gradle.kts`

## 3. iOS

1. In Firebase Console, add an **iOS app** with bundle ID: `com.example.cotrainrFlutter` (or your actual bundle ID)
2. Download `GoogleService-Info.plist` and add it to `ios/Runner/` in Xcode
3. In Xcode: **Signing & Capabilities** → add **Push Notifications** and **Background Modes** (Remote notifications)

## 4. Firebase Service Account (for Edge Function)

1. Firebase Console → Project Settings → **Service accounts**
2. Click **Generate new private key**
3. Save the JSON file securely
4. From the JSON, you need:
   - `project_id` → `FIREBASE_PROJECT_ID`
   - `client_email` → `FIREBASE_CLIENT_EMAIL`
   - `private_key` → `FIREBASE_PRIVATE_KEY` (use as-is, including `\n`)

## 5. Supabase Database

```bash
supabase db push
```

This creates the `device_tokens` table.

## 6. Deploy Edge Function

```bash
# Set secrets (replace with your values)
supabase secrets set FIREBASE_PROJECT_ID=your-project-id
supabase secrets set FIREBASE_CLIENT_EMAIL=your-service-account@project.iam.gserviceaccount.com
supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

# Deploy
supabase functions deploy send-push-notification
```

## 7. Database Webhook

1. Supabase Dashboard → **Database** → **Webhooks**
2. **Create webhook**
3. **HTTP Request** → Edge Function: `send-push-notification`, Method: POST
4. **Add auth header** with service role key
5. **Table**: `notifications`, **Events**: Insert
6. Save

## 8. Test

1. Run the app and sign in
2. Insert a row into `notifications` (Table Editor or SQL)
3. You should receive a push notification on the device
