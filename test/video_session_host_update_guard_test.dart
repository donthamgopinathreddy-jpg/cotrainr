import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/repositories/video_sessions_repository.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  const migration =
      'supabase/migrations/20261018130000_video_session_host_update_lock.sql';

  test('authenticated UPDATE is limited to scheduling fields', () {
    final sql = _source(migration);
    final grant = sql.substring(
      sql.indexOf('GRANT UPDATE ('),
      sql.indexOf(') ON TABLE public.video_sessions TO authenticated'),
    );
    for (final column in [
      'title',
      'description',
      'scheduled_start',
      'duration_minutes',
      'updated_at',
    ]) {
      expect(grant.contains(column), isTrue, reason: column);
    }
    for (final blocked in [
      'join_url',
      'provider_meeting_id',
      'host_id',
      'status',
      'max_participants',
      'created_at',
    ]) {
      expect(grant.contains(blocked), isFalse, reason: blocked);
    }
    expect(sql.contains('FROM anon'), isTrue);
    expect(sql.contains('REVOKE UPDATE, DELETE, TRUNCATE'), isTrue);
    expect(
      sql.contains('DROP POLICY IF EXISTS "Hosts can delete own sessions"'),
      isTrue,
    );
    expect(sql.contains('TO anon'), isFalse);
  });

  test('reschedule repository writes only granted columns', () {
    final src = _source('lib/repositories/video_sessions_repository.dart');
    final start = src.indexOf('final updates = <String, dynamic>{');
    final map = src.substring(start, src.indexOf('};', start));
    expect(map.contains("'title'"), isTrue);
    expect(map.contains("'scheduled_start'"), isTrue);
    expect(map.contains("'duration_minutes'"), isTrue);
    expect(map.contains("'description'"), isTrue);
    expect(map.contains("'updated_at'"), isTrue);
    expect(map.contains('join_url'), isFalse);
    expect(map.contains('provider_meeting_id'), isFalse);
    expect(map.contains('host_id'), isFalse);
    expect(map.contains("'status'"), isFalse);
    expect(src.contains("code: 'JOIN_URL_LOCKED'"), isTrue);
  });

  test('cancellation is idempotent and still notifies through status change', () {
    final sql = _source(migration);
    final fn = sql.substring(sql.indexOf('FUNCTION public.cancel_my_video_session'));
    expect(fn.contains('auth.uid()'), isTrue);
    expect(fn.contains('p_user_id'), isFalse);
    expect(fn.contains("v_status = 'cancelled'"), isTrue);
    expect(fn.contains('RETURN;'), isTrue);
    expect(fn.contains("status = 'cancelled'"), isTrue);
    expect(fn.contains("status = 'scheduled'"), isTrue);
    expect(fn.contains('SECURITY DEFINER'), isTrue);
    expect(fn.contains('search_path = public, pg_catalog'), isTrue);
    expect(fn.contains('GRANT EXECUTE ON FUNCTION public.cancel_my_video_session(uuid) TO authenticated'), isTrue);
    expect(fn.contains('TO anon'), isFalse);
    expect(fn.contains('trg_video_sessions_notify_update'), isTrue);
  });

  test('revoked hosts can cancel and cannot change meeting details', () {
    final sql = _source(migration);
    expect(sql.contains('BEFORE INSERT OR UPDATE ON public.video_sessions'), isTrue);
    expect(sql.contains('UPDATE OF host_id'), isFalse);
    expect(sql.contains("OLD.status = 'scheduled'"), isTrue);
    expect(sql.contains("NEW.status = 'cancelled'"), isTrue);
    expect(sql.contains('OLD.join_url IS NOT DISTINCT FROM NEW.join_url'), isTrue);
    expect(sql.contains('p.verified IS TRUE'), isTrue);
    expect(sql.contains('Does not require providers.verified'), isTrue);
  });

  test('cancel failure codes never report success', () {
    expect(
      cancelSessionFailureCode(sqlState: '42501', message: 'not_authenticated'),
      'UNAUTHORIZED',
    );
    expect(
      cancelSessionFailureCode(sqlState: '42501', message: 'account_restricted'),
      'ACCOUNT_RESTRICTED',
    );
    expect(
      cancelSessionFailureCode(sqlState: '42501', message: 'not_session_host'),
      'FORBIDDEN',
    );
    expect(
      cancelSessionFailureCode(sqlState: 'P0002', message: 'session_not_found'),
      'CANCEL_NOT_APPLIED',
    );
    expect(
      cancelSessionFailureCode(
        sqlState: '22023',
        message: 'session_not_cancellable',
      ),
      'CANCEL_NOT_APPLIED',
    );
    expect(
      cancelSessionFailureCode(sqlState: '42501', message: 'permission denied'),
      'CANCEL_NOT_APPLIED',
    );
  });
}
