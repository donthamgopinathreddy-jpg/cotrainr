-- REQUIRED for PDF/Office chat uploads (run in Supabase SQL editor).
-- Extends posts bucket MIME allow-list + media_kind document enum.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'media_kind' AND e.enumlabel = 'document'
  ) THEN
    ALTER TYPE public.media_kind ADD VALUE 'document';
  END IF;
END $$;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS media_file_name text,
  ADD COLUMN IF NOT EXISTS media_mime_type text,
  ADD COLUMN IF NOT EXISTS media_size_bytes bigint;

UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg','image/jpg','image/png','image/webp','image/gif',
  'video/mp4','video/quicktime',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain','text/csv','application/csv'
]
WHERE id = 'posts';
