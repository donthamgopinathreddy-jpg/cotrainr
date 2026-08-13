# Login with identifier (email or User ID)
#
# Deploy with JWT verification disabled (unauthenticated login entrypoint):
#   supabase functions deploy login-with-identifier --no-verify-jwt
#
# Uses SUPABASE_SERVICE_ROLE_KEY only inside this function to resolve
# username → email. Never returns the mapped email to the client.
# Password checks go through Supabase Auth (anon signInWithPassword).
