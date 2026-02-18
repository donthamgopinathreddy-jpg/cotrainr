import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/video_sessions_repository.dart';

final zoomIntegrationProvider = FutureProvider<ZoomIntegrationStatus>((ref) async {
  final repo = VideoSessionsRepository();
  return repo.getZoomStatus();
});
