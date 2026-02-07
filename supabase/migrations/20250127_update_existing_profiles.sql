-- Migration: Update existing profiles with signup data from auth.users metadata
-- This script extracts phone, date_of_birth, gender, height_cm, weight_kg from auth.users.raw_user_meta_data
-- and updates the profiles table for existing users

-- Update profiles with data from auth.users metadata (if available)
UPDATE public.profiles p
SET 
  phone = COALESCE(
    p.phone,  -- Keep existing value if already set
    NULLIF((SELECT raw_user_meta_data->>'phone' FROM auth.users WHERE id = p.id), '')
  ),
  date_of_birth = COALESCE(
    p.date_of_birth,  -- Keep existing value if already set
    CASE 
      WHEN (SELECT raw_user_meta_data->>'dob' FROM auth.users WHERE id = p.id) IS NOT NULL 
      THEN (SELECT (raw_user_meta_data->>'dob')::DATE FROM auth.users WHERE id = p.id)
      ELSE NULL
    END
  ),
  gender = COALESCE(
    p.gender,  -- Keep existing value if already set
    NULLIF((SELECT raw_user_meta_data->>'gender' FROM auth.users WHERE id = p.id), '')
  ),
  height_cm = COALESCE(
    p.height_cm,  -- Keep existing value if already set
    CASE 
      WHEN (SELECT raw_user_meta_data->>'height_cm' FROM auth.users WHERE id = p.id) IS NOT NULL 
      THEN (SELECT (raw_user_meta_data->>'height_cm')::INTEGER FROM auth.users WHERE id = p.id)
      ELSE NULL
    END
  ),
  weight_kg = COALESCE(
    p.weight_kg,  -- Keep existing value if already set
    CASE 
      WHEN (SELECT raw_user_meta_data->>'weight_kg' FROM auth.users WHERE id = p.id) IS NOT NULL 
      THEN (SELECT (raw_user_meta_data->>'weight_kg')::NUMERIC(5, 2) FROM auth.users WHERE id = p.id)
      ELSE NULL
    END
  )
WHERE EXISTS (
  SELECT 1 FROM auth.users u 
  WHERE u.id = p.id 
  AND u.raw_user_meta_data IS NOT NULL
);

-- Verify the update
SELECT 
  id,
  username,
  phone,
  date_of_birth,
  gender,
  height_cm,
  weight_kg
FROM public.profiles
WHERE phone IS NOT NULL 
   OR date_of_birth IS NOT NULL 
   OR gender IS NOT NULL 
   OR height_cm IS NOT NULL 
   OR weight_kg IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;
