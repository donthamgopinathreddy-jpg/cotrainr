import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PATH_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/(credential|gov_id)\.(jpg|jpeg|png|webp)$/i;

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return json(401, { error: 'Unauthorized' });
    }

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseAuth.auth.getUser();
    if (userError || !user) {
      return json(401, { error: 'Unauthorized' });
    }

    const body = await req.json();
    const path = typeof body?.path === 'string' ? body.path.trim() : '';
    const expiresIn =
      typeof body?.expiresIn === 'number'
        ? Math.min(Math.max(body.expiresIn, 60), 3600)
        : 900;

    if (!path || path.includes('..') || path.startsWith('/') || !PATH_RE.test(path)) {
      return json(400, { error: 'invalid path' });
    }

    const ownerId = path.split('/')[0];
    const isOwner = ownerId === user.id;

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    let isAdmin = false;
    if (!isOwner) {
      const { data: adminRow, error: adminError } = await admin
        .from('admin_users')
        .select('id')
        .eq('id', user.id)
        .eq('is_active', true)
        .maybeSingle();

      if (adminError) {
        return json(403, { error: 'Forbidden' });
      }

      isAdmin = adminRow != null;
    }

    if (!isOwner && !isAdmin) {
      return json(403, { error: 'Forbidden' });
    }

    const { data, error } = await admin.storage
      .from('verification-docs')
      .createSignedUrl(path, expiresIn);

    if (error) {
      return json(400, { error: error.message });
    }

    return json(200, { signedUrl: data.signedUrl });
  } catch (e) {
    return json(500, { error: String(e) });
  }
});
