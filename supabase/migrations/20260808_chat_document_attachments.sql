-- Chat document attachments: extend media_kind + message metadata.
-- Reuses existing public.messages + posts storage bucket (chat path).
-- Does NOT modify historical migrations.

-- 1) Allow document media_kind (keep image/video for history)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'media_kind'
      AND e.enumlabel = 'document'
  ) THEN
    ALTER TYPE public.media_kind ADD VALUE 'document';
  END IF;
END $$;

-- 2) Attachment metadata (nullable for legacy text/image/video rows)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS media_file_name text,
  ADD COLUMN IF NOT EXISTS media_mime_type text,
  ADD COLUMN IF NOT EXISTS media_size_bytes bigint;

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_media_size_bytes_nonneg;

ALTER TABLE public.messages
  ADD CONSTRAINT messages_media_size_bytes_nonneg
  CHECK (media_size_bytes IS NULL OR media_size_bytes >= 0);

COMMENT ON COLUMN public.messages.media_file_name IS
  'Original attachment file name for document/image display';
COMMENT ON COLUMN public.messages.media_mime_type IS
  'MIME type when known (prefer over extension)';
COMMENT ON COLUMN public.messages.media_size_bytes IS
  'Attachment byte size for UI display';

-- 3) Extend posts bucket MIME allow-list for coaching documents (CSV included).
-- Bucket remains public (existing architecture). App enforces 10MB images / 20MB docs.
UPDATE storage.buckets
SET
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'application/csv'
  ]
WHERE id = 'posts';
