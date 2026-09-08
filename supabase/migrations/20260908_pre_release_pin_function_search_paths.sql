-- Cotrainr pre-release security hardening
-- DB-01: pin mutable function search_path to public, pg_catalog.

alter function public.cleanup_expired_meal_photos() set search_path = public, pg_catalog;
alter function public.create_user_profile(uuid,text,text,text,text,text,text,text,text[],numeric,numeric,date,text,text,text) set search_path = public, pg_catalog;
alter function public.nearby_entities(double precision,double precision,integer,text) set search_path = public, pg_catalog;
alter function public.update_meal_days_totals() set search_path = public, pg_catalog;
alter function public.bmi_status(numeric) set search_path = public, pg_catalog;
alter function public.calculate_age() set search_path = public, pg_catalog;
alter function public.calculate_bmi_status() set search_path = public, pg_catalog;
alter function public.calculate_level_from_xp(integer) set search_path = public, pg_catalog;
alter function public.calculate_level_xp(integer) set search_path = public, pg_catalog;
alter function public.compute_bmi(numeric,numeric) set search_path = public, pg_catalog;
alter function public.current_legal_versions() set search_path = public, pg_catalog;
alter function public.get_xp_for_next_level(integer,integer) set search_path = public, pg_catalog;
alter function public.handle_updated_at() set search_path = public, pg_catalog;
alter function public.is_mvp_provider_client_conversation(public.conversations) set search_path = public, pg_catalog;
alter function public.normalize_provider_specialization_array(text[]) set search_path = public, pg_catalog;
alter function public.normalize_provider_specialty(text) set search_path = public, pg_catalog;
alter function public.on_profile_metrics_change() set search_path = public, pg_catalog;
alter function public.protect_cotrainr_pass_id() set search_path = public, pg_catalog;
alter function public.protect_partner_application_status() set search_path = public, pg_catalog;
alter function public.require_legal_reacceptance() set search_path = public, pg_catalog;
alter function public.set_foods_updated_at() set search_path = public, pg_catalog;
alter function public.set_updated_at() set search_path = public, pg_catalog;
alter function public.update_display_name() set search_path = public, pg_catalog;
alter function public.update_level_on_xp_change() set search_path = public, pg_catalog;
alter function public.update_updated_at_column() set search_path = public, pg_catalog;
alter function public.user_is_conversation_participant(public.conversations,uuid) set search_path = public, pg_catalog;
alter function public.video_session_reject_reason_label(text,text) set search_path = public, pg_catalog;
alter function public.video_session_when_label(timestamptz) set search_path = public, pg_catalog;
