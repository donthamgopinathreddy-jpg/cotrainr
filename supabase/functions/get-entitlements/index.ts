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

    // Calculate week start (ISO Monday - same formula as RPC)
    // Formula: current_date - ((dow + 6) % 7)
    const now = new Date()
    const dayOfWeek = now.getDay() // 0=Sunday, 1=Monday, ..., 6=Saturday
    const daysToMonday = (dayOfWeek + 6) % 7
    const weekStart = new Date(now)
    weekStart.setDate(now.getDate() - daysToMonday)
    weekStart.setHours(0, 0, 0, 0)
    const weekStartStr = weekStart.toISOString().split('T')[0]

    const { data: usage } = await supabaseAdmin
      .from('weekly_usage')
      .select('*')
      .eq('user_id', userId)
      .eq('week_start', weekStartStr)
      .maybeSingle()

    interface PlanLimits {
      requests: number
      nutritionist_requests?: number
      nutritionist_allowed?: boolean
    }

    const limits: Record<string, PlanLimits> = {
      free: { requests: 3, nutritionist_allowed: false },
      basic: { requests: 15, nutritionist_requests: 3, nutritionist_allowed: true },
      premium: { requests: 30, nutritionist_requests: 30, nutritionist_allowed: true },
    }

    const planLimits = limits[plan] || limits.free

    const requestsUsed = usage?.requests_used || 0
    const nutritionistRequestsUsed = usage?.nutritionist_requests_used || 0

    const remaining = {
      requests: Math.max(0, planLimits.requests - requestsUsed),
      nutritionist_requests: planLimits.nutritionist_requests 
        ? Math.max(0, planLimits.nutritionist_requests - nutritionistRequestsUsed)
        : 0,
    }

    return new Response(
      JSON.stringify({
        plan,
        status,
        week_start: weekStartStr,
        limits: {
          requests: planLimits.requests,
          nutritionist_requests: planLimits.nutritionist_requests || 0,
          nutritionist_allowed: planLimits.nutritionist_allowed !== false,
        },
        used: {
          requests: requestsUsed,
          nutritionist_requests: nutritionistRequestsUsed,
        },
        remaining,
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
