-- Create profile for existing user if it doesn't exist
-- Replace 'YOUR_EMAIL_HERE' with your actual email address

-- Option 1: Create profile from auth.users metadata (if signup data exists)
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
  COALESCE(u.raw_user_meta_data->>'username', 'user_' || substring(u.id::text, 1, 8)),
  lower(COALESCE(u.raw_user_meta_data->>'username', 'user_' || substring(u.id::text, 1, 8))),
  COALESCE(u.raw_user_meta_data->>'full_name', ''),
  NULLIF(u.raw_user_meta_data->>'phone', ''),
  CASE 
    WHEN u.raw_user_meta_data->>'dob' IS NOT NULL 
    THEN (u.raw_user_meta_data->>'dob')::DATE
    ELSE NULL
  END,
  NULLIF(u.raw_user_meta_data->>'gender', ''),
  CASE 
    WHEN u.raw_user_meta_data->>'height_cm' IS NOT NULL 
    THEN (u.raw_user_meta_data->>'height_cm')::INTEGER
    ELSE NULL
  END,
  CASE 
    WHEN u.raw_user_meta_data->>'weight_kg' IS NOT NULL 
    THEN (u.raw_user_meta_data->>'weight_kg')::NUMERIC(5, 2)
    ELSE NULL
  END
FROM auth.users u
WHERE u.email = 'YOUR_EMAIL_HERE'  -- Replace with your email
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
  )
ON CONFLICT (id) DO NOTHING;

-- Option 2: Create profile manually with your data
-- Uncomment and replace values:
/*
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
  'YOUR_USERNAME',  -- Replace with your username
  'your_username',  -- Replace with lowercase username
  'Your Full Name',  -- Replace with your name
  '+917093028095',
  '1999-09-22'::DATE,
  'Male',
  165,  -- 5'5" in cm
  76.00
FROM auth.users u
WHERE u.email = 'YOUR_EMAIL_HERE'  -- Replace with your email
  AND NOT EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = u.id
  )
ON CONFLICT (id) DO NOTHING;
*/

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
WHERE email = 'YOUR_EMAIL_HERE';  -- Replace with your email
