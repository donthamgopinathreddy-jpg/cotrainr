do $$
declare
  v_def text;
  v_old text := E'  IF p_status = ''accepted'' THEN\r\n    v_now := now();';
  v_new text := E'  IF p_status = ''accepted'' THEN\r\n    IF NOT EXISTS (\r\n      SELECT 1\r\n      FROM public.providers pr\r\n      WHERE pr.user_id = v_lead_record.provider_id\r\n        AND pr.verified = true\r\n    ) THEN\r\n      RETURN jsonb_build_object(\r\n        ''ok'', false,\r\n        ''error_code'', ''PROVIDER_NOT_VERIFIED'',\r\n        ''message'', ''Provider verification is required before accepting this connection''\r\n      );\r\n    END IF;\r\n\r\n    v_now := now();';
begin
  select pg_get_functiondef('public.update_lead_status_tx(uuid,text)'::regprocedure) into v_def;
  if strpos(v_def, 'PROVIDER_NOT_VERIFIED') > 0 then
    return;
  end if;
  if strpos(v_def, v_old) = 0 then
    raise exception 'Expected acceptance marker not found';
  end if;
  execute replace(v_def, v_old, v_new);
end $$;
