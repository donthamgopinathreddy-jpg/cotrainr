-- Cotrainr pre-release security hardening
-- RPC-01: rpc_resolve_login_identifier already enforces service_role in-body;
-- align EXECUTE privileges with that contract.

revoke execute on function public.rpc_resolve_login_identifier(text)
  from public, anon, authenticated;
grant execute on function public.rpc_resolve_login_identifier(text)
  to service_role;
