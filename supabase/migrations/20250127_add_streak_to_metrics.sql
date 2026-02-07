-- Add streak_days column to metrics_daily table
ALTER TABLE public.metrics_daily
ADD COLUMN IF NOT EXISTS streak_days INTEGER DEFAULT 0;

-- Create index for faster streak queries
CREATE INDEX IF NOT EXISTS idx_metrics_daily_user_streak 
ON public.metrics_daily(user_id, date DESC) 
WHERE streak_days > 0;
