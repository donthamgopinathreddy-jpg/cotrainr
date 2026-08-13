import 'dart:async';
import 'dart:io';

import '../config/supabase_config.dart';

/// Best-effort reachability probe (no extra packages).
Future<bool> probeNetworkReachability({
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    final host = Uri.parse(SupabaseConfig.supabaseUrl).host;
    final result = await InternetAddress.lookup(host).timeout(timeout);
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}
