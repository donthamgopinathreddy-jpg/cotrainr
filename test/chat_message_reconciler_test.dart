import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/utils/chat_message_reconciler.dart';

void main() {
  group('ChatMessageReconciler', () {
    test('optimistic + confirm yields one bubble for one DB id', () {
      final r = ChatMessageReconciler();
      final local = r.addOptimistic(
        text: 'Hi',
        isSent: true,
        time: 'Just now',
      );
      expect(r.messages, hasLength(1));

      r.confirmOptimistic(
        localId: local,
        messageId: 'db-1',
        text: 'Hi',
        isSent: true,
        time: '12:00',
      );
      expect(r.messages, hasLength(1));
      expect(r.messages.single.messageId, 'db-1');
      expect(r.messages.single.localId, isNull);

      // Realtime echo of same id must not append.
      final added = r.upsertCanonical(
        messageId: 'db-1',
        text: 'Hi',
        isSent: true,
        time: '12:00',
      );
      expect(added, isFalse);
      expect(r.messages, hasLength(1));
    });

    test('same text twice with different ids yields two bubbles', () {
      final r = ChatMessageReconciler();
      final a = r.addOptimistic(text: 'Hi', isSent: true, time: 't1');
      r.confirmOptimistic(
        localId: a,
        messageId: 'db-1',
        text: 'Hi',
        isSent: true,
        time: 't1',
      );
      final b = r.addOptimistic(text: 'Hi', isSent: true, time: 't2');
      r.confirmOptimistic(
        localId: b,
        messageId: 'db-2',
        text: 'Hi',
        isSent: true,
        time: 't2',
      );
      expect(r.messages, hasLength(2));
      expect(r.messages.map((m) => m.messageId).toSet(), {'db-1', 'db-2'});
    });

    test('realtime before confirm still ends as one bubble', () {
      final r = ChatMessageReconciler();
      final local = r.addOptimistic(text: 'Hello', isSent: true, time: 'now');
      expect(
        r.upsertCanonical(
          messageId: 'db-9',
          text: 'Hello',
          isSent: true,
          time: '12:01',
        ),
        isTrue,
      );
      expect(r.messages, hasLength(2)); // temp + realtime until confirm

      r.confirmOptimistic(
        localId: local,
        messageId: 'db-9',
        text: 'Hello',
        isSent: true,
        time: '12:01',
      );
      expect(r.messages, hasLength(1));
      expect(r.messages.single.messageId, 'db-9');
    });

    test('removeOptimistic removes by local id not last item', () {
      final r = ChatMessageReconciler();
      r.upsertCanonical(
        messageId: 'db-keep',
        text: 'Keep',
        isSent: false,
        time: 't0',
      );
      final local = r.addOptimistic(text: 'Fail', isSent: true, time: 't1');
      expect(r.removeOptimistic(local), isTrue);
      expect(r.messages, hasLength(1));
      expect(r.messages.single.messageId, 'db-keep');
    });

    test('rapid double optimistic + confirm both ids', () {
      final r = ChatMessageReconciler();
      final a = r.addOptimistic(text: 'A', isSent: true, time: 't');
      final b = r.addOptimistic(text: 'B', isSent: true, time: 't');
      r.confirmOptimistic(
        localId: a,
        messageId: 'db-a',
        text: 'A',
        isSent: true,
        time: 't',
      );
      r.confirmOptimistic(
        localId: b,
        messageId: 'db-b',
        text: 'B',
        isSent: true,
        time: 't',
      );
      expect(r.upsertCanonical(messageId: 'db-a', text: 'A', isSent: true, time: 't'), isFalse);
      expect(r.upsertCanonical(messageId: 'db-b', text: 'B', isSent: true, time: 't'), isFalse);
      expect(r.messages, hasLength(2));
    });
  });
}
