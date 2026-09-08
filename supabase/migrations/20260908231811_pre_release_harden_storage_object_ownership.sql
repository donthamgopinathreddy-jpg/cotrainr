-- Mirrors live production migration 20260908231811.
-- Removes generic permissive storage write policies and keeps writes bucket-scoped, owner-scoped and active-account scoped.

DROP POLICY IF EXISTS "Active accounts can insert storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Active accounts can update storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Restricted accounts cannot upload storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Restricted accounts cannot update storage objects" ON storage.objects;

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='avatars' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());
CREATE POLICY "Users can update own avatar" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='avatars' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active()) WITH CHECK (bucket_id='avatars' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());

DROP POLICY IF EXISTS "Users can upload post media" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own post media" ON storage.objects;
CREATE POLICY "Users can upload post media" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='posts' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());
CREATE POLICY "Users can update own post media" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='posts' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active()) WITH CHECK (bucket_id='posts' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());

DROP POLICY IF EXISTS "Providers can upload own verification docs" ON storage.objects;
DROP POLICY IF EXISTS "Providers can update own verification docs" ON storage.objects;
CREATE POLICY "Providers can upload own verification docs" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='verification-docs' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());
CREATE POLICY "Providers can update own verification docs" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='verification-docs' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active()) WITH CHECK (bucket_id='verification-docs' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());

DROP POLICY IF EXISTS "Participants can upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Owners can update chat attachments" ON storage.objects;
CREATE POLICY "Participants can upload chat attachments" ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id='chat-attachments' AND (storage.foldername(name))[1]=(select auth.uid())::text AND (storage.foldername(name))[2]='chat' AND public.is_account_active()
  AND EXISTS (SELECT 1 FROM public.conversations c WHERE c.id::text=(storage.foldername(storage.objects.name))[3] AND ((select auth.uid())=c.client_id OR (select auth.uid())=c.provider_id OR (select auth.uid())=c.other_user_id))
);
CREATE POLICY "Owners can update chat attachments" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='chat-attachments' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active()) WITH CHECK (bucket_id='chat-attachments' AND (storage.foldername(name))[1]=(select auth.uid())::text AND public.is_account_active());
