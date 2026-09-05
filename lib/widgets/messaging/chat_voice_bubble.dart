import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/chat_voice_playback_controller.dart';
import '../../utils/chat_voice_rules.dart';
import '../../utils/messaging_error_messages.dart';

/// Compact play/pause + duration + progress for a chat voice message.
class ChatVoiceBubble extends StatefulWidget {
  final String playbackKey;
  final String? audioUrl;
  final String? audioPath;
  final int? durationMs;
  final Color foreground;
  final Color foregroundMuted;

  const ChatVoiceBubble({
    super.key,
    required this.playbackKey,
    this.audioUrl,
    this.audioPath,
    this.durationMs,
    required this.foreground,
    required this.foregroundMuted,
  });

  @override
  State<ChatVoiceBubble> createState() => _ChatVoiceBubbleState();
}

class _ChatVoiceBubbleState extends State<ChatVoiceBubble> {
  bool _busy = false;

  ChatVoicePlaybackController get _ctrl => ChatVoicePlaybackController.instance;

  bool get _hasSource =>
      (widget.audioPath != null && widget.audioPath!.isNotEmpty) ||
      (widget.audioUrl != null && widget.audioUrl!.isNotEmpty);

  Future<void> _toggle() async {
    if (!_hasSource || _busy) return;
    setState(() => _busy = true);
    try {
      final key = widget.playbackKey;
      if (_ctrl.isActive(key) && _ctrl.player.playing) {
        await _ctrl.pause();
        return;
      }
      if (widget.audioPath != null && widget.audioPath!.isNotEmpty) {
        await _ctrl.playFile(key: key, path: widget.audioPath!);
      } else if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
        await _ctrl.play(key: key, url: widget.audioUrl!);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(MessagingErrorMessages.playbackFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackMs = widget.durationMs ?? 0;
    final fallbackLabel = ChatVoiceRules.formatDuration(
      Duration(milliseconds: fallbackMs),
    );

    return StreamBuilder<PlayerState>(
      stream: _ctrl.player.playerStateStream,
      builder: (context, snapshot) {
        final active = _ctrl.isActive(widget.playbackKey);
        final playing = active && (snapshot.data?.playing ?? false);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _hasSource ? _toggle : null,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.foreground,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 4,
                    child: active
                        ? StreamBuilder<Duration>(
                            stream: _ctrl.player.positionStream,
                            builder: (context, posSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final total =
                                  _ctrl.player.duration ??
                                  Duration(milliseconds: fallbackMs);
                              final maxMs = total.inMilliseconds <= 0
                                  ? 1
                                  : total.inMilliseconds;
                              final value = (pos.inMilliseconds / maxMs).clamp(
                                0.0,
                                1.0,
                              );
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 4,
                                backgroundColor: widget.foregroundMuted
                                    .withValues(alpha: 0.35),
                                color: widget.foreground,
                              );
                            },
                          )
                        : LinearProgressIndicator(
                            value: 0,
                            minHeight: 4,
                            backgroundColor: widget.foregroundMuted.withValues(
                              alpha: 0.35,
                            ),
                            color: widget.foreground,
                          ),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<Duration>(
                    stream: active ? _ctrl.player.positionStream : null,
                    builder: (context, posSnap) {
                      String label = fallbackLabel;
                      if (active && posSnap.data != null) {
                        final total =
                            _ctrl.player.duration ??
                            Duration(milliseconds: fallbackMs);
                        final show = playing
                            ? posSnap.data!
                            : (total.inMilliseconds > 0
                                  ? total
                                  : posSnap.data!);
                        label = ChatVoiceRules.formatDuration(show);
                      }
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.foregroundMuted,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
