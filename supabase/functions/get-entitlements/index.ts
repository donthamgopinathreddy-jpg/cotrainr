import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const userId = user.id

    const { data: subscription } = await supabaseAdmin
      .from('subscriptions')
      .select('plan, status')
      .eq('user_id', userId)
      .maybeSingle()

    const plan = subscription?.plan || 'free'
    const status = subscription?.status || 'active'

    // Calendar month (matches create_lead_tx date_trunc('month', now()))
    const now = new Date()
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    const monthStartStr = monthStart.toISOString().slice(0, 10)

    const { data: usage } = await supabaseAdmin
      .from('monthly_usage')
      .select('*')
      .eq('user_id', userId)
      .eq('month_start', monthStartStr)
      .maybeSingle()

    const requestsUnlimited = plan === 'premium'
    const requestsLimit = plan === 'free' ? 5 : plan === 'basic' ? 15 : null
    const nutritionistAllowed = plan === 'basic' || plan === 'premium'

    const requestsUsed = usage?.requests_used || 0
    const remainingRequests = requestsUnlimited
      ? null
      : Math.max(0, (requestsLimit as number) - requestsUsed)

    return new Response(
      JSON.stringify({
        plan,
        status,
        month_start: monthStartStr,
        // legacy alias for older clients
        week_start: monthStartStr,
        limits: {
          requests: requestsLimit,
          requests_unlimited: requestsUnlimited,
          nutritionist_allowed: nutritionistAllowed,
          // legacy field — sub-cap removed; keep 0 for parsers
          nutritionist_requests: 0,
        },
        used: {
          requests: requestsUsed,
          nutritionist_requests: 0,
        },
        remaining: {
          requests: remainingRequests,
          requests_unlimited: requestsUnlimited,
          nutritionist_requests: 0,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
