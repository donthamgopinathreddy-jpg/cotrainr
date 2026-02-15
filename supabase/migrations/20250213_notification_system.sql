-- =========================================
-- NOTIFICATION SYSTEM
-- =========================================
-- 1. Add notification preferences to profiles
-- 2. Triggers for likes, follows, comments
-- 3. RPC to create notifications (for achievements, reminders)
-- =========================================

-- 1. Add notification preference columns to profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_push BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notification_community BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notification_reminders BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notification_achievements BOOLEAN NOT NULL DEFAULT true;

-- 2. Function: create notification on post like
CREATE OR REPLACE FUNCTION public.notify_on_post_like()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id UUID;
  v_liker_username TEXT;
  v_liker_name TEXT;
BEGIN
  -- Don't notify if user likes their own post
  IF NEW.user_id = (SELECT author_id FROM public.posts WHERE id = NEW.post_id) THEN
    RETURN NEW;
  END IF;

  SELECT author_id INTO v_author_id FROM public.posts WHERE id = NEW.post_id;
  IF v_author_id IS NULL THEN RETURN NEW; END IF;

  SELECT username, full_name INTO v_liker_username, v_liker_name
  FROM public.profiles WHERE id = NEW.user_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_author_id,
    'like',
    COALESCE(v_liker_name, v_liker_username, 'Someone') || ' liked your post',
    COALESCE(v_liker_name, v_liker_username, 'Someone') || ' liked your post',
    jsonb_build_object('actor_id', NEW.user_id, 'post_id', NEW.post_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_post_like ON public.post_likes;
CREATE TRIGGER trg_notify_on_post_like
  AFTER INSERT ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_like();

-- 3. Function: create notification on post comment
CREATE OR REPLACE FUNCTION public.notify_on_post_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_author_id UUID;
  v_commenter_username TEXT;
  v_commenter_name TEXT;
  v_preview TEXT;
BEGIN
  -- Don't notify if user comments on their own post
  SELECT author_id INTO v_author_id FROM public.posts WHERE id = NEW.post_id;
  IF v_author_id IS NULL OR v_author_id = NEW.author_id THEN
    RETURN NEW;
  END IF;

  SELECT username, full_name INTO v_commenter_username, v_commenter_name
  FROM public.profiles WHERE id = NEW.author_id;

  v_preview := LEFT(NEW.content, 80);
  IF LENGTH(NEW.content) > 80 THEN v_preview := v_preview || '...'; END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_author_id,
    'comment',
    COALESCE(v_commenter_name, v_commenter_username, 'Someone') || ' commented on your post',
    v_preview,
    jsonb_build_object('actor_id', NEW.author_id, 'post_id', NEW.post_id, 'comment_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_post_comment ON public.post_comments;
CREATE TRIGGER trg_notify_on_post_comment
  AFTER INSERT ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_comment();

-- 4. Function: create notification on follow
CREATE OR REPLACE FUNCTION public.notify_on_follow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_follower_username TEXT;
  v_follower_name TEXT;
BEGIN
  SELECT username, full_name INTO v_follower_username, v_follower_name
  FROM public.profiles WHERE id = NEW.follower_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.following_id,
    'following',
    COALESCE(v_follower_name, v_follower_username, 'Someone') || ' started following you',
    COALESCE(v_follower_name, v_follower_username, 'Someone') || ' started following you',
    jsonb_build_object('actor_id', NEW.follower_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_follow ON public.user_follows;
CREATE TRIGGER trg_notify_on_follow
  AFTER INSERT ON public.user_follows
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_follow();

-- 5. Function: create notification on quest completion
CREATE OR REPLACE FUNCTION public.notify_on_quest_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title TEXT;
  v_quest_name TEXT;
  v_quest_def_id TEXT;
BEGIN
  IF NEW.status = 'claimed' AND (OLD.status IS NULL OR OLD.status != 'claimed') THEN
    v_quest_def_id := NEW.quest_definition_id;
    v_quest_name := COALESCE(
      (SELECT title FROM public.quests WHERE id = v_quest_def_id),
      INITCAP(COALESCE(NEW.category, 'quest'))
    );
    v_title := 'Quest completed: ' || v_quest_name;

    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.user_id,
      'quest',
      v_title,
      'You completed "' || v_quest_name || '" and earned your rewards!',
      jsonb_build_object('quest_instance_id', NEW.id, 'quest_definition_id', v_quest_def_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_quest_completed ON public.user_quests;
CREATE TRIGGER trg_notify_on_quest_completed
  AFTER UPDATE OF status ON public.user_quests
  FOR EACH ROW
  WHEN (NEW.status = 'claimed' AND (OLD.status IS NULL OR OLD.status != 'claimed'))
  EXECUTE FUNCTION public.notify_on_quest_completed();

-- 6. RPC: create notification (for achievements, reminders - called from app)
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
