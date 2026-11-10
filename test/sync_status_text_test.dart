import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/sync/sync_status_text.dart';

void main() {
  SyncStatusText describe({
    bool connected = false,
    bool connecting = false,
    bool transferring = false,
    bool hasSyncedBefore = false,
    int pendingUploads = 0,
    DateTime? lastSyncedAt,
    String? error,
  }) {
    return describeSyncStatus(
      connected: connected,
      connecting: connecting,
      transferring: transferring,
      hasSyncedBefore: hasSyncedBefore,
      pendingUploads: pendingUploads,
      lastSyncedAt: lastSyncedAt,
      error: error,
    );
  }

  test('says Connecting on the very first connection', () {
    expect(describe(connecting: true).label, 'Connecting…');
  });

  test('says Offline when not connected', () {
    final status = describe();
    expect(status.label, 'Offline');
    expect(status.detail, contains('saved on this device'));
  });

  test('says Offline, not Connecting, while retrying after a sync', () {
    expect(describe(connecting: true, hasSyncedBefore: true).label, 'Offline');
  });

  test('offline shows how many changes are waiting', () {
    expect(describe(pendingUploads: 1).detail, contains('1 change waiting'));
    expect(describe(pendingUploads: 3).detail, contains('3 changes waiting'));
  });

  test('offline shows the reason when there is an error', () {
    final status = describe(connecting: true, error: 'PSYNC_S2101');
    expect(status.label, 'Offline');
    expect(status.detail, contains('Reason: PSYNC_S2101'));
  });

  test('says Syncing while data moves', () {
    expect(describe(connected: true, transferring: true).label, 'Syncing…');
  });

  test('says Syncing while changes still wait to upload', () {
    final status = describe(connected: true, pendingUploads: 2);
    expect(status.label, 'Syncing…');
    expect(status.detail, '2 changes waiting to upload');
  });

  test('says Synced when connected and nothing is waiting', () {
    final status = describe(
      connected: true,
      hasSyncedBefore: true,
      lastSyncedAt: DateTime(2026, 11, 11, 9, 5, 7),
    );
    expect(status.label, 'Synced');
    expect(status.detail, 'Last synced at 09:05:07');
  });
}
