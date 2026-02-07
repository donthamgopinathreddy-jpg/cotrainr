-- Create profile for user: 234d72dd-2ac9-485d-8e53-cc1ac6049860
-- This script will create the profile from auth.users metadata if available

-- First, check if user exists and what metadata they have
SELECT 
  id,
  email,
  raw_user_meta_data->>'username' as username_meta,
  raw_user_meta_data->>'full_name' as full_name_meta,
  raw_user_meta_data->>'phone' as phone_meta,
  raw_user_meta_data->>'dob' as dob_meta,
  raw_user_meta_data->>'gender' as gender_meta,
  raw_user_meta_data->>'height_cm' as height_meta,
  raw_user_meta_data->>'weight_kg' as weight_meta,
  created_at
FROM auth.users
WHERE id = '234d72dd-2ac9-485d-8e53-cc1ac6049860';

-- Create profile from auth.users metadata
INSERT INTO public.profiles (
  id,
  role,
  email,
  username,
  username_lower,
  full_name,
  phone,
  date_of_birth,
  gender,
  height_cm,
  weight_kg
)
SELECT 
  u.id,
  'client'::public.user_role,
  u.email,
  COALESCE(
    u.raw_user_meta_data->>'username',
    'user_' || substring(u.id::text, 1, 8)
  ) as username,
  lower(COALESCE(
    u.raw_user_meta_data->>'username',
    'user_' || substring(u.id::text, 1, 8)
  )) as username_lower,
  COALESCE(u.raw_user_meta_data->>'full_name', '') as full_name,
  NULLIF(u.raw_user_meta_data->>'phone', '') as phone,
  CASE 
    WHEN u.raw_user_meta_data->>'dob' IS NOT NULL 
      AND u.raw_user_meta_data->>'dob' != ''
    THEN (u.raw_user_meta_data->>'dob')::DATE
    ELSE NULL
  END as date_of_birth,
  NULLIF(u.raw_user_meta_data->>'gender', '') as gender,
  CASE 
    WHEN u.raw_user_meta_data->>'height_cm' IS NOT NULL 
      AND u.raw_user_meta_data->>'height_cm' != ''
    THEN (u.raw_user_meta_data->>'height_cm')::INTEGER
    ELSE NULL
  END as height_cm,
  CASE 
    WHEN u.raw_user_meta_data->>'weight_kg' IS NOT NULL 
      AND u.raw_user_meta_data->>'weight_kg' != ''
    THEN (u.raw_user_meta_data->>'weight_kg')::NUMERIC(5, 2)
    ELSE NULL
  END as weight_kg
FROM auth.users u
WHERE u.id = '234d72dd-2ac9-485d-8e53-cc1ac6049860'
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
  )
ON CONFLICT (id) DO NOTHING;

-- Verify the profile was created
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
WHERE id = '234d72dd-2ac9-485d-8e53-cc1ac6049860';
