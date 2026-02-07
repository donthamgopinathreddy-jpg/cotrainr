-- Update profile with specific user data
-- Replace 'YOUR_EMAIL_HERE' with your actual email address, or use your user ID

-- Option 1: Update by email (replace with your email)
UPDATE public.profiles
SET 
  phone = '+917093028095',
  date_of_birth = '1999-09-22'::DATE,  -- 22/09/1999
  gender = 'Male',
  height_cm = 165,  -- 5'5" = 5 feet 5 inches = 65 inches = 165.1 cm (rounded to 165)
  weight_kg = 76.00,
  updated_at = NOW()
WHERE id IN (
  SELECT id FROM auth.users WHERE email = 'YOUR_EMAIL_HERE'
);

-- Option 2: Update by username (replace with your username)
-- UPDATE public.profiles
-- SET 
--   phone = '+917093028095',
--   date_of_birth = '1999-09-22'::DATE,
--   gender = 'Male',
--   height_cm = 165,
--   weight_kg = 76.00,
--   updated_at = NOW()
-- WHERE username = 'YOUR_USERNAME_HERE';

-- Option 3: Update current logged-in user (if running as authenticated user)
-- UPDATE public.profiles
-- SET 
--   phone = '+917093028095',
--   date_of_birth = '1999-09-22'::DATE,
--   gender = 'Male',
--   height_cm = 165,
--   weight_kg = 76.00,
--   updated_at = NOW()
-- WHERE id = auth.uid();

-- Verify the update
SELECT 
  id,
  username,
  email,
  phone,
  date_of_birth,
  gender,
  height_cm,
  weight_kg,
  updated_at
FROM public.profiles
WHERE phone = '+917093028095'
   OR (date_of_birth = '1999-09-22'::DATE AND gender = 'Male');
