-- Add unit preference columns to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS use_metric_height BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS use_metric_weight BOOLEAN DEFAULT true;

-- Add comment
COMMENT ON COLUMN public.profiles.use_metric_height IS 'User preference for height units: true = metric (cm), false = imperial (ft/in)';
COMMENT ON COLUMN public.profiles.use_metric_weight IS 'User preference for weight units: true = metric (kg), false = imperial (lbs)';
