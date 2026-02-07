-- Check your profile data to see what's stored
-- Replace with your user ID: 234d72dd-2ac9-485d-8e53-cc1ac6049860

SELECT 
  id,
  username,
  email,
  full_name,
  avatar_url,
  cover_url,
  phone,
  date_of_birth,
  gender,
  height_cm,
  weight_kg,
  created_at,
  updated_at
FROM public.profiles
WHERE id = '234d72dd-2ac9-485d-8e53-cc1ac6049860';

-- If you want to update your full_name, run this (replace with your actual name):
/*
UPDATE public.profiles
SET full_name = 'Your First Name Your Last Name'
WHERE id = '234d72dd-2ac9-485d-8e53-cc1ac6049860';
*/
