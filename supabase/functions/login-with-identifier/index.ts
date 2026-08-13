import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  identifier?: string;
  password?: string;
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Generic auth failure — never reveal username/email existence. */
function invalidCredentials() {
  return json(401, { error: "invalid_credentials" });
}

function looksLikeEmail(value: string): boolean {
  if (!value.includes("@")) return false;
  // @username shorthand (no other @)
  if (value.startsWith("@") && value.indexOf("@", 1) === -1) return false;
  return true;
}

function isPlausibleEmail(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
}

/** Trim, strip one leading @, lowercase for username_lower match. */
function normalizeUsername(raw: string): string {
  let v = raw.trim();
  if (v.startsWith("@")) v = v.slice(1).trim();
  return v.toLowerCase();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    if (!supabaseUrl || !serviceKey || !anonKey) {
      console.error("login-with-identifier: missing env");
      return json(503, { error: "service_unavailable" });
    }

    let body: Body;
    try {
      body = await req.json();
    } catch {
      return invalidCredentials();
    }

    const identifierRaw =
      typeof body.identifier === "string" ? body.identifier.trim() : "";
    const password =
      typeof body.password === "string" ? body.password : "";

    if (!identifierRaw || !password) {
      return invalidCredentials();
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Auth client with anon key — password verification via Auth API
    // (not a service-role bypass of password checks).
    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let email: string | null = null;

    if (looksLikeEmail(identifierRaw)) {
      if (!isPlausibleEmail(identifierRaw)) {
        return invalidCredentials();
      }
      email = identifierRaw.toLowerCase();
    } else {
      const username = normalizeUsername(identifierRaw);
      if (!username) {
        return invalidCredentials();
      }

      // Prefer private RPC (service_role hard-guarded). Fallback to direct
      // service-role read of profiles — never returned to the client.
      let resolved: string | null = null;
      try {
        const { data, error } = await admin.rpc("rpc_resolve_login_identifier", {
          identifier: username,
        });
        if (!error && Array.isArray(data) && data.length > 0) {
          resolved = (data[0] as { email?: string })?.email ?? null;
        } else if (!error && data && typeof data === "object") {
          // Some PostgREST shapes return a single row object.
          resolved = (data as { email?: string }).email ?? null;
        }
      } catch (e) {
        console.error("login-with-identifier: rpc resolve failed");
      }

      if (!resolved) {
        const { data: profile, error } = await admin
          .from("profiles")
          .select("email")
          .eq("username_lower", username)
          .maybeSingle();
        if (error) {
          console.error("login-with-identifier: profile resolve failed");
          return json(503, { error: "service_unavailable" });
        }
        resolved = profile?.email ?? null;
      }

      if (!resolved) {
        // Indistinguishable from wrong password.
        return invalidCredentials();
      }
      email = resolved;
    }

    const { data, error } = await authClient.auth.signInWithPassword({
      email,
      password,
    });

    if (error || !data.session) {
      // Do not leak error.message (may distinguish confirmations, etc.)
      const msg = (error?.message ?? "").toLowerCase();
      if (msg.includes("rate") || (error as { status?: number })?.status === 429) {
        return json(429, { error: "rate_limited" });
      }
      return invalidCredentials();
    }

    const session = data.session;
    return json(200, {
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_in: session.expires_in,
      token_type: session.token_type ?? "bearer",
      // Minimal user id only — never include resolved email for username logins.
      user: { id: data.user?.id },
    });
  } catch (e) {
    console.error("login-with-identifier: unexpected error");
    return json(503, { error: "service_unavailable" });
  }
});
