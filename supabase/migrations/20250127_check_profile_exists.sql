-- Check if your profile exists and verify RLS policies
-- Run this in Supabase SQL Editor to diagnose the issue

-- 1. Check if profile exists for your user
SELECT 
  id,
  username,
  email,
  full_name,
  phone,
  date_of_birth,
  gender,
  height_cm,
  weight_kg,
  created_at
FROM public.profiles
WHERE email = 'YOUR_EMAIL_HERE';  -- Replace with your email

-- 2. Check if user exists in auth.users
SELECT 
  id,
  email,
  raw_user_meta_data->>'username' as username_meta,
  raw_user_meta_data->>'phone' as phone_meta,
  raw_user_meta_data->>'dob' as dob_meta,
  raw_user_meta_data->>'gender' as gender_meta,
  raw_user_meta_data->>'height_cm' as height_meta,
  raw_user_meta_data->>'weight_kg' as weight_meta,
  created_at
FROM auth.users
WHERE email = 'YOUR_EMAIL_HERE';  -- Replace with your email

-- 3. Check RLS policies on profiles table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles';

-- 4. Test if you can read your own profile (replace with your user ID)
-- Get your user ID from the first query above, then run:
-- SELECT * FROM public.profiles WHERE id = 'YOUR_USER_ID_HERE';
