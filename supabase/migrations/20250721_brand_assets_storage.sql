-- Optional public bucket for remotely replaceable marketing / email / web assets.
-- App startup splash and launcher icons MUST continue to use bundled local assets
-- under assets/branding/ — do not download from this bucket at cold start.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'brand-assets',
  'brand-assets',
  true,
  5242880, -- 5 MB
  array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public read for marketing / web clients.
drop policy if exists "Public read brand-assets" on storage.objects;
create policy "Public read brand-assets"
  on storage.objects
  for select
  to public
  using (bucket_id = 'brand-assets');

-- Authenticated uploads (admin / ops). Tighten to service role in production if preferred.
drop policy if exists "Authenticated upload brand-assets" on storage.objects;
create policy "Authenticated upload brand-assets"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'brand-assets');

drop policy if exists "Authenticated update brand-assets" on storage.objects;
create policy "Authenticated update brand-assets"
  on storage.objects
  for update
  to authenticated
  using (bucket_id = 'brand-assets')
  with check (bucket_id = 'brand-assets');

-- Suggested object keys (upload manually; not used by Flutter splash):
-- brand-assets/logo/cotrainr-logo.png
-- brand-assets/logo/cotrainr-logo-white.png
-- brand-assets/logo/cotrainr-wordmark.png
-- brand-assets/splash/cotrainr-splash-runner.webp
